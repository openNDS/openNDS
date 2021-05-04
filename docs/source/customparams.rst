Custom Parameters, Variables, Images and files
##############################################

Custom Parameters were first introduced in openNDS version 7.
With version 9.0.0, custom variables, images and files have been added.

Custom parameters
*****************

Custom parameters are defined in the config file and are sent as fixed values to FAS in the encoded/encrypted query string where they can be parsed and used by the FAS.

This is particularly useful in a remote or centralised FAS that is serving numerous instances of openNDS at different locations/venues.

* Any number of Custom Parameters can be listed in the configuration file, but each one must be in a separate entry in the form of "param_name=param_value"


* param_name and param_value must be urlencoded if containing white space or single quotes.

For example in the OpenWrt UCI config file:

``list fas_custom_parameters_list '<param_name1=param_value1>'``

``list fas_custom_parameters_list '<param_name2=param_value2>'``

etc.

A real example might be:

``list fas_custom_parameters_list 'location=main_building'``

``list fas_custom_parameters_list 'admin_email=norman@bates-motel.com>'``

Custom Dynamically Generated Form Fields
----------------------------------------
 Custom Dynamically Generated Form Fields are a special case of Custom Parameters.

 ThemeSpec scripts can dynamically generate Form Field html and inject this into the dynamic splash page sequence.

 This is achieved using a SINGLE line containing the keyword "input", in the form: fieldname:field-description:fieldtype

 Numerous fields can be defined in this single "input=" line, separated by a semicolon (;).

 The following Working Example applies to the installed ThemeSpec Files:

  theme_click-to-continue-custom-placeholders

  and

  theme_user-email-login-custom-placeholders

 This example inserts Phone Number and Home Post Code fields:

``list fas_custom_variables_list 'input=phone:Phone%20Number:text;postcode:Home%20Post%20Code:text'``
