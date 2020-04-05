How to Compile opennds
##########################

Linux/Unix
**********

The Libmicrohttpd library is a dependency of opennds so you must first iInstall libmicrohttpd including the header files (often called -dev package). Then proceed to download the opennds source files: 

.. code::

   git clone https://github.com/opennds/opennds.git
   cd opennds
   make

If you installed the libmicrohttpd to another location (e.g. /tmp/libmicrohttpd_install/)
replace path in the make call with

.. code::

   make CFLAGS="-I/tmp/libmicrohttpd_install/include" LDFLAGS="-L/tmp/libmicrohttpd_install/lib"

After compiling you can call ``make install`` to install opennds to /usr/

Making a Package for Installation
*********************************

OpenWrt Package
===============

To compile opennds and create its installable package, please use the package definition from the feeds package.

.. code::

   git clone git://git.openwrt.org/trunk/openwrt.git
   cd openwrt
   ./scripts/feeds update
   ./scripts/feeds install
   ./scripts/feeds install opennds

Select the appropriate "Target System" and "Target Profile" in the menuconfig menu and build the image.

.. code::

   make defconfig
   make menuconfig
   make

Debian Package
==============

First you must compile opennds as described above for Linux/Unix.
Then run the command:

.. code::

   make deb
