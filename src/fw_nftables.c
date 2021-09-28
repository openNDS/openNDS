#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <syslog.h>
#include <errno.h>
#include <string.h>
#include <pthread.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <ctype.h>

#include <nftables/libnftables.h>

#include "common.h"

#include "safe.h"
#include "conf.h"
#include "auth.h"
#include "client_list.h"
#include "fw.h"
#include "debug.h"
#include "util.h"

#define CHAIN_TO_INTERNET "to_internet"
#define CHAIN_TO_ROUTER "to_router"
#define CHAIN_TRUSTED_TO_ROUTER "trusted_to_router"
#define CHAIN_UPLOAD_RATE  "upload_rate"

#define CHAIN_MANGLE_PRE "mangle_pre"
#define CHAIN_MANGLE_POST "mangle_post"

#define CHAIN_NAT_PRE "nat_pre"
#define CHAIN_NAT_OUTGOING "nat_outgoing"

#define CHAIN_FILTER_INPUT "filter_input"
#define CHAIN_FILTER_FORWARD "filter_forward"

#define CHAIN_BLOCKED "block"
#define CHAIN_ALLOWED "allow"
#define CHAIN_TRUSTED "trust"
#define CHAIN_OUTGOING "outgoing"
#define CHAIN_INCOMING "incoming"
#define CHAIN_AUTHENTICATED "authenticated"
#define CHAIN_PREAUTHENTICATED   "preauthenticated"

#define CHAIN_FILTER_TRUSTED "filter_trust"

#define TABLE_OPENNDS "opennds"

// Used to mark packets, and characterize client state.  Unmarked packets are considered 'preauthenticated'
unsigned int FW_MARK_PREAUTHENTICATED; // @brief 0: Actually not used as a packet mark
unsigned int FW_MARK_AUTHENTICATED;    // @brief The client is authenticated
unsigned int FW_MARK_BLOCKED;          // @brief The client is blocked
unsigned int FW_MARK_TRUSTED;          // @brief The client is trusted

extern pthread_mutex_t client_list_mutex;
extern pthread_mutex_t config_mutex;

static struct nft_ctx *nft;

static char * strlower(char *str)
{
	size_t i;

	for (i = 0; str[i]; i++)
		str[i] = tolower(str[i]);

	return str;
}

static int __nftables_do(const char *cmd)
{
	int rc;

	rc = nft_run_cmd_from_buffer(nft, cmd);
	debug(LOG_DEBUG,"nftables command [ %s ], return code [ %d ]", cmd, rc);

	return rc;
}

static int nftables_do(const char *cmd_pre, const char *format, ...)
{
	char cmd[256];
	va_list vlist;
	const s_config *config = config_get_config();
	const char *proto = config->ip6 ? "ip6" : "ip";
	unsigned pos;

	pos = snprintf(cmd, sizeof(cmd), "%s %s " TABLE_OPENNDS " ", cmd_pre, proto);

	va_start(vlist, format);
	vsnprintf(&cmd[pos], sizeof(cmd) - pos, format, vlist);
	va_end(vlist);

	return __nftables_do(cmd);
}

static int get_rule_handle(const char *output, const char *match)
{
	int handle = -1;
	char *p;

	if (output == NULL)
		return -1;

	p = strstr(output, match);
	if (p) {
		p = strstr(p, "# handle ");
		if (p)
			handle = atoi(p + 9);
	}
	return handle;
}

static const char * nftables_list(const char *chain, int flags)
{
	int rc;

	nft_ctx_buffer_output(nft);
	nft_ctx_output_set_flags(nft, flags
					| NFT_CTX_OUTPUT_HANDLE
					| NFT_CTX_OUTPUT_NUMERIC_ALL
					| NFT_CTX_OUTPUT_TERSE);

	rc = nftables_do("list chain", "%s", chain);
	if (rc) {
		nft_ctx_unbuffer_output(nft);
		return NULL;
	}

	return nft_ctx_get_output_buffer(nft);
}

static unsigned long long nftables_parse_counter_bytes(const char *line)
{
	const char *p = strstr(line, "bytes ");
	unsigned long long bytes = 0;

	if (p)
		bytes = strtoull(p + 6, NULL, 10);

	return bytes;
}

