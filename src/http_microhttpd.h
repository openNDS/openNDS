/* SPDX-License-Identifier: GPL-2.0-or-later */
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

/** @internal
 * @file http_microhttpd.c
 * @brief a httpd implementation using libmicrohttpd
 * @author Copyright (C) 2015 Alexander Couzens <lynxis@fe80.eu>
 * @author Copyright (C) 2015-2023 The openNDS contributors <opennds@blue-wave.net>
 * @author Copyright (C) 2015-2026 Modifications and additions by BlueWave Projects and Services <opennds@blue-wave.net>
 */

#ifndef HTTP_MICROHTTPD_H
#define HTTP_MICROHTTPD_H

#include <stddef.h>
#include <stdio.h>
#include <string.h>

struct MHD_Connection;

/** @brief Get an IP's MAC address from the ARP cache.*/
int arp_get(char mac_addr[18], const char req_ip[]);

void start_mhd(void);
void stop_mhd(void);

enum MHD_Result libmicrohttpd_cb (void *cls,
					struct MHD_Connection *connection,
					const char *url,
					const char *method,
					const char *version,
					const char *upload_data, size_t *upload_data_size, void **ptr);

#endif // HTTP_MICROHTTPD_H
