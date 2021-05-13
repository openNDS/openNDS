/********************************************************************\
 * This program is free software; you can redistribute it and/or    *
 * modify it under the terms of the GNU General Public License as   *
 * published by the Free:Software Foundation; either version 2 of   *
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

/** @internal
  @file main.c
  @brief Main loop
  @author Copyright (C) 2004 Philippe April <papril777@yahoo.com>
  @author Copyright (C) 2004 Alexandre Carmel-Veilleux <acv@miniguru.ca>
  @author Copyright (C) 2008 Paul Kube <nodogsplash@kokoro.ucsd.edu>
 */



#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <syslog.h>
#include <pthread.h>
#include <signal.h>
#include <errno.h>
#include <time.h>
#include <sys/stat.h>
#include <arpa/inet.h>

// for strerror()
#include <string.h>

// for wait()
#include <sys/wait.h>

// for unix socket communication
#include <sys/socket.h>
#include <sys/un.h>

#include "common.h"
#include "http_microhttpd.h"
#include "http_microhttpd_utils.h"
#include "safe.h"
#include "debug.h"
#include "conf.h"
#include "main.h"
#include "commandline.h"
#include "auth.h"
#include "client_list.h"
#include "ndsctl_thread.h"
#include "fw_iptables.h"
#include "util.h"

#include <microhttpd.h>

/* Check for libmicrohttp version in compiler
 *0.9.71 is the minimum version for NDS to work with the new API
 */
#if MHD_VERSION < 0x00095100
#error libmicrohttp version >= 0.9.71 required
#endif
/* Check for libmicrohttp version at runtime
 *0.9.69 is the minimum version to prevent loss of special characters in form data (BinAuth and PreAuth) 
 */
#define MIN_MHD_MAJOR 0
#define MIN_MHD_MINOR 9
#define MIN_MHD_PATCH 71

/** XXX Ugly hack
 * We need to remember the thread IDs of threads that simulate wait with pthread_cond_timedwait
 * so we can explicitly kill them in the termination handler
 */
static pthread_t tid_client_check = 0;

// Time when opennds started
time_t started_time = 0;

/**@internal
 * @brief Handles SIGCHLD signals to avoid zombie processes
 *
 * When a child process exits, it causes a SIGCHLD to be sent to the
 * parent process. This handler catches it and reaps the child process so it
 * can exit. Otherwise we'd get zombie processes.
 */
void
sigchld_handler(int s)
{
	int	status;
	pid_t rc;

	debug(LOG_DEBUG, "SIGCHLD handler: Trying to reap a child");

	rc = waitpid(-1, &status, WNOHANG | WUNTRACED);

	if (rc == -1) {
		if (errno == ECHILD) {
			debug(LOG_DEBUG, "SIGCHLD handler: waitpid(): No child exists now.");
		} else {
			debug(LOG_ERR, "SIGCHLD handler: Error reaping child (waitpid() returned -1): %s", strerror(errno));
		}
		return;
	}

	if (WIFEXITED(status)) {
		debug(LOG_DEBUG, "SIGCHLD handler: Process PID %d exited normally, status %d", (int)rc, WEXITSTATUS(status));
		return;
	}

	if (WIFSIGNALED(status)) {
		debug(LOG_DEBUG, "SIGCHLD handler: Process PID %d exited due to signal %d", (int)rc, WTERMSIG(status));
		return;
	}

	debug(LOG_DEBUG, "SIGCHLD handler: Process PID %d changed state, status %d not exited, ignoring", (int)rc, status);
	return;
}

/** Exits cleanly after cleaning up the firewall.
 *  Use this function anytime you need to exit after firewall initialization
 */