static long long int nftables_get_counter_bytes(const char *hook_chain, const char *jump_chain)
{
	const char *output;
	unsigned long long bytes = 0;
	char *p;

	output = nftables_list(hook_chain, 0);
	if (output == NULL)
		return -1;

	p = strstr(output, jump_chain);
	if (p && p - output > 32)
		bytes = nftables_parse_counter_bytes(p - 32);

	nft_ctx_unbuffer_output(nft);
	return bytes;
}

static int nftables_delete(const char *chain, const char *match_fmt, ...)
{
	const char *output;
	int rc;
	int handle;
	char match[128];
	va_list vlist;

	output = nftables_list(chain, NFT_CTX_OUTPUT_STATELESS);
	if (output == NULL)
		return -1;

	va_start(vlist, match_fmt);
	vsnprintf(match, sizeof(match), match_fmt, vlist);
	va_end(vlist);

	handle = get_rule_handle(output, match);
	nft_ctx_unbuffer_output(nft);

	if (handle > 0) {
		rc = nftables_do("delete rule", "%s handle %d", chain, handle);
	} else {
		debug(LOG_ERR, "Rule not found\n");
		rc = -1;
	}

	return rc;
}

// Return a string representing a connection state
const char * fw_connection_state_as_string(int mark)
{
	if (mark == FW_MARK_PREAUTHENTICATED)
		return "Preauthenticated";
	if (mark == FW_MARK_AUTHENTICATED)
		return "Authenticated";
	if (mark == FW_MARK_TRUSTED)
		return "Trusted";
	if (mark == FW_MARK_BLOCKED)
		return "Blocked";
	return "ERROR: unrecognized mark";
}

static int fw_init_marks()
{
	// Check FW_MARK values are distinct.
	if (FW_MARK_BLOCKED == FW_MARK_TRUSTED ||
			FW_MARK_TRUSTED == FW_MARK_AUTHENTICATED ||
			FW_MARK_AUTHENTICATED == FW_MARK_BLOCKED) {
		debug(LOG_ERR, "FW_MARK_BLOCKED, FW_MARK_TRUSTED, FW_MARK_AUTHENTICATED not distinct values.");
		return -1;
	}

	// Check FW_MARK values nonzero.
	if (FW_MARK_BLOCKED == 0 ||
			FW_MARK_TRUSTED == 0 ||
			FW_MARK_AUTHENTICATED == 0) {
		debug(LOG_ERR, "FW_MARK_BLOCKED, FW_MARK_TRUSTED, FW_MARK_AUTHENTICATED not all nonzero.");
		return -1;
	}

	FW_MARK_PREAUTHENTICATED = 0;  // always 0

	debug(LOG_DEBUG,"Nftables mark %s: 0x%x",
		fw_connection_state_as_string(FW_MARK_PREAUTHENTICATED),
		FW_MARK_PREAUTHENTICATED);
	debug(LOG_DEBUG,"Nftables mark %s: 0x%x",
		fw_connection_state_as_string(FW_MARK_AUTHENTICATED),
		FW_MARK_AUTHENTICATED);
	debug(LOG_DEBUG,"Nftables mark %s: 0x%x",
		fw_connection_state_as_string(FW_MARK_TRUSTED),
		FW_MARK_TRUSTED);
	debug(LOG_DEBUG,"Nftables mark %s: 0x%x",
		fw_connection_state_as_string(FW_MARK_BLOCKED),
		FW_MARK_BLOCKED);

	return 0;
}

static void fw_compile(char *cmd, size_t maxlen, t_firewall_rule *rule)
{
	const char *mode;
	size_t len = 0;

	cmd[0] = 0;

	switch (rule->target) {
	case TARGET_DROP:
		mode = "drop";
		break;
	case TARGET_REJECT:
		mode = "reject";
		break;
	case TARGET_ACCEPT:
		mode = "accept";
		break;
	case TARGET_RETURN:
		mode = "return";
		break;
	case TARGET_LOG:
		mode = "log";
		break;
	case TARGET_ULOG:
		mode = "ulog";
		break;
	default:
		return;
	}

	if (rule->mask != NULL)
		len += snprintf(cmd + len, maxlen - len, "ip daddr %s ", rule->mask);

	if (rule->protocol && strcmp(rule->protocol, "all"))
		len += snprintf(cmd + len, maxlen - len, "%s ", rule->protocol);

	if (rule->port != NULL)
		len += snprintf(cmd + len, maxlen - len, "dport %s ", rule->port);

	// TODO: Ipset nftables
#if 0
	if (rule->ipset != NULL) {
		snprintf((command + strlen(command)),
			 (sizeof(command) - strlen(command)),
			 "-m set --match-set %s dst ", rule->ipset
		);
	}
#endif

	snprintf(cmd + len, maxlen - len, "%s", mode);

	debug(LOG_DEBUG, "Compiled Command for nftables: [ %s ]", cmd);
}

