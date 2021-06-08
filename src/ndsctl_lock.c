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
  @file ndsctl_lock.c
  @brief ndsctl locking
  @author Copyright (C) 2021 Linus Lüssing <ll@simonwunderlich.de>
 */

#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>


#define NDSCTL_LOCK_TIMEOUT_MS 1000

int ndsctl_lock(const char *lockfile)
{
	int fd, i, ret;

	fd = open(lockfile, O_RDWR | O_CREAT);
	if (fd < 0)
		return -1;

	for (i = 0; i < NDSCTL_LOCK_TIMEOUT_MS; i++) {
		ret = lockf(fd, F_TLOCK, 0);
		if (ret == 0) {
			return fd;
		}

		/* persistent error, no reason to retry */
		if (errno != EACCES && errno != EAGAIN)
			break;

		/* sleep for 1ms */
		usleep(1000);
	}

	close(fd);
	return -1;
}

void ndsctl_unlock(int fd)
{
	lockf(fd, F_ULOCK, 0);
	close(fd);
}
