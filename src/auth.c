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

/** @file auth.c
    @brief Authentication handling thread
    @author Copyright (C) 2004 Alexandre Carmel-Veilleux <acv@miniguru.ca>
*/

#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <string.h>
#include <stdarg.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <unistd.h>
#include <syslog.h>

#include "safe.h"
#include "conf.h"
#include "debug.h"
#include "auth.h"
#include "fw_iptables.h"
#include "client_list.h"
#include "util.h"
#include "http_microhttpd_utils.h"


extern pthread_mutex_t client_list_mutex;
extern pthread_mutex_t config_mutex;

// Count number of authentications
unsigned int authenticated_since_start = 0;


static void binauth_action(t_client *client, const char *reason, char *customdata)
{
	s_config *config = config_get_config();
	char lockfile[] = "/tmp/ndsctl.lock";
	FILE *fd;
	time_t now = time(NULL);
	int seconds = 60 * config->session_timeout;
	unsigned long int sessionstart;
	unsigned long int sessionend;
	char *deauth = "deauth";
	char *client_auth = "client_auth";
	char *ndsctl_auth = "ndsctl_auth";
	char customdata_enc[384] = {0};

	if (!customdata) {
		customdata="na";
	}

	if (config->binauth) {
		uh_urlencode(customdata_enc, sizeof(customdata_enc), customdata, strlen(customdata));
		debug(LOG_DEBUG, "binauth_action: customdata_enc [%s]", customdata_enc);
		// ndsctl will deadlock if run within the BinAuth script so we must lock it
		//Create lock
		fd = fopen(lockfile, "w");

		// get client's current session start and end
		sessionstart = client->session_start;
		sessionend = client->session_end;
		debug(LOG_DEBUG, "binauth_action client: seconds=%lu, sessionstart=%lu, sessionend=%lu", seconds, sessionstart, sessionend);

		// Check for a deauth reason
		if (strstr(reason, deauth) != NULL) {
			sessionend = now;
		}

		// Check for client_auth reason
		if (strstr(reason, client_auth) != NULL) {
			sessionstart = now;
		}

		// Check for ndsctl_auth reason
		if (strstr(reason, ndsctl_auth) != NULL) {
			sessionstart = now;
		}

		debug(LOG_NOTICE, "BinAuth %s - client session end time: [ %lu ]", reason, sessionend);

		execute("%s %s %s %llu %llu %lu %lu %s %s",
			config->binauth,
			reason ? reason : "unknown",
			client->mac,
			client->counters.incoming,
			client->counters.outgoing,
			sessionstart,
			sessionend,
			client->token,
			customdata_enc
		);

		// unlock ndsctl
		fclose(fd);
		remove(lockfile);
	}
}

static int auth_change_state(t_client *client, const unsigned int new_state, const char *reason, char *customdata)
{
	const unsigned int state = client->fw_connection_state;
	const time_t now = time(NULL);
	s_config *config = config_get_config();

	debug(LOG_DEBUG, "auth_change_state: customdata [%s]", customdata);

	if (state == new_state) {
		return -1;
	} else if (state == FW_MARK_PREAUTHENTICATED) {
		if (new_state == FW_MARK_AUTHENTICATED) {
			iptables_fw_authenticate(client);

			if (client->upload_rate == 0) {
				client->upload_rate = config->upload_rate;
			}

			if (client->download_rate == 0) {
				client->download_rate = config->download_rate;
			}

			if (client->upload_quota == 0) {
				client->upload_quota = config->upload_quota;
			}

			if (client->download_quota == 0) {
				client->download_quota = config->download_quota;
			}

			debug(LOG_INFO, "auth_change_state > authenticated - download_rate [%llu] upload_rate [%llu] ",
				client->download_rate,
				client->upload_rate
			);

			client->window_start = now;
			client->window_counter = config->rate_check_window;
			client->initial_loop = 1;
			client->counters.in_window_start = client->counters.incoming;
			client->counters.out_window_start = client->counters.outgoing;
			binauth_action(client, reason, customdata);
		} else if (new_state == FW_MARK_BLOCKED) {
			return -1;
		} else if (new_state == FW_MARK_TRUSTED) {
			return -1;
		} else {
			return -1;
		}
	} else if (state == FW_MARK_AUTHENTICATED) {
		if (new_state == FW_MARK_PREAUTHENTICATED) {
			iptables_fw_deauthenticate(client);
			binauth_action(client, reason, customdata);
			client_reset(client);
		} else if (new_state == FW_MARK_BLOCKED) {
			return -1;
		} else if (new_state == FW_MARK_TRUSTED) {
			return -1;
		} else {
			return -1;
		}
	} else if (state == FW_MARK_BLOCKED) {
		if (new_state == FW_MARK_PREAUTHENTICATED) {
			return -1;
		} else if (new_state == FW_MARK_AUTHENTICATED) {
			return -1;
		} else if (new_state == FW_MARK_TRUSTED) {
			return -1;
		} else {
			return -1;
		}
	} else if (state == FW_MARK_TRUSTED) {
		if (new_state == FW_MARK_PREAUTHENTICATED) {
			return -1;
		} else if (new_state == FW_MARK_AUTHENTICATED) {
			return -1;
		} else if (new_state == FW_MARK_BLOCKED) {
			return -1;
		} else {
			return -1;
		}
	} else {
		return -1;
	}

	client->fw_connection_state = new_state;

	return 0;
}