static int _fw_append_ruleset(const char ruleset[], const char chain[])
{
	t_firewall_rule *rule;
	char cmd[MAX_BUF];
	int ret = 0;

	debug(LOG_DEBUG, "Loading ruleset %s into chain %s", ruleset, chain);

	for (rule = get_ruleset_list(ruleset); rule != NULL; rule = rule->next) {
		fw_compile(cmd, sizeof(cmd), rule);
		debug(LOG_DEBUG, "Loading rule \"%s\" into chain %s", cmd, chain);
		ret |= nftables_do("add rule", "%s %s", chain, cmd);
	}

	debug(LOG_DEBUG, "Ruleset %s loaded into chain %s", ruleset, chain);
	return ret;
}

int fw_block_mac(const char mac[])
{
	return nftables_do("add rule",  CHAIN_BLOCKED " ether saddr %s ct mark set 0x%x", mac, FW_MARK_BLOCKED);
}

int fw_unblock_mac(const char mac[])
{
	return nftables_delete(CHAIN_BLOCKED, "ether saddr %s ct mark set 0x%08x", mac, FW_MARK_BLOCKED);
}

int fw_allow_mac(const char mac[])
{
	return nftables_do("insert rule",  CHAIN_BLOCKED " ether saddr %s return", mac);
}

int fw_unallow_mac(const char mac[])
{
	return nftables_delete(CHAIN_BLOCKED, "ether saddr %s return", mac);
}

int fw_trust_mac(const char mac[])
{
	return nftables_do("add rule",  CHAIN_TRUSTED " ether saddr %s ct mark set 0x%x", mac, FW_MARK_TRUSTED);
}

int fw_untrust_mac(const char mac[])
{
	return nftables_delete(CHAIN_TRUSTED, "ether saddr %s ct mark set 0x%08x", mac, FW_MARK_TRUSTED);
}

int fw_download_ratelimit_enable(t_client *client, int enable)
{
	debug(LOG_INFO, "Download Rate Limiting not implemented for nftables\n");
	return 0;
}

int fw_upload_ratelimit_enable(t_client *client, int enable)
{
	debug(LOG_INFO, "Upload Rate Limiting not implemented for nftables\n");
	return 0;
}

int fw_authenticate(t_client *client)
{
	int rc = 0;

	debug(LOG_NOTICE, "Authenticating %s %s", client->ip, client->mac);

	// This rule is for marking upload (outgoing) packets, and for upload byte counting
	rc |= nftables_do("add rule", CHAIN_OUTGOING " ip saddr %s ether saddr %s counter ct mark set 0x%x",
			client->ip, client->mac, FW_MARK_AUTHENTICATED);

	// This rule is just for download (incoming) byte counting, see fw_counters_update()
	rc |= nftables_do("add rule", CHAIN_INCOMING " ip daddr %s ct mark set 0x%x", client->ip, FW_MARK_AUTHENTICATED);
	rc |= nftables_do("add rule", CHAIN_INCOMING " ip daddr %s counter accept", client->ip);

	return rc;
}

int fw_deauthenticate(t_client *client)
{
	unsigned long long int download_rate, packetsdown;
	int rc = 0;

	download_rate = client->download_rate;

	packetsdown = download_rate * 1024 / 1500;

	// Remove the authentication rules.
	debug(LOG_NOTICE, "Deauthenticating %s %s", client->ip, client->mac);

	rc |= nftables_delete(CHAIN_OUTGOING, "ip saddr %s ether saddr %s counter ct mark set 0x%08x",
			client->ip, client->mac, FW_MARK_AUTHENTICATED);

	rc |= nftables_delete(CHAIN_INCOMING, "ip daddr %s drop", client->ip);
	rc |= nftables_delete(CHAIN_INCOMING, "ip daddr %s ct mark set 0x%08x", client->ip, FW_MARK_AUTHENTICATED);
	rc |= nftables_delete(CHAIN_INCOMING, "ip daddr %s counter accept", client->ip);
	rc |= nftables_delete(CHAIN_INCOMING, "ip daddr %s limit rate %llu/second accept", client->ip, packetsdown);

	return rc;
}

