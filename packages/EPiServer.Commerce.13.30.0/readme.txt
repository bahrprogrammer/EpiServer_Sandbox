EPiServer.Commerce


INSTALLATION
============

During installation of this nuget package, any existing files and directory have been overwritten with new ones.

UPDATE SEARCH INDEX FOLDER
==========================

If you are upgrading an existing Commerce site, this step can be skipped.
This package installation sets the search index folder to [appDataPath]\Search\ECApplication.
It is required for this site and Commerce Manager site to have same search index folder. Either set the
appData/basePath attribute of the episerver.framework config section to the same value for both sites
(this affects both the search index and other configured paths using the [appDataPath] placeholder),
or edit Configs\Mediachase.Search.Config directly and set the basePath attribute of Indexers section
and the storage attribute of LuceneSearchProvider section.

ADDITIONAL INFORMATION
======================

For additional information regarding what's new, please visit the following pages:

http://world.episerver.com/documentation/Release-Notes/?packageGroup=Commerce

http://world.episerver.com/documentation/Upgrading/EPiserver-Commerce/

http://world.episerver.com/releases/