/** See if they are still active,
 *  refresh their traffic counters,
 *  remove and deny them if timed out
 */
static void
fw_refresh_client_list(void)
{
	t_client *cp1, *cp2;
	s_config *config = config_get_config();
	const int preauth_idle_timeout_secs = 60 * config->preauth_idle_timeout;
	const int auth_idle_timeout_secs = 60 * config->auth_idle_timeout;
	const time_t now = time(NULL);
	unsigned long long int durationsecs;
	unsigned long long int download_bytes, upload_bytes;
	unsigned long long int uprate;
	unsigned long long int downrate;

	debug(LOG_DEBUG, "Rate Check Window is set to %u period(s) of checkinterval", config->rate_check_window);

	// Update all the counters
	if (-1 == iptables_fw_counters_update()) {
		debug(LOG_ERR, "Could not get counters from firewall!");
		return;
	}

	LOCK_CLIENT_LIST();

	for (cp1 = cp2 = client_get_first_client(); NULL != cp1; cp1 = cp2) {
		cp2 = cp1->next;

		if (!(cp1 = client_list_find_by_id(cp1->id))) {
			debug(LOG_ERR, "Client was freed while being re-validated!");
			continue;
		}

		time_t last_updated = cp1->counters.last_updated;

		unsigned int conn_state = cp1->fw_connection_state;

		debug(LOG_DEBUG, "conn_state [%x]", conn_state);

		if (conn_state == FW_MARK_PREAUTHENTICATED) {

			// Preauthenticated client reached Idle Timeout witout authenticating so delete from the client list
			if (preauth_idle_timeout_secs > 0
				&& conn_state == FW_MARK_PREAUTHENTICATED
				&& (last_updated + preauth_idle_timeout_secs) <= now)
				{

				debug(LOG_NOTICE, "Timeout preauthenticated idle user: %s %s, inactive: %lus",
					cp1->ip,
					cp1->mac, now - last_updated
				);

				client_list_delete(cp1);
			}
			continue;
		}

		debug(LOG_INFO, "Client @ %s %s, quotas: ", cp1->ip, cp1->mac);

		debug(LOG_INFO, "	Download DATA quota (kBytes): %llu, used: %llu ", cp1->download_quota, cp1->counters.incoming / 1000);

		debug(LOG_INFO, "	Upload DATA quota (kBytes): %llu, used: %llu \n", cp1->upload_quota, cp1->counters.outgoing / 1000);

		if (cp1->session_end > 0 && cp1->session_end <= now) {
			// Session Timeout so deauthenticate the client

			debug(LOG_NOTICE, "Session end time reached, deauthenticating: %s %s, connected: %lu, in: %llukB, out: %llukB",
				cp1->ip, cp1->mac, now - cp1->session_end,
				cp1->counters.incoming / 1000,
				cp1->counters.outgoing / 1000
			);

			auth_change_state(cp1, FW_MARK_PREAUTHENTICATED, "timeout_deauth", NULL);


		} else if (cp1->download_quota > 0 && cp1->download_quota <= (cp1->counters.incoming / 1000)) {
			// Download quota reached so deauthenticate the client

			debug(LOG_NOTICE, "Download quota reached, deauthenticating: %s %s, connected: %lus, in: %llukB, out: %llukB",
				cp1->ip, cp1->mac,
				now - cp1->session_end,
				cp1->counters.incoming / 1000,
				cp1->counters.outgoing / 1000
			);

			auth_change_state(cp1, FW_MARK_PREAUTHENTICATED, "downquota_deauth", NULL);

		} else if (cp1->upload_quota > 0 && cp1->upload_quota <= (cp1->counters.outgoing / 1000)) {
			// Upload quota reached so deauthenticate the client

			debug(LOG_NOTICE, "Upload quota reached, deauthenticating: %s %s, connected: %lus, in: %llukB, out: %llukB",
				cp1->ip,
				cp1->mac,
				now - cp1->session_end,
				cp1->counters.incoming / 1000,
				cp1->counters.outgoing / 1000
			);

			auth_change_state(cp1, FW_MARK_PREAUTHENTICATED, "upquota_deauth", NULL);

		} else if (auth_idle_timeout_secs > 0
				&& conn_state == FW_MARK_AUTHENTICATED
				&& (last_updated + auth_idle_timeout_secs) <= now) {
			// Authenticated client reached Idle Timeout so deauthenticate the client

			debug(LOG_NOTICE, "Timeout authenticated idle user: %s %s, inactive: %ds, in: %llukB, out: %llukB",
				cp1->ip, cp1->mac, now - last_updated,
				cp1->counters.incoming / 1000,
				cp1->counters.outgoing / 1000
			);

			auth_change_state(cp1, FW_MARK_PREAUTHENTICATED, "idle_deauth", NULL);

		}

		// Now we need to process rate quotas, so first refresh the connection state in case it has changed
		conn_state = cp1->fw_connection_state;

		if (conn_state != FW_MARK_PREAUTHENTICATED) {

			debug(LOG_DEBUG, "Window start [%lu] - window counter [%u]",
				cp1->window_start,
				cp1->window_counter
			);

			debug(LOG_DEBUG, "in_window_start [%llu] - out_window_start [%llu]",
				cp1->counters.in_window_start,
				cp1->counters.out_window_start
			);

			durationsecs = (now - cp1->window_start);

			if (durationsecs <= (config->checkinterval * config->rate_check_window)) {
				--cp1->window_counter;
				continue;
			}

			if (cp1->initial_loop == 0) {
				download_bytes = (cp1->counters.incoming - cp1->counters.in_window_start);
				upload_bytes = (cp1->counters.outgoing - cp1->counters.out_window_start);
				downrate = (download_bytes / 125 / durationsecs); // kbits/sec
				uprate = (upload_bytes / 125 / durationsecs); // kbits/sec

				debug(LOG_DEBUG, "durationsecs [%llu] download_bytes [%llu] upload_bytes [%llu] ",
					durationsecs,
					download_bytes,
					upload_bytes
				);

				debug(LOG_INFO, "	Download RATE quota (kbits/s): %llu, Current average download rate (kbits/s): %llu",
					cp1->download_rate, downrate
				);

				debug(LOG_INFO, "	Upload RATE quota (kbits/s): %llu, Current average upload rate (kbits/s): %llu",
					cp1->upload_rate, uprate
				);

				if (cp1->download_rate > 0 && cp1->download_rate <= downrate && cp1->rate_exceeded == 0) {
					//download rate has exceeded quota so deauthenticate the client

					debug(LOG_NOTICE, "Download RATE quota reached for: %s %s, in: %llukbits/s, out: %llukbits/s",
						cp1->ip, cp1->mac,
						downrate,
						uprate
					);

					cp1->rate_exceeded = 1;
					iptables_do_command("-I FORWARD -s %s -j DROP", cp1->ip);
				} else if (cp1->upload_rate > 0 && cp1->upload_rate <= uprate && cp1->rate_exceeded == 0) {
					//upload rate has exceeded quota so deauthenticate the client

					debug(LOG_NOTICE, "Upload RATE quota reached for: %s %s, in: %llukbits/s, out: %llukbits/s",
						cp1->ip, cp1->mac,
						downrate,
						uprate
					);

					cp1->rate_exceeded = 1;
					iptables_do_command("-I FORWARD -s %s -j DROP", cp1->ip);
				}

				if (cp1->download_rate >= downrate && cp1->upload_rate >= uprate && cp1->rate_exceeded == 1) {
					cp1->rate_exceeded = 0;
					iptables_do_command("-D FORWARD -s %s -j DROP", cp1->ip);
				}

				if (cp1->window_counter == 0) { // Start new window
					cp1->window_start = now;
					cp1->window_counter = config->rate_check_window;
					cp1->counters.in_window_start = cp1->counters.incoming;
					cp1->counters.out_window_start = cp1->counters.outgoing;
				}
			} else {
				//reset initial loop and start new window
				cp1->initial_loop = 0;
				cp1->window_start = now;
				cp1->window_counter = config->rate_check_window;
				cp1->counters.in_window_start = cp1->counters.incoming;
				cp1->counters.out_window_start = cp1->counters.outgoing;
			}

		}
	}
	UNLOCK_CLIENT_LIST();
}

