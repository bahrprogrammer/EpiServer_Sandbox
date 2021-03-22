EPiServer.Commerce.UI.ManagerIntegration
- Not part of public API


Installation
============

Starting from release 7.5, the EPiServer Commerce Manager integration has been converted to a standard
nuget package. This means that content files and assemblies will be added to the project. As a part of
the conversion the previously installed add-on package needs to be removed.

There are several project configuration steps performed as part of the package installation; these
are documented below. If any of the configuration steps fail during the installation a message box
will be displayed describing the issue.


Remove add-on assemblies
------------------------

This step removes EPiServer.Commerce.AddOns.Manager.dll (if installed) from the modulesbin folder.
If you have reconfigured the probing path for your site, then these assemblies will be removed from the
configured location.

If you receive an error during this step, then the process installing the nuget package does not
have permission to delete the files. In this case, a user with the appropriate permissions will
need to delete EPiServer.Commerce.AddOns.Manager.dll (if installed) from the modulesbin folder manually.

Update packages.config
----------------------

This step removes the EPiServer.Commerce.AddOns.Manager package entry from the packages.config 
file in order to unregister them from the add-on system.

If you receive an error during this step, then the process installing the nuget package does not
have permission to read or write the file. In this case, a user with the appropriate permissions
will need to remove the EPiServer.Commerce.AddOns.Manager package entriy manually. By default, 
the packages.config file is located inside the modules folder in appdata.

Remove add-on folders
---------------------

This step removes the EPiServer.Commerce.AddOns.Manager folder and its contents from the modules folder.

If you receive an error during this step, then the process installing the nuget package does not
have permission to delete the folders or their contents. In this case, a user with the appropriate
permissions will need to remove the EPiServer.Commerce.AddOns.Manager folder manually. By default, 
these folders are located inside the modules folder in appdata.

Update Commerce Manager Link in Web.config
------------------------------------------

This step is required if you have an existing Commerce Manager site. 

In appSettings tag of web.config, update "CommerceManagerLink" key with the link to Commerce Manager site.

See example:
<add key="CommerceManagerLink" value="http://<YOUR_COMMERCE_MANAGER_SITE>" />