void
termination_handler(int s)
{
	static pthread_mutex_t sigterm_mutex = PTHREAD_MUTEX_INITIALIZER;
	char *fasssl = NULL;

	debug(LOG_INFO, "Handler for termination caught signal %d", s);

	// Makes sure we only call iptables_fw_destroy() once.
	if (pthread_mutex_trylock(&sigterm_mutex)) {
		debug(LOG_INFO, "Another thread already began global termination handler. I'm exiting");
		pthread_exit(NULL);
	} else {
		debug(LOG_INFO, "Cleaning up and exiting");
	}

	// Check if authmon is already running and if it is, kill it
	debug(LOG_INFO, "Explicitly killing the authmon daemon");
	safe_asprintf(&fasssl, "kill $(pgrep -f \"usr/lib/opennds/authmon.sh\") > /dev/null 2>&1");
	system(fasssl);
	free(fasssl);

	auth_client_deauth_all();

	debug(LOG_INFO, "Flushing firewall rules...");
	iptables_fw_destroy();

	/* XXX Hack
	 * Aparently pthread_cond_timedwait under openwrt prevents signals (and therefore
	 * termination handler) from happening so we need to explicitly kill the threads
	 * that use that
	 */

	if (tid_client_check) {
		debug(LOG_INFO, "Explicitly killing the fw_counter thread");
		pthread_kill(tid_client_check, SIGKILL);
	}

	debug(LOG_NOTICE, "Exiting...");
	exit(s == 0 ? 1 : 0);
}


/** @internal
 * Registers all the signal handlers
 */
static void
init_signals(void)
{
	struct sigaction sa;

	debug(LOG_DEBUG, "Setting SIGCHLD handler to sigchld_handler()");
	sa.sa_handler = sigchld_handler;
	sigemptyset(&sa.sa_mask);
	sa.sa_flags = SA_RESTART;
	if (sigaction(SIGCHLD, &sa, NULL) == -1) {
		debug(LOG_ERR, "sigaction(): %s", strerror(errno));
		exit(1);
	}

	// Trap SIGPIPE

	/* This is done so that when libhttpd does a socket operation on
	 * a disconnected socket (i.e.: Broken Pipes) we catch the signal
	 * and do nothing. The alternative is to exit. SIGPIPE are harmless
	 * if not desirable.
	 */

	debug(LOG_DEBUG, "Setting SIGPIPE  handler to SIG_IGN");
	sa.sa_handler = SIG_IGN;
	if (sigaction(SIGPIPE, &sa, NULL) == -1) {
		debug(LOG_ERR, "sigaction(): %s", strerror(errno));
		exit(1);
	}

	debug(LOG_DEBUG, "Setting SIGTERM, SIGQUIT, SIGINT  handlers to termination_handler()");
	sa.sa_handler = termination_handler;
	sigemptyset(&sa.sa_mask);
	sa.sa_flags = SA_RESTART;

	// Trap SIGTERM
	if (sigaction(SIGTERM, &sa, NULL) == -1) {
		debug(LOG_ERR, "sigaction(): %s", strerror(errno));
		exit(1);
	}

	// Trap SIGQUIT
	if (sigaction(SIGQUIT, &sa, NULL) == -1) {
		debug(LOG_ERR, "sigaction(): %s", strerror(errno));
		exit(1);
	}

	// Trap SIGINT
	if (sigaction(SIGINT, &sa, NULL) == -1) {
		debug(LOG_ERR, "sigaction(): %s", strerror(errno));
		exit(1);
	}
}

/**@internal
 * Setup from Configuration values
 */
