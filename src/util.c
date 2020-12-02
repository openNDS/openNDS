/********************************************************************\
 * This program is free software; you can redistribute it and/or    *
 * modify it under the terms of the GNU General Public License as   *
 * published by the Free Software Foundation; either version 2 of   *
 * the License, or (at your option) any later version.              *
 *                                                                  *
 * This program is distributed in the hope that it will be useful,  *
 * but WITHOUT ANY WARRANTY; without even the implied warranty of   *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the    *
 * GNU General Public License for more details.                     *
 *                                                                  *
 * You should have received a copy of the GNU General Public License*
 * along with this program; if not, contact:                        *
 *                                                                  *
 * Free Software Foundation           Voice:  +1-617-542-5942       *
 * 59 Temple Place - Suite 330        Fax:    +1-617-542-2652       *
 * Boston, MA  02111-1307,  USA       gnu@gnu.org                   *
 *                                                                  *
 \********************************************************************/

/**
  @file util.c
  @brief Misc utility functions
  @author Copyright (C) 2004 Philippe April <papril777@yahoo.com>
  @author Copyright (C) 2006 Benoit Grégoire <bock@step.polymtl.ca>
  @author Copyright (C) 2008 Paul Kube <nodogsplash@kokoro.ucsd.edu>
 */

#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <syslog.h>
#include <errno.h>
#include <pthread.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <sys/ioctl.h>
#include <arpa/inet.h>
#include <sys/time.h>
#include <ifaddrs.h>
#include <unistd.h>

#if defined(__NetBSD__)
#include <sys/socket.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <util.h>
#endif

#ifdef __linux__
#include <netinet/in.h>
#include <net/if.h>
#endif

#include <string.h>
#include <pthread.h>
#include <netdb.h>

#include "common.h"
#include "client_list.h"
#include "safe.h"
#include "util.h"
#include "conf.h"
#include "debug.h"
#include "fw_iptables.h"


// Defined in main.c
extern time_t started_time;

// Defined in clientlist.c
extern pthread_mutex_t client_list_mutex;
extern pthread_mutex_t config_mutex;

// Defined in auth.c
extern unsigned int authenticated_since_start;

// Defined in main.c
extern int created_httpd_threads;
extern int current_httpd_threads;

int get_client_interface(char* clientif, int clientif_len, const char *climac)
{
	char *clifcmd = NULL;

	safe_asprintf(&clifcmd, "/usr/lib/opennds/get_client_interface.sh %s", climac);

	if (execute_ret_url_encoded(clientif, clientif_len - 1, clifcmd) == 0) {
		debug(LOG_DEBUG, "Client Mac Address: %s", climac);
		debug(LOG_DEBUG, "Client Connection(s) [localif] [remotemeshnodemac] [localmeshif]: %s", clientif);
	} else {
		debug(LOG_ERR, "Failed to get client connections - client probably offline");
		free (clifcmd);
		return -1;
	}
	free (clifcmd);
	return 0;
}


int hash_str(char* hash, int hash_len, const char *src)
{
	char *hashcmd = NULL;

	s_config *config = config_get_config();

	safe_asprintf(&hashcmd, "printf '%s' | %s | awk -F' ' '{printf $1}'", src, config->fas_hid);

	if (execute_ret_url_encoded(hash, hash_len - 1, hashcmd) == 0) {
		debug(LOG_DEBUG, "Source string: %s", src);
		debug(LOG_DEBUG, "Hashed string: %s", hash);
	} else {
		debug(LOG_ERR, "Failed to hash string");
		free (hashcmd);
		return -1;
	}
	free (hashcmd);
	return 0;
}


