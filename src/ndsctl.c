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

/** @file ndsctl.c
    @brief Monitoring and control of opennds, client part
    @author Copyright (C) 2004 Alexandre Carmel-Veilleux <acv@acv.ca>
    trivially modified for opennds
*/

#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <syslog.h>
#include <errno.h>

#include "ndsctl.h"


struct argument {
	const char *cmd;
	const char *ifyes;
	const char *ifno;
};

/** @internal
 * @brief Print usage
 *
 * Prints usage, called when ndsctl is run with -h or with an unknown option
 */
static void
usage(void)
{
	printf(
		"Usage: ndsctl [options] command [arguments]\n"
		"\n"
		"options:\n"
		"  -s <path>           Path to the socket\n"
		"  -h                  Print usage\n"
		"\n"
		"commands:\n"
		"  status\n"
		"	View the status of opennds\n\n"
		"  clients\n"
		"	Display machine-readable client list\n\n"
		"  json	mac|ip|token(optional)\n"
		"	Display client list in json format\n"
		"	mac|ip|token is optional, if not specified, all clients are listed\n\n"
		"  stop\n"
		"	Stop the running opennds\n\n"
		"  auth mac|ip|token sessiontimeout(minutes) uploadrate(kb/s) downloadrate(kb/s) uploadquota(kB) downloadquota(kB) customstring\n"
		"	Authenticate client with specified mac, ip or token\n"
		"\n"
		"	sessiontimeout sets the session duration. Unlimited if 0, defaults to global setting if null (double quotes).\n"
		"	The client will be deauthenticated once the sessiontimout period has passed.\n"
		"\n"
		"	uploadrate and downloadrate are the maximum allowed data rates. Unlimited if 0, global setting if null (\"\").\n"
		"\n"
		"	uploadquota and downloadquota are the maximum volumes of data allowed. Unlimited if 0, global setting if null (\"\").\n"
		"\n"
		"	customstring is a custom string that will be passed to BinAuth.\n"
		"\n"
		"	Example: ndsctl auth 1400 300 1500 500000 1000000 \"This is a Custom String\"\n"
		"\n"
		"  deauth mac|ip|token\n"
		"	Deauthenticate user with specified mac, ip or token\n\n"
		"  block mac\n"
		"	Block the given MAC address\n\n"
		"  unblock mac\n"
		"	Unblock the given MAC address\n\n"
		"  allow mac\n"
		"	Allow the given MAC address\n\n"
		"  unallow mac\n"
		"	Unallow the given MAC address\n\n"
		"  trust mac\n"
		"	Trust the given MAC address\n\n"
		"  untrust mac\n"
		"	Untrust the given MAC address\n\n"
		"  debuglevel n\n"
		"	Set debug level to n (0=silent, 1=Normal, 2=Info, 3=debug)\n"
		"\n"
	);
}

static struct argument arguments[] = {
	{"clients", NULL, NULL},
	{"json", NULL, NULL},
	{"status", NULL, NULL},
	{"stop", NULL, NULL},
	{"debuglevel", "Debug level set to %s.\n", "Failed to set debug level to %s.\n"},
	{"deauth", "Client %s deauthenticated.\n", "Client %s not found.\n"},
	{"auth", "Client %s authenticated.\n", "Failed to authenticate client %s.\n"},
	{"block", "MAC %s blocked.\n", "Failed to block MAC %s.\n"},
	{"unblock", "MAC %s unblocked.\n", "Failed to unblock MAC %s.\n"},
	{"allow", "MAC %s allowed.\n", "Failed to allow MAC %s.\n"},
	{"unallow", "MAC %s unallowed.\n", "Failed to unallow MAC %s.\n"},
	{"trust", "MAC %s trusted.\n", "Failed to trust MAC %s.\n"},
	{"untrust", "MAC %s untrusted.\n", "Failed to untrust MAC %s.\n"},
	{NULL, NULL, NULL}
};

static const struct argument*
find_argument(const char *cmd) {
	int i;

	for (i = 0; arguments[i].cmd; i++) {
		if (strcmp(arguments[i].cmd, cmd) == 0) {
			return &arguments[i];
		}
	}

	return NULL;
}

static int
connect_to_server(const char sock_name[])
{
	int sock;
	char lockfile[] = "/tmp/ndsctl.lock";
	struct sockaddr_un sa_un;

	// Connect to socket
	sock = socket(AF_UNIX, SOCK_STREAM, 0);
	memset(&sa_un, 0, sizeof(sa_un));
	sa_un.sun_family = AF_UNIX;
	strncpy(sa_un.sun_path, sock_name, (sizeof(sa_un.sun_path) - 1));

	if (connect(sock, (struct sockaddr *)&sa_un, strlen(sa_un.sun_path) + sizeof(sa_un.sun_family))) {
		fprintf(stderr, "ndsctl: opennds probably not started (Error: %s)\n", strerror(errno));
		remove(lockfile);
		return -1;
	}

	return sock;
}