int fw_init(void)
{
	s_config *config;
	char *gw_interface;
	const char *ICMP_TYPE;
	char *gw_address;
	char *gw_iprange;
	char *fas_remoteip = NULL;
	char *gw_ip;
	int fas_port = 0;
	int set_mss, mss_value;
	t_MAC *pt;
	t_MAC *pb;
	t_MAC *pa;
	int rc = 0;
	int macmechanism;

	debug(LOG_NOTICE, "Initializing firewall rules");

	LOCK_CONFIG();
	config = config_get_config();

	// ip4 vs ip6 differences
	if (config->ip6) {
		// ip6 addresses must be in square brackets like [ffcc:e08::1]
		safe_asprintf(&gw_ip, "[%s]", config->gw_ip); // must free
		ICMP_TYPE = "icmp6";
	} else {
		gw_ip = safe_strdup(config->gw_ip);    // must free
		ICMP_TYPE = "icmp";
	}

	if (config->fas_port) {
		fas_remoteip = safe_strdup(config->fas_remoteip);
		fas_port = config->fas_port;
	}

	gw_interface = safe_strdup(config->gw_interface);
	gw_address = safe_strdup(config->gw_address);
	gw_iprange = safe_strdup(config->gw_iprange);
	pt = config->trustedmaclist;
	pb = config->blockedmaclist;
	pa = config->allowedmaclist;
	macmechanism = config->macmechanism;
	set_mss = config->set_mss;
	mss_value = config->mss_value;
	FW_MARK_BLOCKED = config->fw_mark_blocked;
	FW_MARK_TRUSTED = config->fw_mark_trusted;
	FW_MARK_AUTHENTICATED = config->fw_mark_authenticated;
	UNLOCK_CONFIG();

	nft = nft_ctx_new(NFT_CTX_DEFAULT);
	if (nft == NULL)
		return -1;

	// Set up packet marking methods
	rc |= fw_init_marks();

	/*
	 *
	 **************************************
	 * Set up mangle table chains and rules
	 *
	 */

	// Create new chains in the mangle table
	rc |= nftables_do("add table", "");
	rc |= nftables_do("add chain",  CHAIN_MANGLE_PRE " { type filter hook prerouting priority mangle; }");
	rc |= nftables_do("add chain",  CHAIN_MANGLE_POST " { type filter hook postrouting priority mangle; }");

	rc |= nftables_do("add chain",  CHAIN_BLOCKED);
	rc |= nftables_do("add chain",  CHAIN_TRUSTED);
	rc |= nftables_do("add chain",  CHAIN_ALLOWED);
	rc |= nftables_do("add chain",  CHAIN_OUTGOING);
	rc |= nftables_do("add chain",  CHAIN_INCOMING);

	// Assign jumps to these new chains
	rc |= nftables_do("add rule", CHAIN_MANGLE_PRE " meta iifname %s ip saddr %s counter jump " CHAIN_OUTGOING, gw_interface, gw_iprange);
	rc |= nftables_do("add rule", CHAIN_MANGLE_PRE " meta iifname %s ip saddr %s jump " CHAIN_BLOCKED, gw_interface, gw_iprange);
	rc |= nftables_do("add rule", CHAIN_MANGLE_PRE " meta iifname %s ip saddr %s jump " CHAIN_TRUSTED, gw_interface, gw_iprange);
	rc |= nftables_do("add rule", CHAIN_MANGLE_POST " meta oifname %s ip daddr %s counter jump " CHAIN_INCOMING, gw_interface, gw_iprange);


	// Rules to mark as trusted MAC address packets in mangle PREROUTING
	for (; pt != NULL; pt = pt->next)
		rc |= fw_trust_mac(pt->mac);

	// Rules to mark as blocked MAC address packets in mangle PREROUTING
	if (MAC_BLOCK == macmechanism) {
		/* with the MAC_BLOCK mechanism,
		 * MAC's on the block list are marked as blocked;
		 * everything else passes */
		for (; pb != NULL; pb = pb->next) {
			rc |= fw_block_mac(pb->mac);
		}
	} else if (MAC_ALLOW == macmechanism) {
		/* with the MAC_ALLOW mechanism,
		 * MAC's on the allow list pass;
		 * everything else is to be marked as blocked
		 * So, append at end of chain a rule to mark everything blocked
		 */
		rc |= nftables_do("add rule", CHAIN_BLOCKED " ct mark set 0x%x", FW_MARK_BLOCKED);

		// But insert at beginning of chain rules to pass allowed MAC's
		for (; pa != NULL; pa = pa->next) {
			rc |= fw_allow_mac(pa->mac);
		}
	} else {
		debug(LOG_ERR, "Unknown MAC mechanism: %d", macmechanism);
		rc = -1;
	}

	/*
	 *
	 * End of mangle table chains and rules
	 **************************************
	 */

	/*
	 *
	 **************************************
	 * Set up nat table chains and rules (ip4 only)
	 *
	 */

	if (!config->ip6) {
		rc = nftables_do("add chain", CHAIN_NAT_PRE " { type nat hook prerouting priority dstnat; }");
		rc = nftables_do("add chain", CHAIN_NAT_OUTGOING);

		// packets coming in on gw_interface jump to CHAIN_OUTGOING
		rc = nftables_do("add rule", CHAIN_NAT_PRE " meta iifname %s ip saddr %s jump " CHAIN_NAT_OUTGOING, gw_interface, gw_iprange);

		// CHAIN_OUTGOING, packets marked TRUSTED, AUTHENTICATED  ACCEPT
		rc |= nftables_do("add rule", CHAIN_NAT_OUTGOING " ct mark {0x%x, 0x%x} return", FW_MARK_TRUSTED, FW_MARK_AUTHENTICATED);

		// Allow access to remote FAS - CHAIN_OUTGOING and CHAIN_TO_INTERNET packets for remote FAS, ACCEPT
		if (fas_port && strcmp(fas_remoteip, gw_ip))
			rc |= nftables_do("add rule", CHAIN_NAT_OUTGOING " ip daddr %s tcp dport %d accept", fas_remoteip, fas_port);

		// CHAIN_OUTGOING, packets for tcp port 80, redirect to gw_port on primary address for the iface
		rc |= nftables_do("add rule", CHAIN_NAT_OUTGOING " tcp dport 80 dnat to %s", gw_address);

		// CHAIN_OUTGOING, other packets ACCEPT
		rc |= nftables_do("add rule", CHAIN_NAT_OUTGOING " accept");

		if (config->gw_fqdn) {
			rc |= nftables_do("insert rule", CHAIN_NAT_OUTGOING " ip daddr %s tcp dport 80 redirect to %d",
				config->gw_ip,
				config->gw_port
			);
		}
	}
	/*
	 * End of nat table chains and rules (ip4 only)
	 **************************************
	 */

	/*
	 *
	 **************************************
	 * Set up filter table chains and rules
	 *
	 */

	// Create new chains in the filter table
	rc |= nftables_do("add chain", CHAIN_FILTER_INPUT " { type filter hook input priority filter; }" );
	rc |= nftables_do("add chain", CHAIN_TO_INTERNET);
	rc |= nftables_do("add chain", CHAIN_TO_ROUTER);
	rc |= nftables_do("add chain", CHAIN_AUTHENTICATED);
	rc |= nftables_do("add chain", CHAIN_UPLOAD_RATE);
	rc |= nftables_do("add chain", CHAIN_FILTER_TRUSTED);
	rc |= nftables_do("add chain", CHAIN_TRUSTED_TO_ROUTER);

	// filter INPUT chain

	// packets coming in on gw_interface jump to CHAIN_TO_ROUTER
	rc |= nftables_do("add rule", CHAIN_FILTER_INPUT " meta iifname %s ip saddr %s jump " CHAIN_TO_ROUTER, gw_interface, gw_iprange);

	// CHAIN_TO_ROUTER packets marked BLOCKED DROP
	rc |= nftables_do("add rule", CHAIN_TO_ROUTER " ct mark 0x%x drop", FW_MARK_BLOCKED);

	// CHAIN_TO_ROUTER, invalid packets DROP
	rc |= nftables_do("add rule", CHAIN_TO_ROUTER " ct state invalid drop");

	// CHAIN_TO_ROUTER, related and established packets ACCEPT
	rc |= nftables_do("add rule", CHAIN_TO_ROUTER " ct state related,established accept");

	// CHAIN_TO_ROUTER, packets to HTTP listening on gw_port on router ACCEPT
	rc |= nftables_do("add rule", CHAIN_TO_ROUTER " tcp dport %u accept", config->gw_port);

	// CHAIN_TO_ROUTER, packets to HTTP listening on fas_port on router ACCEPT
	if (fas_port && !strcmp(fas_remoteip, gw_ip))
		rc |= nftables_do("add rule", CHAIN_TO_ROUTER " tcp dport %d accept", fas_port);

	/* if trusted-users-to-router ruleset is empty:
	 *    use empty ruleset policy
	 * else:
	 *    jump to CHAIN_TRUSTED_TO_ROUTER, and load and use users-to-router ruleset
	 */
	if (is_empty_ruleset("trusted-users-to-router")) {
		rc |= nftables_do("add rule", CHAIN_TO_ROUTER " ct mark 0x%x %s",
				FW_MARK_TRUSTED, strlower(get_empty_ruleset_policy("trusted-users-to-router")));
	} else {
		rc |= nftables_do("add rule", CHAIN_TO_ROUTER " ct mark 0x%x jump " CHAIN_TRUSTED_TO_ROUTER, FW_MARK_TRUSTED);

		// CHAIN_TRUSTED_TO_ROUTER, related and established packets ACCEPT
		rc |= nftables_do("add rule", CHAIN_TRUSTED_TO_ROUTER " ct state related,established accept");

		// CHAIN_TRUSTED_TO_ROUTER, append the "trusted-users-to-router" ruleset
		rc |= _fw_append_ruleset("trusted-users-to-router", CHAIN_TRUSTED_TO_ROUTER);

		// CHAIN_TRUSTED_TO_ROUTER, any packets not matching that ruleset REJECT
		rc |= nftables_do("add rule", CHAIN_TRUSTED_TO_ROUTER " reject with %s type port-unreachable", ICMP_TYPE);
	}

	// CHAIN_TO_ROUTER, other packets:

	/* if users-to-router ruleset is empty:
	 *    use empty ruleset policy
	 * else:
	 *    load and use users-to-router ruleset
	 */
	if (is_empty_ruleset("users-to-router")) {
		rc |= nftables_do("add rule", CHAIN_TO_ROUTER " %s", strlower(get_empty_ruleset_policy("users-to-router")));
	} else {
		// CHAIN_TO_ROUTER, append the "users-to-router" ruleset
		rc |= _fw_append_ruleset("users-to-router", CHAIN_TO_ROUTER);

		// CHAIN_TO_ROUTER packets marked AUTHENTICATED RETURN
		rc |= nftables_do("add rule", CHAIN_TO_ROUTER " ct mark 0x%x return", FW_MARK_AUTHENTICATED);

		// everything else, REJECT
		rc |= nftables_do("add rule", CHAIN_TO_ROUTER " reject with %s type port-unreachable", ICMP_TYPE);
	}

	/*
	 * filter FORWARD chain
	 */

	// packets coming in on gw_interface jump to CHAIN_TO_INTERNET
	rc |= nftables_do("add chain", CHAIN_FILTER_FORWARD " { type filter hook forward priority filter; }");
	rc |= nftables_do("add rule",  CHAIN_FILTER_FORWARD " meta iifname %s ip saddr %s jump " CHAIN_TO_INTERNET, gw_interface, gw_iprange);

	// CHAIN_TO_INTERNET packets marked BLOCKED DROP
	rc |= nftables_do("add rule", CHAIN_TO_INTERNET " ct mark 0x%x drop", FW_MARK_BLOCKED);

	// CHAIN_TO_INTERNET, invalid packets DROP
	rc |= nftables_do("add rule", CHAIN_TO_INTERNET " ct state invalid drop");

	// CHAIN_TO_INTERNET, deal with MSS
	if (set_mss) {
		/* XXX this mangles, so 'should' be done in the mangle POSTROUTING chain.
		 * However OpenWRT standard S35firewall does it in filter FORWARD,
		 * and since we are pre-empting that chain here, we put it in */
		if (mss_value > 0) { // set specific MSS value
			rc |= nftables_do("add rule", CHAIN_TO_INTERNET " tcp flags syn tcp option maxseg size set %d", mss_value);
		} else { // allow MSS as large as possible
			rc |= nftables_do("add rule", CHAIN_TO_INTERNET " tcp flags syn,rst tcp option maxseg size set rt mtu");
		}
	}


	// Allow access to remote FAS - CHAIN_TO_INTERNET packets for remote FAS, ACCEPT
	if (fas_port && strcmp(fas_remoteip, gw_ip))
		rc |= nftables_do("add rule", CHAIN_TO_INTERNET " ip daddr %s tcp dport %d accept", fas_remoteip, fas_port);

	// TODO: ipset support (walledgarden)
#if 0
	t_WGP *allowed_wgport;

	// Allow access to Walled Garden ipset - CHAIN_TO_INTERNET packets for Walled Garden, ACCEPT
	if (config->walledgarden_fqdn_list != NULL && config->walledgarden_port_list == NULL)
		rc |= nftables_do("insert rule", CHAIN_TO_INTERNET " ip filter input tcp dport @walledgarden accept");
		rc |= iptables_do_command("-t filter -I " CHAIN_TO_INTERNET " -m set --match-set walledgarden dst -j ACCEPT");

	// Compile walledgarden tcp dest port set
	if (config->walledgarden_fqdn_list != NULL && config->walledgarden_port_list != NULL) {
		for (allowed_wgport = config->walledgarden_port_list; allowed_wgport != NULL; allowed_wgport = allowed_wgport->next) {
			debug(LOG_INFO, "Nftables: walled garden port [%u]", allowed_wgport->wgport);
			rc |= nftables_do("insert rule", CHAIN_TO_INTERNET " tcp dport %u ip filter output ip daddr @walledgarden accept",
			//rc |= nftables_do_command("-t filter -I " CHAIN_TO_INTERNET " -p tcp --dport %u -m set --match-set walledgarden dst -j ACCEPT",
				allowed_wgport->wgport
			);
		}
	}
#endif

	// CHAIN_TO_INTERNET, packets marked TRUSTED:

	/* if trusted-users ruleset is empty:
	 *    use empty ruleset policy
	 * else:
	 *    jump to CHAIN_TRUSTED, and load and use trusted-users ruleset
	 */
	if (is_empty_ruleset("trusted-users")) {
		rc |= nftables_do("add rule", CHAIN_TO_INTERNET " ct mark 0x%x %s",
				FW_MARK_TRUSTED, strlower(get_empty_ruleset_policy("trusted-users")));
	} else {
		rc |= nftables_do("add rule", CHAIN_TO_INTERNET " ct mark 0x%x jump " CHAIN_FILTER_TRUSTED, FW_MARK_TRUSTED);

		// CHAIN_TRUSTED, related and established packets ACCEPT
		rc |= nftables_do("add rule", CHAIN_FILTER_TRUSTED" ct state related,established accept");
		// CHAIN_TRUSTED, append the "trusted-users" ruleset
		rc |= _fw_append_ruleset("trusted-users", CHAIN_FILTER_TRUSTED);
		// CHAIN_TRUSTED, any packets not matching that ruleset REJECT
		rc |= nftables_do("add rule", CHAIN_FILTER_TRUSTED" reject with %s type port-unreachable", ICMP_TYPE);
	}

	// Add basic rule to CHAIN_UPLOAD_RATE for upload rate limiting
	rc |= nftables_do("add rule", CHAIN_UPLOAD_RATE " return");

	// CHAIN_TO_INTERNET, packets marked AUTHENTICATED:

	/* if authenticated-users ruleset is empty:
	 *    use empty ruleset policy
	 * else:
	 *    jump to CHAIN_AUTHENTICATED, and load and use authenticated-users ruleset
	 */
	if (is_empty_ruleset("authenticated-users")) {
		rc |= nftables_do("add rule", CHAIN_TO_INTERNET " ct mark 0x%x %s",
			FW_MARK_AUTHENTICATED, strlower(get_empty_ruleset_policy("authenticated-users")));
	} else {
		rc |= nftables_do("add rule", CHAIN_TO_INTERNET " ct mark 0x%x goto " CHAIN_AUTHENTICATED, FW_MARK_AUTHENTICATED);

		// CHAIN_AUTHENTICATED, jump to CHAIN_UPLOAD_RATE to handle upload rate limiting
		rc |= nftables_do("add rule", CHAIN_AUTHENTICATED " jump  " CHAIN_UPLOAD_RATE);
		// CHAIN_AUTHENTICATED, related and established packets ACCEPT
		rc |= nftables_do("add rule", CHAIN_AUTHENTICATED " ct state related,established accept");
		// CHAIN_AUTHENTICATED, append the "authenticated-users" ruleset
		rc |= _fw_append_ruleset("authenticated-users", CHAIN_AUTHENTICATED);
		// CHAIN_AUTHENTICATED, any packets not matching that ruleset REJECT
		rc |= nftables_do("add rule", CHAIN_AUTHENTICATED " reject with %s type port-unreachable", ICMP_TYPE);
	}

	// CHAIN_TO_INTERNET, other packets:

	/* if preauthenticated-users ruleset is empty:
	 *    use empty ruleset policy
	 * else:
	 *    load and use authenticated-users ruleset
	 */

	if (is_empty_ruleset("preauthenticated-users"))
		rc |= nftables_do("add rule", CHAIN_TO_INTERNET " %s", strlower(get_empty_ruleset_policy("preauthenticated-users")));
	else
		rc |= _fw_append_ruleset("preauthenticated-users", CHAIN_TO_INTERNET);

	// CHAIN_TO_INTERNET, all other packets REJECT
	rc |= nftables_do("add rule", CHAIN_TO_INTERNET " reject with %s type port-unreachable", ICMP_TYPE);

	/*
	 * End of filter table chains and rules
	 **************************************
	 */
	free(gw_ip);
	free(gw_iprange);
	free(gw_address);
	free(gw_interface);
	free(fas_remoteip);

	return rc;
}