static int _execute_ret(char* msg, int msg_len, const char *cmd)
{
	struct sigaction sa, oldsa;
	FILE *fp;
	int rc;

	debug(LOG_DEBUG, "Executing command: %s", cmd);

	// Temporarily get rid of SIGCHLD handler (see main.c), until child exits.
	debug(LOG_DEBUG,"Setting default SIGCHLD handler SIG_DFL");
	sa.sa_handler = SIG_DFL;
	sigemptyset(&sa.sa_mask);
	sa.sa_flags = SA_NOCLDSTOP | SA_RESTART;
	if (sigaction(SIGCHLD, &sa, &oldsa) == -1) {
		debug(LOG_ERR, "sigaction() failed to set default SIGCHLD handler: %s", strerror(errno));
	}

	fp = popen(cmd, "r");
	if (fp == NULL) {
		debug(LOG_ERR, "popen(): %s", strerror(errno));
		rc = -1;
		goto abort;
	}

	if (msg && msg_len > 0) {
		rc = fread(msg, msg_len - 1, 1, fp);
	}

	rc = pclose(fp);

	if (WIFSIGNALED(rc) != 0) {
		debug(LOG_WARNING, "Command process exited due to signal %d", WTERMSIG(rc));
	}

	rc = WEXITSTATUS(rc);

abort:

	// Restore signal handler
	if (sigaction(SIGCHLD, &oldsa, NULL) == -1) {
		debug(LOG_ERR, "sigaction() failed to restore SIGCHLD handler! Error %s", strerror(errno));
	}

	return rc;
}

int execute(const char fmt[], ...)
{
	char cmd[QUERYMAXLEN];
	va_list vlist;
	int rc;

	va_start(vlist, fmt);
	rc = vsnprintf(cmd, sizeof(cmd), fmt, vlist);
	va_end(vlist);

	if (rc < 0 || rc >= sizeof(cmd)) {
		debug(LOG_ERR, "Format string too small or encoding error.");
		return -1;
	}

	return _execute_ret(NULL, 0, cmd);
}

int execute_ret(char* msg, int msg_len, const char fmt[], ...)
{
	char cmd[QUERYMAXLEN];
	va_list vlist;
	int rc;

	va_start(vlist, fmt);
	rc = vsnprintf(cmd, sizeof(cmd), fmt, vlist);
	va_end(vlist);

	if (rc < 0 || rc >= sizeof(cmd)) {
		debug(LOG_ERR, "Format string too small or encoding error.");
		return -1;
	}

	return _execute_ret(msg, msg_len, cmd);
}

/* Warning: Any client originated portion of the cmd string must be url encoded before calling this function.
 It may not be desired to url encode the entire cmd string,
 so it is our responsibility to encode the relevant parts (eg the clients original request url) before calling.
 */
int execute_ret_url_encoded(char* msg, int msg_len, const char *cmd)
{
	return _execute_ret(msg, msg_len, cmd);
}


char *
get_iface_ip(const char ifname[], int ip6)
{
	char addrbuf[INET6_ADDRSTRLEN] = {0};
	char cmd[128] = {0};
	char iptype[8] = {0};
	int i;

	if (ip6) {
		snprintf(iptype, sizeof(iptype), "inet6");
	} else {
		snprintf(iptype, sizeof(iptype), "inet");
 	}

	snprintf(cmd, sizeof(cmd), "ip address | grep -A2 ': %s' | grep '%s ' | awk '$NF == \"%s\" {print $2}' | awk -F'/' 'NR==1 {printf $1}'",
		ifname,
		iptype,
		ifname
	);

	debug(LOG_NOTICE, "Attempting to Bind to interface: %s", ifname);

	for (i=0; i<10; i=i+1) {
		execute_ret(addrbuf, sizeof(addrbuf), cmd);
		if (is_addr(addrbuf) == 1) {
			break;
		} else {
			debug(LOG_NOTICE, "Interface: %s is not yet ready - waiting...", ifname);
			sleep(1);
		}
	}

	return safe_strdup(addrbuf);
}

