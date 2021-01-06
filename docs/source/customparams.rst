Custom Parameters
#################

Custom Parameters were first introduced in openNDS version 7.

Custom parameters are defined in the config file and are sent as fixed values to FAS in the encoded/encrypted query string where they can be parsed and used by the FAS.

This is particularly useful in a remote or centralised FAS that is serving numerous instances of openNDS at different locations/venues.

* Custom Parameters are listed in configuration file in the form of "param_name=param_value"


* param_name and param_value must be htmlentity encoded if containing white space or single quotes.

For example in the OpenWrt UCI config file:

``list fas_custom_parameters_list '<param_name1=param_value1> <param_name2=param_value2> [.....] <param_nameN=param_valueN>'``

A real example might be:

``list fas_custom_parameters_list 'location=main_building admin_email=norman@bates-motel.com>'``