/** Remove the firewall rules
 * This is used when we do a clean shutdown of opennds,
 * and when it starts, to make sure there are no rules left over from a crash
 */
int fw_destroy(void)
{
	debug(LOG_DEBUG, "Destroying our nftables entries");

	/* In case we got called on start, before fw_init()
	 */
	if (nft == NULL) {
		nft = nft_ctx_new(NFT_CTX_DEFAULT);
		if (nft == NULL)
			return -1;
	}

	/* Flushes the whole opennds table */
	nftables_do("delete table", "");
	nft_ctx_free(nft);
	nft = NULL;

	return 0;
}

// Return the total upload usage in bytes
unsigned long long int fw_total_upload()
{
	return nftables_get_counter_bytes(CHAIN_MANGLE_PRE, CHAIN_OUTGOING);
}

// Return the total download usage in bytes
unsigned long long int fw_total_download()
{
	return nftables_get_counter_bytes(CHAIN_MANGLE_POST, CHAIN_INCOMING);
}

static const char * str_getline(char *dst, size_t len, const char *src)
{
	size_t i;

	for (i = 0; src[i] && src[i] != '\n' && i < len; i++)
		dst[i] = src[i];

	dst[i] = 0;

	if (src[i])
		i++;

	return src + i;
}

static int __fw_counters_update(const char *chain, time_t t_now, int outgoing)
{
	const char *buf = nftables_list(chain, 0);
	char line[128];

	if (buf == NULL) {
		nft_ctx_unbuffer_output(nft);
		return -1;
	}

	while (*(buf = str_getline(line, sizeof(line), buf))) {
		char proto[4];
		char addr_type[8];
		char addr[64];
		t_client *client;
		unsigned long long bytes;
		int n;

		proto[0] = 0;
		addr_type[0] = 0;
		addr_type[1] = 0;
		addr[0] = 0;
		bytes = 0;

		n = sscanf(line, "%3s %7s %63s", proto, addr_type, addr);
		if (n != 3 || strcmp(proto, "ip") || strcmp(addr_type + 1, "addr"))
			continue;

		client = client_list_find_by_ip(addr);
		if (client) {
			bytes = nftables_parse_counter_bytes(line + 32);
			unsigned long long *counter;

			if (outgoing)
				counter = &client->counters.outgoing;
			else
				counter = &client->counters.incoming;

			if (bytes > 0 && bytes != *counter) {
				*counter = bytes;
				client->counters.last_updated = t_now;

				debug(LOG_DEBUG, "%s - Updated counter.%s to %llu bytes",
					addr, outgoing ? "outgoing" : "incoming", bytes);
			}
		}
	}
	nft_ctx_unbuffer_output(nft);
	return 0;
}

static int renew_nftables_ctx()
{
	if (nft)
		nft_ctx_free(nft);

	nft = nft_ctx_new(NFT_CTX_DEFAULT);
	return nft != NULL;
}

// Update the counters of all the clients in the client list
int fw_counters_update(void)
{
	const time_t t_now = time(NULL);
	int rc;

	/* Renew libnftables context to avoid cached counters */
	if (!renew_nftables_ctx())
		return -1;

	LOCK_CLIENT_LIST();
	rc = __fw_counters_update(CHAIN_OUTGOING, t_now, 0);
	rc |= __fw_counters_update(CHAIN_INCOMING, t_now, 1);
	UNLOCK_CLIENT_LIST();

	return rc;
}