char *
get_iface_mac(const char ifname[])
{
	char addrbuf[18] = {0};
	char cmd[128] = {0};

	snprintf(cmd, sizeof(cmd), "ip address | grep -A1 '%s:' | grep 'link/ether ' | awk '{print $2}' | awk -F'/' '{printf $1}'",
		ifname
	);

	execute_ret(addrbuf, sizeof(addrbuf), cmd);
	return safe_strdup(addrbuf);
}

/** Get name of external interface (the one with default route to the net).
 *  Caller must free.
 */
char *
get_ext_iface(void)
{
#ifdef __linux__
	FILE *input;
	char device[16] = {0};
	char gw[16] = {0};
	int i = 1;
	pthread_cond_t cond = PTHREAD_COND_INITIALIZER;
	pthread_mutex_t cond_mutex = PTHREAD_MUTEX_INITIALIZER;
	struct timespec timeout;

	debug(LOG_DEBUG, "get_ext_iface(): Autodectecting the external interface from routing table");
	for (i = 1; i <= NUM_EXT_INTERFACE_DETECT_RETRY; i += 1) {
		input = fopen("/proc/net/route", "r");
		while (!feof(input)) {
			int rc = fscanf(input, "%s %s %*s %*s %*s %*s %*s %*s %*s %*s %*s\n", device, gw);
			if (rc == 2 && strcmp(gw, "00000000") == 0) {
				fclose(input);
				debug(LOG_INFO, "get_ext_iface(): Detected %s as the default interface after try %d", device, i);
				return strdup(device);
			}
		}
		fclose(input);
		debug(LOG_ERR, "get_ext_iface(): Failed to detect the external interface after try %d (maybe the interface is not up yet?).  Retry limit: %d", i, NUM_EXT_INTERFACE_DETECT_RETRY);

		// Sleep for EXT_INTERFACE_DETECT_RETRY_INTERVAL seconds
		timeout.tv_sec = time(NULL) + EXT_INTERFACE_DETECT_RETRY_INTERVAL;
		timeout.tv_nsec = 0;

		// Mutex must be locked for pthread_cond_timedwait...
		pthread_mutex_lock(&cond_mutex);
		// Thread safe "sleep"
		pthread_cond_timedwait(&cond, &cond_mutex, &timeout);
		// No longer needs to be locked
		pthread_mutex_unlock(&cond_mutex);
	}

	debug(LOG_ERR, "get_ext_iface(): Failed to detect the external interface after %d tries, aborting", i);
	exit(1);
#endif
	return NULL;
}

char *
format_duration(time_t from, time_t to, char buf[64])
{
	int days, hours, minutes, seconds;
	long long int secs;
	const char *neg = "";

	if (from <= to) {
		secs = to - from;
	} else {
		secs = from - to;
		// Prepend minus sign
		neg = "-";
	}

	days = secs / (24 * 60 * 60);
	secs -= days * (24 * 60 * 60);
	hours = secs / (60 * 60);
	secs -= hours * (60 * 60);
	minutes = secs / 60;
	secs -= minutes * 60;
	seconds = secs;

	if (days > 0) {
		snprintf(buf, 64, "%s%dd %dh %dm %ds", neg, days, hours, minutes, seconds);
	} else if (hours > 0) {
		snprintf(buf, 64, "%s%dh %dm %ds", neg, hours, minutes, seconds);
	} else if (minutes > 0) {
		snprintf(buf, 64, "%s%dm %ds", neg, minutes, seconds);
	} else {
		snprintf(buf, 64, "%s%ds", neg, seconds);
	}

	return buf;
}

char *
format_time(time_t time, char buf[64])
{
	strftime(buf, 64, "%a %b %d %H:%M:%S %Y", localtime(&time));
	return buf;
}

char * get_uptime_string(char buf[64]) {
	time_t sysuptime;
	unsigned long int now, uptimesecs;

	sysuptime = get_system_uptime ();
	now = time(NULL);

	debug(LOG_DEBUG, "Uncorrected NDS Uptime: %li seconds ", (now - started_time));

	if ((now - started_time) > sysuptime) {
		uptimesecs = sysuptime;
	} else {
		uptimesecs = now - started_time;
	}

	return format_duration((now - uptimesecs), now, buf);
}

