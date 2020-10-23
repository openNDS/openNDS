
CC?=gcc
CFLAGS?=-O2 -g -Wall
CFLAGS+=-Isrc
#CFLAGS+=-Wall -Wwrite-strings -pedantic -std=gnu99
LDFLAGS+=-pthread
LDLIBS=-lmicrohttpd

STRIP=yes

NDS_OBJS=src/auth.o src/client_list.o src/commandline.o src/conf.o \
	src/debug.o src/fw_iptables.o src/main.o src/http_microhttpd.o src/http_microhttpd_utils.o \
	src/ndsctl_thread.o src/safe.o src/tc.o src/util.o src/template.o

.PHONY: all clean install

all: opennds ndsctl

%.o : %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

opennds: $(NDS_OBJS) $(LIBHTTPD_OBJS)
	$(CC) $(LDFLAGS) -o opennds $+ $(LDLIBS)

ndsctl: src/ndsctl.o
	$(CC) $(LDFLAGS) -o ndsctl $+ $(LDLIBS)

clean:
	rm -f opennds ndsctl src/*.o
	rm -rf dist

install:
#ifeq(yes,$(STRIP))
	strip opennds
	strip ndsctl
#endif
	mkdir -p $(DESTDIR)/usr/bin/
	cp ndsctl $(DESTDIR)/usr/bin/
	cp opennds $(DESTDIR)/usr/bin/
	mkdir -p $(DESTDIR)/etc/opennds/htdocs/images
	cp resources/opennds.conf $(DESTDIR)/etc/opennds/
	cp resources/splash.html $(DESTDIR)/etc/opennds/htdocs/
	cp resources/splash.css $(DESTDIR)/etc/opennds/htdocs/
	cp resources/status.html $(DESTDIR)/etc/opennds/htdocs/
	cp resources/splash.jpg $(DESTDIR)/etc/opennds/htdocs/images/
	cp resources/opennds.service $(DESTDIR)/etc/systemd/system/
	mkdir -p $(DESTDIR)/usr/lib/opennds
	cp forward_authentication_service/binauth/binauth_log.sh $(DESTDIR)/usr/lib/opennds/
	sed -i 's/#!\/bin\/sh/#!\/bin\/bash/' $(DESTDIR)/usr/lib/opennds/binauth_log.sh
	cp forward_authentication_service/binauth/binauth_sitewide.sh $(DESTDIR)/usr/lib/opennds/
	sed -i 's/#!\/bin\/sh/#!\/bin\/bash/' $(DESTDIR)/usr/lib/opennds/binauth_sitewide.sh
	cp forward_authentication_service/binauth/userlist.dat $(DESTDIR)/etc/opennds/
	cp forward_authentication_service/binauth/splash_sitewide.html $(DESTDIR)/etc/opennds/htdocs/
	cp forward_authentication_service/PreAuth/login.sh $(DESTDIR)/usr/lib/opennds/
	sed -i 's/#!\/bin\/sh/#!\/bin\/bash/' $(DESTDIR)/usr/lib/opennds/login.sh
	cp forward_authentication_service/PreAuth/login-remote-image.sh $(DESTDIR)/usr/lib/opennds/
	sed -i 's/#!\/bin\/sh/#!\/bin\/bash/' $(DESTDIR)/usr/lib/opennds/login-remote-image.sh
	cp forward_authentication_service/libs/get_client_interface.sh $(DESTDIR)/usr/lib/opennds/
	sed -i 's/#!\/bin\/sh/#!\/bin\/bash/' $(DESTDIR)/usr/lib/opennds/get_client_interface.sh
	cp forward_authentication_service/libs/get_client_token.sh $(DESTDIR)/usr/lib/opennds/
	sed -i 's/#!\/bin\/sh/#!\/bin\/bash/' $(DESTDIR)/usr/lib/opennds/get_client_token.sh
	cp forward_authentication_service/libs/unescape.sh $(DESTDIR)/usr/lib/opennds/
	sed -i 's/#!\/bin\/sh/#!\/bin\/bash/' $(DESTDIR)/usr/lib/opennds/unescape.sh
	cp forward_authentication_service/libs/authmon.sh $(DESTDIR)/usr/lib/opennds/
	sed -i 's/#!\/bin\/sh/#!\/bin\/bash/' $(DESTDIR)/usr/lib/opennds/authmon.sh
	cp forward_authentication_service/libs/post-request.php $(DESTDIR)/usr/lib/opennds/
	cp forward_authentication_service/fas-aes/fas-aes.php $(DESTDIR)/etc/opennds/
	cp forward_authentication_service/fas-aes/fas-aes-https.php $(DESTDIR)/etc/opennds/

installservice:
	cp opennds.service /etc/systemd/system
	systemctl daemon-reload

