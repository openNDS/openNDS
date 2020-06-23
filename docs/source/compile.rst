How to Compile openNDS
######################

Linux/Unix - Compile in Place on Target Hardware
************************************************

Make sure the development suite for your Linux distribution is installed.

The libmicrohttpd library (MHD) is a dependency of openNDS so compiling and installing this is a prerequisite.

**First**, create a working directory and "cd" into it.

**Next, Download and un-tar the libmicrohttpd source files.**

You can find a version number for MHD at https://ftp.gnu.org/gnu/libmicrohttpd/

.. code::

 wget https://ftp.gnu.org/gnu/libmicrohttpd/libmicrohttpd-0.9.70.tar.gz
 tar  -xf libmicrohttpd-0.9.70.tar.gz
 cd libmicrohttpd-0.9.70

where "0.9.70" is the MHD version number we are using in this example.

**Now configure and compile:**

.. code::

 ./configure
 make
 sudo make install
 sudo ldconfig
 cd ..


**Then proceed to download the opennds source files.**

You can find a release version number for openNDS at https://github.com/openNDS/openNDS/releases

.. code::

 wget https://codeload.github.com/opennds/opennds/tar.gz/v5.1.0
 tar -xf v5.1.0
 cd openNDS-5.1.0
 make
 sudo make install
 systemctl enable opennds

Where "5.1.0" is the openNDS version we are using in this example.

openNDS should now start automatically at boot time.

It can be manually started, restarted, stopped or disabled with the following commands:

.. code::

 systemctl start opennds

 systemctl restart opennds

 systemctl stop opennds

 systemctl disable opennds

The status of openNDS can be checked with the following command:

.. code::

 ndsctl status

On most Linux distributions you can read the system message log with the command:

.. code::

 sudo /usr/bin/cat /var/log/messages


OpenWrt Package
***************
The OpenWrt package feed supports cross-compiled openNDS packages for all OpenWrt targets. See the "Installing openNDS" section of this documentation.

Cross Compiling for OpenWrt
---------------------------
You can cross-compile openNDS from source and create your own installable package using the package definition from the feeds package.

.. code::

   git clone git://git.openwrt.org/trunk/openwrt.git
   cd openwrt
   ./scripts/feeds update
   ./scripts/feeds install
   ./scripts/feeds install opennds

Select the appropriate "Target System" and "Target Profile" in the menuconfig menu and build the image:

.. code::

   make defconfig
   make menuconfig
   make