time_t get_system_uptime() {
	time_t sysuptime;
	char buf[64];
	FILE *pfp;

	pfp = fopen ("/proc/uptime", "r");

	if (pfp != NULL) {
		(void) fgets (buf, sizeof(buf), pfp);
		sysuptime = atol(strtok(buf, "."));
		debug(LOG_DEBUG, "Operating System Uptime: %li seconds ", sysuptime);
		fclose (pfp);
		return sysuptime;
	}

	debug(LOG_WARNING, "Unable to determine System Uptime.");
	return -1;
}


int is_addr(const char* addr) {
	struct sockaddr_in sa;
	struct sockaddr_in6 sa6;

	return (inet_pton(AF_INET, addr, &sa.sin_addr) == 1) ||
		(inet_pton(AF_INET6, addr, &sa6.sin6_addr) == 1);
}

void
ndsctl_status(FILE *fp)
{
	char timebuf[32];
	char durationbuf[64];
	s_config *config;
	t_client *client;
	int indx;
	unsigned long int now, uptimesecs, durationsecs = 0;
	unsigned long long int download_bytes, upload_bytes;
	t_MAC *trust_mac;
	t_MAC *allow_mac;
	t_MAC *block_mac;
	time_t sysuptime;
	t_WGP *allowed_wgport;
	t_WGFQDN *allowed_wgfqdn;

	config = config_get_config();

	fprintf(fp, "==================\nopenNDS Status\n====\n");
	sysuptime = get_system_uptime ();
	now = time(NULL);

	debug(LOG_DEBUG, "Uncorrected Uptime: %li seconds ", (now - started_time));

	if ((now - started_time) > sysuptime) {
		uptimesecs = sysuptime;
	} else {
		uptimesecs = now - started_time;
	}

	fprintf(fp, "Version: " VERSION "\n");

	format_duration(0, uptimesecs, durationbuf);

	fprintf(fp, "Uptime: %s\n", durationbuf);
	fprintf(fp, "Gateway Name: %s\n", config->gw_name);
	fprintf(fp, "Managed interface: %s\n", config->gw_interface);
	fprintf(fp, "Managed IP range: %s\n", config->gw_iprange);
	fprintf(fp, "Server listening: http://%s\n", config->gw_address);

	if (config->binauth) {
		fprintf(fp, "Binauth Script: %s\n", config->binauth);
	} else {
		fprintf(fp, "Binauth: Disabled\n");
	}

	if (config->preauth) {
		fprintf(fp, "Preauth Script: %s\n", config->preauth);
	} else {
		fprintf(fp, "Preauth: Disabled\n");
	}

	if (config->fas_port) {
		fprintf(fp, "FAS: Secure Level %u, URL: %s\n",
			config->fas_secure_enabled,
			config->fas_url);
	} else {
		fprintf(fp, "FAS: Disabled\n");
	}

	fprintf(fp, "Client Check Interval: %ds\n", config->checkinterval);
	fprintf(fp, "Rate Check Window: %d check intervals (%ds)\n", config->rate_check_window, (config->rate_check_window * config->checkinterval));
	fprintf(fp, "Preauthenticated Client Idle Timeout: %dm\n", config->preauth_idle_timeout);
	fprintf(fp, "Authenticated Client Idle Timeout: %dm\n", config->auth_idle_timeout);

	if (config->redirectURL) {
		fprintf(fp, "Redirect URL: %s\n", config->redirectURL);
	}

	if (config->download_rate > 0) {
		fprintf(fp, "Download rate limit (default per client): %llu kbit/s\n", config->download_rate);
	} else {
		fprintf(fp, "Download rate limit (default per client): no limit\n");
	}
	if (config->upload_rate > 0) {
		fprintf(fp, "Upload rate limit (default per client): %llu kbit/s\n", config->upload_rate);
	} else {
		fprintf(fp, "Upload rate limit (default per client): no limit\n");
	}

	if (config->download_quota > 0) {
		fprintf(fp, "Download quota (default per client): %llu kB\n", config->download_quota);
	} else {
		fprintf(fp, "Download quota (default per client): no limit\n");
	}
	if (config->upload_quota > 0) {
		fprintf(fp, "Upload quota (default per client): %llu kB\n", config->upload_quota);
	} else {
		fprintf(fp, "Upload quota (default per client): no limit\n");
	}


	download_bytes = iptables_fw_total_download();
	fprintf(fp, "Total download: %llu kByte", download_bytes / 1000);
	fprintf(fp, "; avg: %.2f kbit/s\n", ((double) download_bytes) / 125 / uptimesecs);

	upload_bytes = iptables_fw_total_upload();
	fprintf(fp, "Total upload: %llu kByte", upload_bytes / 1000);
	fprintf(fp, "; avg: %.2f kbit/s\n", ((double) upload_bytes) / 125 / uptimesecs);
	fprintf(fp, "====\n");
	fprintf(fp, "Client authentications since start: %u\n", authenticated_since_start);

	// Update the client's counters so info is current
	iptables_fw_counters_update();

	LOCK_CLIENT_LIST();

	fprintf(fp, "Current clients: %d\n", get_client_list_length());

	client = client_get_first_client();
	if (client) {
		fprintf(fp, "\n");
	}

	indx = 0;
	while (client != NULL) {
		fprintf(fp, "Client %d\n", indx);

		fprintf(fp, "  IP: %s MAC: %s\n", client->ip, client->mac);

		format_time(client->counters.last_updated, timebuf);
		format_duration(client->counters.last_updated, now, durationbuf);
		fprintf(fp, "  Last Activity: %s (%s ago)\n", timebuf, durationbuf);

		if (client->session_start) {
			format_time(client->session_start, timebuf);
			format_duration(client->session_start, now, durationbuf);
			fprintf(fp, "  Session Start: %s (%s ago)\n", timebuf, durationbuf);
		} else {
			fprintf(fp, "  Session Start: -\n");
		}

		if (client->session_end) {
			format_time(client->session_end, timebuf);
			format_duration(now, client->session_end, durationbuf);
			fprintf(fp, "  Session End:   %s (%s left)\n", timebuf, durationbuf);
		} else {
			fprintf(fp, "  Session End:   -\n");
		}

		fprintf(fp, "  Token: %s\n", client->token ? client->token : "none");
		fprintf(fp, "  State: %s\n", fw_connection_state_as_string(client->fw_connection_state));

		if (client->upload_rate == 0) {
			fprintf(fp, "  Upload rate limit: not set\n");
		} else {
			fprintf(fp, "  Upload rate limit: %llu kb/s\n", client->upload_rate);
		}

		if (client->download_rate == 0) {
			fprintf(fp, "  Download rate limit: not set\n");
		} else {
			fprintf(fp, "  Download rate limit: %llu kb/s\n", client->download_rate);
		}

		if (client->upload_quota == 0) {
			fprintf(fp, "  Upload quota: not set\n");
		} else {
			fprintf(fp, "  Upload quota: %llu kB\n", client->upload_quota);
		}

		if (client->download_quota == 0) {
			fprintf(fp, "  Download quota: not set\n");
		} else {
			fprintf(fp, "  Download quota: %llu kB\n", client->download_quota);
		}

		download_bytes = client->counters.incoming;
		upload_bytes = client->counters.outgoing;
		durationsecs = now - client->session_start;

		// prevent divison by 0
		if (durationsecs < 1) {
			durationsecs = 1;
		}

		fprintf(fp, "  Upload this session: %llu kB; Session avg: %.2f kb/s\n",
			upload_bytes / 1000,
			((double)upload_bytes) / 125 / durationsecs)
		;

		fprintf(fp, "  Download this session: %llu kB; Session avg: %.2f kb/s\n\n",
			download_bytes / 1000,
			((double)download_bytes) / 125 / durationsecs)
		;

		indx++;
		client = client->next;
	}

	UNLOCK_CLIENT_LIST();

	fprintf(fp, "====\n");

	fprintf(fp, "Blocked MAC addresses:");

	if (config->macmechanism == MAC_ALLOW) {
		fprintf(fp, " N/A\n");
	} else  if (config->blockedmaclist != NULL) {
		fprintf(fp, "\n");
		for (block_mac = config->blockedmaclist; block_mac != NULL; block_mac = block_mac->next) {
			fprintf(fp, "  %s\n", block_mac->mac);
		}
	} else {
		fprintf(fp, " none\n");
	}

	fprintf(fp, "Allowed MAC addresses:");

	if (config->macmechanism == MAC_BLOCK) {
		fprintf(fp, " N/A\n");
	} else  if (config->allowedmaclist != NULL) {
		fprintf(fp, "\n");
		for (allow_mac = config->allowedmaclist; allow_mac != NULL; allow_mac = allow_mac->next) {
			fprintf(fp, "  %s\n", allow_mac->mac);
		}
	} else {
		fprintf(fp, " none\n");
	}

	fprintf(fp, "Trusted MAC addresses:");

	if (config->trustedmaclist != NULL) {
		fprintf(fp, "\n");
		for (trust_mac = config->trustedmaclist; trust_mac != NULL; trust_mac = trust_mac->next) {
			fprintf(fp, "  %s\n", trust_mac->mac);
		}
	} else {
		fprintf(fp, " none\n");
	}

	fprintf(fp, "Walled Garden FQDNs:");

	if (config->walledgarden_fqdn_list != NULL) {
		fprintf(fp, "\n");
		for (allowed_wgfqdn = config->walledgarden_fqdn_list; allowed_wgfqdn != NULL; allowed_wgfqdn = allowed_wgfqdn->next) {
			fprintf(fp, "  %s\n", allowed_wgfqdn->wgfqdn);
		}
	} else {
		fprintf(fp, " none\n");
	}

	fprintf(fp, "Walled Garden Ports:");

	if (config->walledgarden_port_list != NULL) {
		fprintf(fp, "\n");
		for (allowed_wgport = config->walledgarden_port_list; allowed_wgport != NULL; allowed_wgport = allowed_wgport->next) {
			fprintf(fp, "  %u\n", allowed_wgport->wgport);
		}
	} else {
		fprintf(fp, " none\n");
	}

	fprintf(fp, "========\n");
}