/** Launched in its own thread.
 *  This just wakes up every config.checkinterval seconds, and calls fw_refresh_client_list()
@todo This thread loops infinitely, need a watchdog to verify that it is still running?
*/
void *
thread_client_timeout_check(void *arg)
{
	pthread_cond_t cond = PTHREAD_COND_INITIALIZER;
	pthread_mutex_t cond_mutex = PTHREAD_MUTEX_INITIALIZER;
	struct timespec timeout;

	while (1) {
		debug(LOG_DEBUG, "Running fw_refresh_client_list()");

		fw_refresh_client_list();

		// Sleep for config.checkinterval seconds...
		timeout.tv_sec = time(NULL) + config_get_config()->checkinterval;
		timeout.tv_nsec = 0;

		// Mutex must be locked for pthread_cond_timedwait...
		pthread_mutex_lock(&cond_mutex);

		// Thread safe "sleep"
		pthread_cond_timedwait(&cond, &cond_mutex, &timeout);

		// No longer needs to be locked
		pthread_mutex_unlock(&cond_mutex);
	}

	return NULL;
}

/** Take action on a client.
 * Alter the firewall rules and client list accordingly.
*/
int
auth_client_deauth(const unsigned id, const char *reason)
{
	t_client *client;
	int rc = -1;

	LOCK_CLIENT_LIST();

	client = client_list_find_by_id(id);

	// Client should already have hit the server and be on the client list
	if (client == NULL) {
		debug(LOG_ERR, "Client %u to deauthenticate is not on client list", id);
		goto end;
	}

	rc = auth_change_state(client, FW_MARK_PREAUTHENTICATED, reason, NULL);

end:
	UNLOCK_CLIENT_LIST();
	return rc;
}