static int
send_request(int sock, const char request[])
{
	ssize_t len, written;

	len = 0;
	while (len != strlen(request)) {
		written = write(sock, (request + len), strlen(request) - len);
		if (written == -1) {
			fprintf(stderr, "Write to opennds failed: %s\n", strerror(errno));
			exit(1);
		}
		len += written;
	}

	return((int)len);
}

/* Perform a ndsctl action, with server response Yes or No.
 * Action given by cmd, followed by config.param.
 * Responses printed to stdout, as formatted by ifyes or ifno.
 * config.param interpolated in format with %s directive if desired.
 */
static int
ndsctl_do(const char *socket, const struct argument *arg, const char *param)
{
	int sock;
	char buffer[4096];
	char request[128];
	int len, rlen;
	int ret;

	setlogmask(LOG_UPTO (LOG_NOTICE));
	sock = connect_to_server(socket);

	if (sock < 0) {
		return 3;
	}

	if (param) {
		snprintf(request, sizeof(request), "%s %s\r\n\r\n", arg->cmd, param);
	} else {
		snprintf(request, sizeof(request), "%s\r\n\r\n", arg->cmd);
	}

	len = send_request(sock, request);

	if (arg->ifyes && arg->ifno) {
		len = 0;
		memset(buffer, 0, sizeof(buffer));
		while ((len < sizeof(buffer)) && ((rlen = read(sock, (buffer + len),
			(sizeof(buffer) - len))) > 0)) {
			len += rlen;
		}

		if (rlen < 0) {
			fprintf(stderr, "ndsctl: Error reading socket: %s\n", strerror(errno));
			ret = 3;
		} else if (strcmp(buffer, "Yes") == 0) {
			printf(arg->ifyes, param);
			ret = 0;
		} else if (strcmp(buffer, "No") == 0) {
			printf(arg->ifno, param);
			ret = 1;
		} else {
			fprintf(stderr, "ndsctl: Error: opennds sent an abnormal reply.\n");
			ret = 2;
		}
	} else {
		while ((len = read(sock, buffer, sizeof(buffer) - 1)) > 0) {
			buffer[len] = '\0';
			printf("%s", buffer);
		}
		ret = 0;
	}

	shutdown(sock, 2);
	close(sock);
	return ret;
}

int
main(int argc, char **argv)
{
	const struct argument* arg;
	const char *socket;
	int i = 1;
	int counter;
	char lockfile[] = "/tmp/ndsctl.lock";
	char args[512] = {0};
	char argi[64] = {0};
	FILE *fd;

	if ((fd = fopen(lockfile, "r")) != NULL) {
		openlog ("ndsctl", LOG_CONS | LOG_PID | LOG_NDELAY, LOG_LOCAL1);
		syslog (LOG_NOTICE, "ndsctl is locked by another process");
		printf ("ndsctl is locked by another process\n");
		closelog ();
		fclose(fd);
		return 0;
	} else {
		//Create lock
		fd = fopen(lockfile, "w");
	}


	socket = strdup(DEFAULT_SOCK);

	if (argc <= i) {
		usage();
		fclose(fd);
		remove(lockfile);
		return 0;
	}

	if (strcmp(argv[1], "-h") == 0) {
		usage();
		fclose(fd);
		remove(lockfile);
		return 1;
	}

	if (strcmp(argv[1], "-s") == 0) {
		if (argc >= 2) {
			socket = strdup(argv[2]);
			i = 3;
		} else {
			usage();
			fclose(fd);
			remove(lockfile);
			return 1;
		}
	}

	arg = find_argument(argv[i]);

	if (arg == NULL) {
		fprintf(stderr, "Unknown command: %s\n", argv[i]);
		fclose(fd);
		remove(lockfile);
		return 1;
	}

	// Collect command line arguments then send the command
	snprintf(args, sizeof(args), "%s", argv[i+1]);

	if (argc > i) {
		for (counter=2; counter < argc-1; counter++) {
			snprintf(argi, sizeof(argi), ",%s", argv[i+counter]);
			strncat(args, argi, sizeof(argi));
		}
	}

	ndsctl_do(socket, arg, args);
	fclose(fd);
	remove(lockfile);
	return 0;
}
