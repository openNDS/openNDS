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

/** @file fw_iptables.h
    @brief Firewall iptables functions
    @author Copyright (C) 2004 Philippe April <papril777@yahoo.com>
    @author Copyright (C) 2007 Paul Kube <nodogsplash@kokoro.ucsd.edu>
*/

#ifndef _FW_H_
#define _FW_H_

#include "auth.h"
#include "client_list.h"

/** Used to mark packets, and characterize client state.  Unmarked packets are considered 'preauthenticated' */
extern unsigned int  FW_MARK_PREAUTHENTICATED; /**< @brief 0: Actually not used as a packet mark */
extern unsigned int  FW_MARK_AUTHENTICATED;    /**< @brief The client is authenticated */
extern unsigned int  FW_MARK_BLOCKED;          /**< @brief The client is blocked */
extern unsigned int  FW_MARK_TRUSTED;          /**< @brief The client is trusted */
extern unsigned int  FW_MARK_MASK;             /**< @brief Iptables mask: bitwise or of the others */


/** @brief Initialize the firewall */
int fw_init(void);

/** @brief Destroy the firewall */
int fw_destroy(void);

/** @brief Helper function for fw_destroy */
int fw_destroy_mention( const char table[], const char chain[], const char mention[]);

/** @brief Define the access of a specific client */
int fw_authenticate(t_client *client);
int fw_deauthenticate(t_client *client);

/** @brief Enable/Disable Upload Rate Limiting of a specific client */
int fw_upload_ratelimit_enable(t_client *client, int enable);

/** @brief Enable/Disable Download Rate Limiting of a specific client */
int fw_download_ratelimit_enable(t_client *client, int enable);

/** @brief Return the total download usage in bytes */
unsigned long long int fw_total_download();

/** @brief Return the total upload usage in bytes */
unsigned long long int fw_total_upload();

/** @brief All counters in the client list */
int fw_counters_update(void);

/** @brief Return a string representing a connection state */
const char *fw_connection_state_as_string(int mark);

/** @brief Fork an iptables command */

int fw_block_mac(const char mac[]);
int fw_unblock_mac(const char mac[]);

int fw_allow_mac(const char mac[]);
int fw_unallow_mac(const char mac[]);

int fw_trust_mac(const char mac[]);
int fw_untrust_mac(const char mac[]);

#endif /* _IPTABLES_H_ */