/**
 * @brief auth_client_auth_nolock authenticate a client without holding the CLIENT_LIST lock
 * @param id the client id
 * @param reason can be NULL
 * @return 0 on success
 */
int
auth_client_auth_nolock(const unsigned id, const char *reason, char *customdata)
{
	t_client *client;
	int rc;

	debug(LOG_DEBUG, "authorise client: custom data [%s] ", customdata);

	client = client_list_find_by_id(id);

	// Client should already have hit the server and be on the client list
	if (client == NULL) {
		debug(LOG_ERR, "Client %u to authenticate is not on client list", id);
		return -1;
	}

	rc = auth_change_state(client, FW_MARK_AUTHENTICATED, reason, customdata);
	if (rc == 0) {
		authenticated_since_start++;
	}

	return rc;
}

int
auth_client_auth(const unsigned id, const char *reason, char *customdata)
{
	int rc;

	LOCK_CLIENT_LIST();
	rc = auth_client_auth_nolock(id, reason, customdata);
	UNLOCK_CLIENT_LIST();

	return rc;
}

int
auth_client_trust(const char *mac)
{
	int rc = -1;

	LOCK_CONFIG();

	if (!add_to_trusted_mac_list(mac) && !iptables_trust_mac(mac)) {
		rc = 0;
	}

	UNLOCK_CONFIG();

	return rc;
}

int
auth_client_untrust(const char *mac)
{
	int rc = -1;

	LOCK_CONFIG();

	if (!remove_from_trusted_mac_list(mac) && !iptables_untrust_mac(mac)) {
		rc = 0;
	}

	UNLOCK_CONFIG();

/* 
	if (rc == 0) {
		LOCK_CLIENT_LIST();
		t_client * client = client_list_find_by_mac(mac);
		if (client) {
			rc = auth_change_state(client, FW_MARK_PREAUTHENTICATED, "manual_untrust", NULL);
			if (rc == 0) {
				client->session_start = 0;
				client->session_end = 0;
			}
		}
		UNLOCK_CLIENT_LIST();
	}
*/

	return rc;
}

int
auth_client_allow(const char *mac)
{
	int rc = -1;

	LOCK_CONFIG();

	if (!add_to_allowed_mac_list(mac) && !iptables_allow_mac(mac)) {
		rc = 0;
	}

	UNLOCK_CONFIG();

	return rc;
}

int
auth_client_unallow(const char *mac)
{
	int rc = -1;

	LOCK_CONFIG();

	if (!remove_from_allowed_mac_list(mac) && !iptables_unallow_mac(mac)) {
		rc = 0;
	}

	UNLOCK_CONFIG();

	return rc;
}

int
auth_client_block(const char *mac)
{
	int rc = -1;

	LOCK_CONFIG();

	if (!add_to_blocked_mac_list(mac) && !iptables_block_mac(mac)) {
		rc = 0;
	}

	UNLOCK_CONFIG();

	return rc;
}

int
auth_client_unblock(const char *mac)
{
	int rc = -1;

	LOCK_CONFIG();

	if (!remove_from_blocked_mac_list(mac) && !iptables_unblock_mac(mac)) {
		rc = 0;
	}

	UNLOCK_CONFIG();

	return rc;
}

void
auth_client_deauth_all()
{
	t_client *cp1, *cp2;

	LOCK_CLIENT_LIST();

	for (cp1 = cp2 = client_get_first_client(); NULL != cp1; cp1 = cp2) {
		cp2 = cp1->next;

		if (!(cp1 = client_list_find_by_id(cp1->id))) {
			debug(LOG_ERR, "Client was freed while being re-validated!");
			continue;
		}

		auth_change_state(cp1, FW_MARK_PREAUTHENTICATED, "shutdown_deauth", NULL);
	}

	UNLOCK_CLIENT_LIST();
}