static void
setup_from_config(void)
{
	char protocol[8] = {0};
	char port[8] = {0};
	char msg[255] = {0};
	char gwhash[255] = {0};
	char authmonpid[255] = {0};
	char *socket;
	char *fasurl = NULL;
	char *apiurl = NULL;
	char *authurl = NULL;
	char *fasssl = NULL;
	char *gatewayhash = NULL;
	char *fashid = NULL;
	char *phpcmd = NULL;
	char *preauth_dir = NULL;
	char loginscript[] = "/usr/lib/opennds/libopennds.sh";
	char gw_name_entityencoded[QUERYMAXLEN] = {0};
	char gw_name_urlencoded[QUERYMAXLEN] = {0};
	struct stat sb;
	time_t sysuptime;
	t_WGFQDN *allowed_wgfqdn;
	char wgfqdns[1024] = {0};
	char *dnscmd;

	s_config *config;

	config = config_get_config();

	debug(LOG_INFO, "tmpfs mountpoint is [%s]", config->tmpfsmountpoint);
	// Before we do anything else, reset the firewall (cleans it, in case we are restarting after opennds crash)
	iptables_fw_destroy();

	// Check for libmicrohttp version at runtime, ie actual installed version
	int major = 0;
	int minor = 0;
	int patch = 0;
	int outdated = 0;
	const char *version = MHD_get_version();

	debug(LOG_INFO, "MHD version is %s", version);

	if (sscanf(version, "%d.%d.%d", &major, &minor, &patch) == 3) {

		if (major < MIN_MHD_MAJOR) {
			outdated = 1;

		} else if (minor < MIN_MHD_MINOR) {
			outdated = 1;

		} else if (patch < MIN_MHD_PATCH) {
			outdated = 1;
		}

		if (outdated == 1) {
			debug(LOG_ERR, "libmicrohttpd is out of date, please upgrade to version %d.%d.%d or higher",
				MIN_MHD_MAJOR, MIN_MHD_MINOR, MIN_MHD_PATCH);

			if (config->use_outdated_mhd == 0) {
				debug(LOG_ERR, "exiting...");
				exit(1);
			} else {
				debug(LOG_ERR, "Attempting use of outdated MHD - Data may be corrupted or openNDS may fail...");
			}
		}
	}

	// If we don't have the Gateway IP address, get it. Exit on failure.
	if (!config->gw_ip) {
		debug(LOG_DEBUG, "Finding IP address of %s", config->gw_interface);
		config->gw_ip = get_iface_ip(config->gw_interface, config->ip6);
		if (is_addr(config->gw_ip) != 1) {
			debug(LOG_ERR, "Could not get IP address information of %s, exiting...", config->gw_interface);
			exit(1);
		} else {
			debug(LOG_NOTICE, "Interface %s is up", config->gw_interface);
		}
	}

	// format gw_address accordingly depending on if gw_ip is v4 or v6
	const char *ipfmt = config->ip6 ? "[%s]:%d" : "%s:%d";
	safe_asprintf(&config->gw_address, ipfmt, config->gw_ip, config->gw_port);

	config->gw_mac = get_iface_mac(config->gw_interface);

	if (config->gw_mac == NULL) {
		debug(LOG_ERR, "Could not get MAC address information of %s, exiting...", config->gw_interface);
		exit(1);
	}

	debug(LOG_NOTICE, "Interface %s is at %s (%s)", config->gw_interface, config->gw_ip, config->gw_mac);

	// Make sure fas_remoteip is set. Note: This does not enable FAS.
	if (!config->fas_remoteip) {
		config->fas_remoteip = safe_strdup(config->gw_ip);
	}

	// Setup custom FAS parameters if configured
	char fasparam[MAX_BUF] = {0};
	t_FASPARAM *fas_fasparam;
	if (config->fas_custom_parameters_list) {
		for (fas_fasparam = config->fas_custom_parameters_list; fas_fasparam != NULL; fas_fasparam = fas_fasparam->next) {

			// Make sure we don't have a buffer overflow
			if ((sizeof(fasparam) - strlen(fasparam)) > (strlen(fas_fasparam->fasparam) + 4)) {
				strcat(fasparam, fas_fasparam->fasparam);
				strcat(fasparam, QUERYSEPARATOR);
			} else {
				break;
			}
		}
		config->custom_params = safe_strdup(fasparam);
		debug(LOG_DEBUG, "Custom FAS parameter string [%s]", config->custom_params);
	}

	// Setup custom FAS variables if configured
	char fasvar[MAX_BUF] = {0};
	t_FASVAR *fas_fasvar;
	if (config->fas_custom_parameters_list) {
		for (fas_fasvar = config->fas_custom_variables_list; fas_fasvar != NULL; fas_fasvar = fas_fasvar->next) {

			// Make sure we don't have a buffer overflow
			if ((sizeof(fasvar) - strlen(fasvar)) > (strlen(fas_fasvar->fasvar) + 4)) {
				strcat(fasvar, fas_fasvar->fasvar);
				strcat(fasvar, QUERYSEPARATOR);
			} else {
				break;
			}
		}
		config->custom_vars = safe_strdup(fasvar);
		debug(LOG_DEBUG, "Custom FAS variables string [%s]", config->custom_vars);
	}

	// Setup custom FAS images if configured
	char fasimage[MAX_BUF] = {0};
	t_FASIMG *fas_fasimage;
	if (config->fas_custom_images_list) {
		for (fas_fasimage = config->fas_custom_images_list; fas_fasimage != NULL; fas_fasimage = fas_fasimage->next) {

			// Make sure we don't have a buffer overflow
			if ((sizeof(fasimage) - strlen(fasimage)) > (strlen(fas_fasimage->fasimg) + 4)) {
				strcat(fasimage, fas_fasimage->fasimg);
				strcat(fasimage, QUERYSEPARATOR);
			} else {
				break;
			}
		}
		config->custom_images = safe_strdup(fasimage);
		debug(LOG_DEBUG, "Custom FAS images string [%s]", config->custom_images);
	}

	// Setup custom FAS images if configured
	char fasfile[MAX_BUF] = {0};
	t_FASFILE *fas_fasfile;
	if (config->fas_custom_files_list) {
		for (fas_fasfile = config->fas_custom_files_list; fas_fasfile != NULL; fas_fasfile = fas_fasfile->next) {

			// Make sure we don't have a buffer overflow
			if ((sizeof(fasfile) - strlen(fasfile)) > (strlen(fas_fasfile->fasfile) + 4)) {
				strcat(fasfile, fas_fasfile->fasfile);
				strcat(fasfile, QUERYSEPARATOR);
			} else {
				break;
			}
		}
		config->custom_files = safe_strdup(fasfile);
		debug(LOG_DEBUG, "Custom FAS files string [%s]", config->custom_files);
	}

	if (strcmp(config->gw_fqdn, "disable") == 0) {
		config->gw_fqdn = NULL;
	}

	if (config->gw_fqdn || config->walledgarden_fqdn_list) {
		// For Client status Page - configure the hosts file
		if (config->gw_fqdn) {
			safe_asprintf(&dnscmd, "/usr/lib/opennds/dnsconfig.sh \"hostconf\" \"%s\" \"%s\"",
				config->gw_ip,
				config->gw_fqdn
			);

			if (execute_ret_url_encoded(msg, sizeof(msg) - 1, dnscmd) == 0) {
				debug(LOG_INFO, "Dnsmasq configured for Walled Garden");
			} else {
				debug(LOG_ERR, "Client Status Page: Hosts setup script failed to execute");
			}
			free(dnscmd);
		}

		// For Walled Garden - Check we have ipset support and if we do, set it up
		if (config->walledgarden_fqdn_list) {
			// Check ipset command is available
			if (execute_ret_url_encoded(msg, sizeof(msg) - 1, "ipset -v") == 0) {
				debug(LOG_NOTICE, "ipset support is available");
			} else {
				debug(LOG_ERR, "ipset support not available - please install package to provide it");
				debug(LOG_ERR, "Exiting...");
				exit(1);
			}

			// Check we have dnsmasq ipset compile option
			if (execute_ret_url_encoded(msg, sizeof(msg) - 1, "dnsmasq --version | grep ' ipset '") == 0) {
				debug(LOG_NOTICE, "dnsmasq ipset support is available");
			} else {
				debug(LOG_ERR, "Please install dnsmasq full version with ipset compile option");
				debug(LOG_ERR, "Exiting...");
				exit(1);
			}

			// If Walled Garden ipset exists, destroy it.
			execute_ret_url_encoded(msg, sizeof(msg) - 1, "ipset destroy walledgarden");

			// Set up the Walled Garden
			if (execute_ret_url_encoded(msg, sizeof(msg) - 1, "ipset create walledgarden hash:ip") == 0) {
				debug(LOG_INFO, "Walled Garden ipset created");
			} else {
				debug(LOG_ERR, "Failed to create Walled Garden");
				debug(LOG_ERR, "Exiting...");
				exit(1);
			}

			// Configure dnsmasq
			for (allowed_wgfqdn = config->walledgarden_fqdn_list; allowed_wgfqdn != NULL; allowed_wgfqdn = allowed_wgfqdn->next) {

				// Make sure we don't have a buffer overflow
				if ((sizeof(wgfqdns) - strlen(wgfqdns)) > (strlen(allowed_wgfqdn->wgfqdn) + 15)) {
					strcat(wgfqdns, "/");
					strcat(wgfqdns, allowed_wgfqdn->wgfqdn);
				} else {
					break;
				}
			}

			strcat(wgfqdns, "/walledgarden");
			debug(LOG_DEBUG, "Dnsmasq Walled Garden config [%s]", wgfqdns);
			safe_asprintf(&dnscmd, "/usr/lib/opennds/dnsconfig.sh \"ipsetconf\" \"%s\"", wgfqdns);
			if (execute_ret_url_encoded(msg, sizeof(msg) - 1, dnscmd) == 0) {
				debug(LOG_INFO, "Dnsmasq configured for Walled Garden");
			} else {
				debug(LOG_ERR, "Walled Garden Dnsmasq setup script failed to execute");
			}
			free(dnscmd);
		}

		safe_asprintf(&dnscmd, "/usr/lib/opennds/dnsconfig.sh \"restart_only\" &");
		debug(LOG_DEBUG, "restart command [ %s ]", dnscmd);
		system(dnscmd);
		debug(LOG_INFO, "Dnsmasq restarted");
		free(dnscmd);
	}

	// Encode gatewayname
	htmlentityencode(gw_name_entityencoded, sizeof(gw_name_entityencoded), config->gw_name, strlen(config->gw_name));
	config->http_encoded_gw_name = safe_strdup(gw_name_entityencoded);

	uh_urlencode(gw_name_urlencoded, sizeof(gw_name_urlencoded), config->gw_name, strlen(config->gw_name));
	config->url_encoded_gw_name = safe_strdup(gw_name_urlencoded);

	// Set the time when opennds started
	sysuptime = get_system_uptime ();
	debug(LOG_INFO, "main: System Uptime is %li seconds", sysuptime);

	if (!started_time) {
		debug(LOG_INFO, "Setting started_time");
		started_time = time(NULL);
	} else if (started_time < (time(NULL) - sysuptime)) {
		debug(LOG_WARNING, "Detected possible clock skew - re-setting started_time");
		started_time = time(NULL);
	}

	// Initialize the web server
	start_mhd();
	debug(LOG_NOTICE, "Created web server on %s", config->gw_address);

	// Get the ndsctl socket path/filename
	if (strcmp(config->ndsctl_sock, DEFAULT_NDSCTL_SOCK) == 0) {
		safe_asprintf(&socket, "%s/%s", config->tmpfsmountpoint, DEFAULT_NDSCTL_SOCK);
		config->ndsctl_sock = safe_strdup(socket);
		free(socket);
	}

	debug(LOG_NOTICE, "Socket access at %s", config->ndsctl_sock);

	// Check if login script or custom preauth script is enabled
	if (config->login_option_enabled >= 1) {
		debug(LOG_NOTICE, "Login option is Enabled using mode %d.\n", config->login_option_enabled);
		config->preauth = safe_strdup(loginscript);
	} else if (config->login_option_enabled == 0 && config->fas_port == 0 && config->preauth == NULL) {
		debug(LOG_NOTICE, "Click to Continue option is Enabled.\n");
		config->preauth = safe_strdup(loginscript);
	} else if (config->login_option_enabled == 0 && config->fas_port == 0 && config->preauth != NULL) {
		debug(LOG_NOTICE, "Custom PreAuth Script Enabled.\n");
	} else if (config->login_option_enabled == 0 && config->fas_port >= 1 ) {
		debug(LOG_NOTICE, "FAS Enabled.\n");
		config->preauth = NULL;
	}


	// If PreAuth is enabled, override any FAS configuration and check script exists
	if (config->preauth) {
		debug(LOG_NOTICE, "Preauth is Enabled - Overiding FAS configuration.\n");
		debug(LOG_INFO, "Preauth Script is %s\n", config->preauth);


		if (!((stat(config->preauth, &sb) == 0) && S_ISREG(sb.st_mode) && (sb.st_mode & S_IXUSR))) {
			debug(LOG_ERR, "Login script does not exist or is not executable: %s", config->preauth);
			debug(LOG_ERR, "Exiting...");
			exit(1);
		}

		//override all other FAS settings
		config->fas_remoteip = safe_strdup(config->gw_ip);
		config->fas_remotefqdn = NULL;
		config->fas_port = config->gw_port;
		safe_asprintf(&preauth_dir, "/%s/", config->preauthdir);
		config->fas_path = safe_strdup(preauth_dir);
		config->fas_secure_enabled = 1;
		free(preauth_dir);
	}

	// If FAS is enabled then set it up
	if (config->fas_port) {
		debug(LOG_INFO, "fas_secure_enabled is set to level %d", config->fas_secure_enabled);

		// Check the FAS remote IP address
		if (config->fas_remoteip) {
			if (is_addr(config->fas_remoteip) == 1) {
				debug(LOG_INFO, "fasremoteip - %s - is a valid IPv4 address...", config->fas_remoteip);
			} else {
				debug(LOG_ERR, "fasremoteip - %s - is NOT a valid IPv4 address format...", config->fas_remoteip);
				debug(LOG_ERR, "Exiting...");
				exit(1);
			}
		}

		// Block fas port 80 if local FAS
		snprintf(port, sizeof(port), "%u", config->fas_port);

		if((strcmp(config->gw_ip, config->fas_remoteip) == 0) && (strcmp(port, "80") == 0)) {
			debug(LOG_ERR, "Invalid fasport - port 80 is reserved and cannot be used for local FAS...");
			debug(LOG_ERR, "Exiting...");
			exit(1);
		}

		// If FAS key is set, then check the prerequisites

		// FAS secure Level >=1
		if (config->fas_key && config->fas_secure_enabled >= 1) {
			// Check sha256sum command is available
			if (execute_ret_url_encoded(msg, sizeof(msg) - 1, "printf 'test' | sha256sum") == 0) {
				safe_asprintf(&fashid, "sha256sum");
				debug(LOG_NOTICE, "sha256sum provider is available");
			} else {
				debug(LOG_ERR, "sha256sum provider not available - please install package to provide it");
				debug(LOG_ERR, "Exiting...");
				exit(1);
			}
			config->fas_hid = safe_strdup(fashid);
			free(fashid);
		}

		// FAS secure Level 2 and 3
		if (config->fas_key && config->fas_secure_enabled >= 2) {
			// PHP cli command can be php or php-cli depending on Linux version.
			if (execute_ret(msg, sizeof(msg) - 1, "php -v") == 0) {
				safe_asprintf(&fasssl, "php");
				debug(LOG_NOTICE, "SSL Provider is active");
				debug(LOG_DEBUG, "SSL Provider: %s FAS key is: %s\n", &msg, config->fas_key);

			} else if (execute_ret(msg, sizeof(msg) - 1, "php-cli -v") == 0) {
				safe_asprintf(&fasssl, "php-cli");
				debug(LOG_NOTICE, "SSL Provider is active");
				debug(LOG_DEBUG, "SSL Provider: %s FAS key is: %s\n", &msg, config->fas_key);
			} else {
				debug(LOG_ERR, "PHP packages PHP CLI and PHP OpenSSL are required");
				debug(LOG_ERR, "Exiting...");
				exit(1);
			}
			config->fas_ssl = safe_strdup(fasssl);
			free(fasssl);
			safe_asprintf(&phpcmd,
				"echo '<?php "
				"if (!extension_loaded (\"openssl\")) {exit(1);}"
				" ?>' | %s", config->fas_ssl
			);

			if (execute_ret(msg, sizeof(msg) - 1, phpcmd) == 0) {
				debug(LOG_INFO, "OpenSSL module is loaded\n");
			} else {
				debug(LOG_ERR, "OpenSSL PHP module is not loaded");
				debug(LOG_ERR, "Exiting...");
				exit(1);
			}
			free(phpcmd);
		}

		// set the protocol used, enforcing https for Level 3
		if (config->fas_secure_enabled == 3) {
			snprintf(protocol, sizeof(protocol), "https");
		} else {
			snprintf(protocol, sizeof(protocol), "http");
		}

		// Setup the FAS URL
		if (config->fas_remotefqdn) {
			safe_asprintf(&fasurl, "%s://%s:%u%s",
				protocol, config->fas_remotefqdn, config->fas_port, config->fas_path);
			config->fas_url = safe_strdup(fasurl);
		} else {
			safe_asprintf(&fasurl, "%s://%s:%u%s",
				protocol, config->fas_remoteip, config->fas_port, config->fas_path);
			config->fas_url = safe_strdup(fasurl);
		}
		debug(LOG_NOTICE, "FAS URL is %s\n", config->fas_url);
		free(fasurl);

		// Setup the API URL | ensure that the api option has been configured
		if (config->api_remotefqdn) {
			safe_asprintf(&apiurl, "%s://%s:%u%s",
				protocol, config->api_remotefqdn, config->api_port,config->api_path);
			config->api_url = safe_strdup(apiurl);		 
			free(apiurl);
		} else if(config->api_remoteip) {
			safe_asprintf(&apiurl, "%s://%s:%u%s",
				protocol, config->api_remoteip, config->api_port,config->api_path);
			config->api_url = safe_strdup(apiurl);			
			free(apiurl);
		}
		
		debug(LOG_NOTICE, "API URL is %s\n", config->api_url);
		// Setup the Auth URL
		if(config->api_url){
			safe_asprintf(&authurl, "%s",config->api_url);
			config->auth_url = safe_strdup(authurl);
		}else{
			safe_asprintf(&authurl, "%s",config->fas_url);
			config->auth_url = safe_strdup(authurl);
		}

		debug(LOG_NOTICE, "Auth URL is %s\n", config->auth_url);
		free(auth_url);

		// Check if authmon is running and if it is, kill it
		safe_asprintf(&fasssl, "kill $(pgrep -f \"usr/lib/opennds/authmon.sh\") > /dev/null 2>&1");
		system(fasssl);
		free(fasssl);

		// Start the authmon daemon if configured for Level 3
		if (config->fas_key && config->fas_secure_enabled == 3) {

			// Get the sha256 digest of gatewayname
			safe_asprintf(&fasssl,
				"echo \"<?php echo openssl_digest('%s', 'sha256'); ?>\" | %s",
				config->url_encoded_gw_name,
				config->fas_ssl
			);

			if (execute_ret_url_encoded(gwhash, sizeof(gwhash) - 1, fasssl) == 0) {
				safe_asprintf(&gatewayhash, "%s", gwhash);
				debug(LOG_DEBUG, "gatewayname digest is: %s\n", gwhash);
			} else {
				debug(LOG_ERR, "Error hashing gatewayname");
				debug(LOG_ERR, "Exiting...");
				exit(1);
			}
			free(fasssl);

			// Start authmon in the background
			safe_asprintf(&fasssl,
				"/usr/lib/opennds/authmon.sh \"%s\" \"%s\" \"%s\" &",
				config->auth_url,//config->fas_url,
				gatewayhash,
				config->fas_ssl
			);

			debug(LOG_DEBUG, "authmon startup command is: %s\n", fasssl);

			system(fasssl);

			// Check authmon is running
			safe_asprintf(&fasssl,
				"pgrep -f \"usr/lib/opennds/authmon.sh\""
			);

			if (execute_ret_url_encoded(authmonpid, sizeof(authmonpid) - 1, fasssl) == 0) {
				debug(LOG_INFO, "authmon pid is: %s\n", authmonpid);
			} else {
				debug(LOG_ERR, "Error starting authmon daemon");
				debug(LOG_ERR, "Exiting...");
				exit(1);
			}

			free(fasssl);
			free(gatewayhash);
		}

		// Report the FAS FQDN
		if (config->fas_remotefqdn) {
			debug(LOG_INFO, "FAS FQDN is: %s\n", config->fas_remotefqdn);
		}

		// Report security warning
		if (config->fas_secure_enabled == 0) {
			debug(LOG_WARNING, "Warning - Forwarding Authentication - Security is DISABLED.\n");
		}

		// Report the Pre-Shared key is not available
		if (config->fas_secure_enabled >= 2 && config->fas_key == NULL) {
			debug(LOG_ERR, "Error - faskey is not set - exiting...\n");
			exit(1);
		}

		debug(LOG_NOTICE, "Forwarding Authentication is Enabled.\n");
	}

	// Report if BinAuth is enabled
	if (config->binauth) {
		debug(LOG_NOTICE, "Binauth is Enabled.\n");
		debug(LOG_INFO, "Binauth Script is %s\n", config->binauth);
	}

	// Now initialize the firewall
	if (iptables_fw_init() != 0) {
		debug(LOG_ERR, "Error initializing firewall rules! Cleaning up");
		iptables_fw_destroy();
		debug(LOG_ERR, "Exiting because of error initializing firewall rules");
		exit(1);
	}

	debug(LOG_NOTICE, "openNDS is now running.\n");
}