// TODO Deprecated ndsctl clients, remove at future date
void
ndsctl_clients(FILE *fp)
{
	t_client *client;
	int indx;
	unsigned long int now, durationsecs = 0;
	unsigned long long int download_bytes, upload_bytes;

	now = time(NULL);

	// Update the client's counters so info is current
	iptables_fw_counters_update();

	LOCK_CLIENT_LIST();

	fprintf(fp, "%d\n", get_client_list_length());

	client = client_get_first_client();
	if (client) {
		fprintf(fp, "\n");
	}

	indx = 0;
	while (client != NULL) {
		fprintf(fp, "client_id=%d\n", indx);
		fprintf(fp, "ip=%s\nmac=%s\n", client->ip, client->mac);
		fprintf(fp, "added=%lld\n", (long long) client->session_start);
		fprintf(fp, "active=%lld\n", (long long) client->counters.last_updated);
		if (client->session_start) {
			fprintf(fp, "duration=%lu\n", now - client->session_start);
		} else {
			fprintf(fp, "duration=%lu\n", 0ul);
		}
		fprintf(fp, "token=%s\n", client->token ? client->token : "none");
		fprintf(fp, "state=%s\n", fw_connection_state_as_string(client->fw_connection_state));

		durationsecs = now - client->session_start;
		download_bytes = client->counters.incoming;
		upload_bytes = client->counters.outgoing;

		fprintf(fp, "downloaded=%llu\n", download_bytes/1000);
		fprintf(fp, "avg_down_speed=%.2f\n", ((double)download_bytes) / 125 / durationsecs);
		fprintf(fp, "uploaded=%llu\n", upload_bytes/1000);
		fprintf(fp, "avg_up_speed=%.2f\n\n", ((double)upload_bytes) / 125 / durationsecs);

		fprintf(fp, "Warning - ndsctl clients is deprecated and will be removed in future versions.\n");
		fprintf(fp, "Please use status or json options instead.\n\n");

		indx++;
		client = client->next;
	}

	UNLOCK_CLIENT_LIST();
}

