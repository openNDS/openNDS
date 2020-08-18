Walled Garden
#############

Preauthenticated clients are, by default, blocked from all access to the Internet.

Access to certain web sites can be allowed. For example, clients will automatically be granted access to an external FAS server for the purpose of authentication.

Access to other web sites may be manually granted so clients can be served content such as news, information, advertising, etc. This is achieved by openNDS by allowing access to the IP address of the web sites as required.

A set of such web sites is referred to as a Walled Garden.

Granting access by specifying the site IP address works well in simple cases but the administrative overhead can rapidly become very for example with social media sites that load balance high volumes of traffic over many possible IP addresses.

In addition, the IP address of any web site may change.

Rather than using IP addresses, a much more efficient method of granting access would be by using the web address (URL) of each site and have a background process populate a database of allowed IP addresses.

openNDS supports dynamic Walled Garden by utilising the combination of Dnsmasq(full version) and the ipset utility.

OpenWrt Walled Garden
*********************

Install by running the following commands:

.. code::

 opkg update
 opkg install ipset
 opkg remove dnsmasq
 opkg install dnsmasq-full

Configure as follows:

.. code::

 ipset create openndsset hash:ip

Configure dnsmasq:

.. code::

 uci add_list dhcp.@dnsmasq[0].ipset='/<fqdn1>/<fqdn2>/<fqdn3>/<fqdn...>/<fqdnN>/openndsset'

where <fqdn1> to <fqdnN> are the fully qualified domain names of the URLs you want to use to populate the ipset.

eg. For Facebook use facebook.com and fbcdn.net as fqdn1 and fqdn2

.. code::

 uci add_list dhcp.@dnsmasq[0].ipset='/facebook.com/fbcdn.net/openndsset'
 uci commit dhcp

Configure opennds by uncommenting the following two lines:

.. code::

	list preauthenticated_users 'allow tcp port 80 ipset openndsset'
	list preauthenticated_users 'allow tcp port 443 ipset openndsset'

Generic Linux Walled Garden
***************************
On most generic Linux platforms the procedure is in principle the same as for OpenWrt.

The ipset and full dnasmasq packages are requirements.

You can check the compile time options of dnsmasq with the following command:

.. code::

 dnsmasq --version | grep -m1 'Compile time options:' | cut -d: -f2

If the returned string contains "no-ipset" then you will have to upgrade dnsmasq to the full version.

Configure ipset as follows:

.. code::


 ipset create openndsset hash:ip

Configure dnsmasq by adding the following line to the dnsmasq config file:

.. code::

 ipset=/<fqdn1>/<fqdn2>/<fqdn3>/<fqdn...>/<fqdnN>/openndsset

where <fqdn1> to <fqdnN> are the fully qualified domain names of the URLs you want to use to populate the ipset.
eg. For Facebook use facebook.com and fbcdn.net as fqdn1 and fqdn2


.. code::

 ipset='/facebook.com/fbcdn.net/openndsset

Configure openNDS by adding the following two lines to the "**FirewallRuleSet preauthenticated-users**" section of the opennds.conf file:

.. code::

 FirewallRule allow tcp port 80 ipset openndsset
 FirewallRule allow tcp port 443 ipset openndsset