/**@internal
 * Main execution loop
 */
static void
main_loop(void)
{
	int result = 0;
	pthread_t tid;
	s_config *config;

	config = config_get_config();

	// Set up everything we need based on the configuration
	setup_from_config();

	// Start client statistics and timeout clean-up thread
	result = pthread_create(&tid_client_check, NULL, thread_client_timeout_check, NULL);
	if (result != 0) {
		debug(LOG_ERR, "FATAL: Failed to create thread_client_timeout_check - exiting");
		termination_handler(0);
	}
	pthread_detach(tid_client_check);

	// Start control thread
	result = pthread_create(&tid, NULL, thread_ndsctl, (void *)(config->ndsctl_sock));
	if (result != 0) {
		debug(LOG_ERR, "FATAL: Failed to create thread_ndsctl - exiting");
		termination_handler(1);
	}

	result = pthread_join(tid, NULL);
	if (result) {
		debug(LOG_INFO, "Failed to wait for opennds thread.");
	}
	//MHD_stop_daemon(webserver);
	stop_mhd();

	termination_handler(result);
}

/** Main entry point for opennds.
 * Reads the configuration file and then starts the main loop.
 */
int main(int argc, char **argv)
{
	s_config *config = config_get_config();
	config_init();

	parse_commandline(argc, argv);

	// Initialize the config
	debug(LOG_NOTICE, "openNDS Version %s is in startup\n", VERSION);
	debug(LOG_INFO, "Reading and validating configuration file %s", config->configfile);
	config_read(config->configfile);
	config_validate();

	// Initializes the linked list of connected clients
	client_list_init();

	// Init the signals to catch chld/quit/etc
	debug(LOG_INFO, "Initializing signal handlers");
	init_signals();

	if (config->daemon) {

		debug(LOG_NOTICE, "Starting as daemon, forking to background");

		switch(safe_fork()) {
		case 0: // child
			setsid();
			main_loop();
			break;

		default: // parent
			exit(0);
			break;
		}
	} else {
		main_loop();
	}

	return 0; // never reached
}