static void
ndsctl_json_client(FILE *fp, const t_client *client, time_t now, char *indent)
{
	unsigned long int durationsecs;
	unsigned long long int download_bytes, upload_bytes;
	char clientif[64] = {0};
	s_config *config;

	config = config_get_config();
	get_client_interface(clientif, sizeof(clientif), client->mac);

	fprintf(fp, "  %s\"gatewayname\":\"%s\",\n", indent, config->url_encoded_gw_name);
	fprintf(fp, "  %s\"version\":\"%s\",\n", indent, VERSION);
	fprintf(fp, "  %s\"mac\":\"%s\",\n", indent, client->mac);
	fprintf(fp, "  %s\"ip\":\"%s\",\n", indent, client->ip);
	fprintf(fp, "  %s\"clientif\":\"%s\",\n", indent, clientif);
	fprintf(fp, "  %s\"session_start\":\"%lld\",\n", indent, (long long) client->session_start);
	fprintf(fp, "  %s\"session_end\":\"%lld\",\n", indent, (long long) client->session_end);
	fprintf(fp, "  %s\"last_active\":\"%lld\",\n", indent, (long long) client->counters.last_updated);
	fprintf(fp, "  %s\"token\":\"%s\",\n", indent, client->token ? client->token : "none");
	fprintf(fp, "  %s\"state\":\"%s\",\n", indent, fw_connection_state_as_string(client->fw_connection_state));

	durationsecs = now - client->session_start;
	download_bytes = client->counters.incoming;
	upload_bytes = client->counters.outgoing;

	if (client->upload_rate == 0) {
		fprintf(fp, "  %s\"upload_rate_limit\":\"null\",\n", indent);
	} else {
		fprintf(fp, "  %s\"upload_rate_limit\":\"%llu\",\n", indent, client->upload_rate);
	}

	if (client->download_rate == 0) {
		fprintf(fp, "  %s\"download_rate_limit\":\"null\",\n", indent);
	} else {
		fprintf(fp, "  %s\"download_rate_limit\":\"%llu\",\n", indent, client->download_rate);
	}

	if (client->upload_quota == 0) {
		fprintf(fp, "  %s\"upload_quota\":\"null\",\n", indent);
	} else {
		fprintf(fp, "  %s\"upload_quota\":\"%llu\",\n", indent, client->upload_quota);
	}

	if (client->download_quota == 0) {
		fprintf(fp, "  %s\"download_quota\":\"null\",\n", indent);
	} else {
		fprintf(fp, "  %s\"download_quota\":\"%llu\",\n", indent, client->download_quota);
	}

	// prevent divison by 0
	if (durationsecs < 1) {
		durationsecs = 1;
	}

	fprintf(fp, "  %s\"upload_this_session\":\"%llu\",\n",
		indent,
		(upload_bytes / 1000)
	);

	fprintf(fp, "  %s\"upload_session_avg\":\"%.2f\",\n",
		indent,
		(double)upload_bytes / 125 / durationsecs
	);

	fprintf(fp, "  %s\"download_this_session\":\"%llu\",\n",
		indent,
		(download_bytes / 1000)
	);

	fprintf(fp, "  %s\"download_session_avg\":\"%.2f\"\n",
		indent,
		(double)download_bytes / 125 / durationsecs
	);
}

static void
ndsctl_json_one(FILE *fp, const char *arg, char *indent)
{
	t_client *client;
	time_t now;
	now = time(NULL);

	// Update the client's counters so info is current
	iptables_fw_counters_update();

	LOCK_CLIENT_LIST();

	client = client_list_find_by_any(arg, arg, arg);

	if (client) {
		fprintf(fp, "{\n");
		ndsctl_json_client(fp, client, now, indent);
		fprintf(fp, "}\n");
	} else {
		fprintf(fp, "{}\n");
	}

	UNLOCK_CLIENT_LIST();
}

static void
ndsctl_json_all(FILE *fp, char *indent)
{
	t_client *client;
	time_t now;
	t_MAC *trust_mac;
	s_config *config;
	int count = 0;

	now = time(NULL);

	config = config_get_config();

	// Update the client's counters so info is current
	iptables_fw_counters_update();

	LOCK_CLIENT_LIST();

	fprintf(fp, "{\n  \"client_list_length\":\"%d\",\n", get_client_list_length());

	client = client_get_first_client();

	fprintf(fp, "  \"clients\":{\n");

	while (client != NULL) {
		fprintf(fp, "%s\"%s\":{\n", indent, client->mac);
		ndsctl_json_client(fp, client, now, indent);

		client = client->next;
		if (client) {
			fprintf(fp, "%s},\n", indent);
		} else {
			fprintf(fp, "%s}\n", indent);
		}
	}

	fprintf(fp, "  }\n");

	UNLOCK_CLIENT_LIST();

	// Trusted mac list
	if (config->trustedmaclist != NULL) {

		// count the number of trusted mac addresses
		for (trust_mac = config->trustedmaclist; trust_mac != NULL; trust_mac = trust_mac->next) {
			count++;
		}

		// output the count of trusted macs and list them in json array format
		fprintf(fp, "  \"trusted_list_length\":\"%d\",\n", count);
		fprintf(fp, "  \"trusted\":[\n");

		for (trust_mac = config->trustedmaclist; trust_mac != NULL; trust_mac = trust_mac->next) {

			if (count > 1) {
				fprintf(fp, "    \"%s\",\n", trust_mac->mac);
				count--;
			} else {
				fprintf(fp, "    \"%s\"\n", trust_mac->mac);
			}
		}

		fprintf(fp, "  ]\n");
	}
	fprintf(fp, "}\n");
}

void
ndsctl_json(FILE *fp, const char *arg)
{
	char indent[5] = {0};
	//if (arg && strlen(arg)) {
	debug(LOG_DEBUG, "arg [%s %d]", arg, strlen(arg));
	if (strlen(arg) > 6) {
		//snprintf(indent, sizeof(indent), "%s", "");
		ndsctl_json_one(fp, arg, indent);
	} else {
		snprintf(indent, sizeof(indent), "%s", "    ");
		ndsctl_json_all(fp, indent);
	}
}

unsigned short
rand16(void)
{
	static int been_seeded = 0;

	if (!been_seeded) {
		unsigned int seed = 0;
		struct timeval now;

		// not a very good seed but what the heck, it needs to be quickly acquired
		gettimeofday(&now, NULL);
		seed = now.tv_sec ^ now.tv_usec ^ (getpid() << 16);

		srand(seed);
		been_seeded = 1;
	}

	/* Some rand() implementations have less randomness in low bits
	 than in high bits, so we only pay attention to the high ones.
	 But most implementations don't touch the high bit, so we
	 ignore that one.
	 */
	return( (unsigned short) (rand() >> 15) );
}
