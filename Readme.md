# FixSPOFolderPath 

When folder structures and the corresponding FileRef values may become inconsistent.
The following script can be used to remediate this issue and restore consistency between the folder structure and FileRef entries.

Those are the parameters.

## FixSPOFolderPath.ps1

|Argument|Explanation|
|--|--|
|ApplicationID|PnP Application ID to connect as PnP.PowerShell app.|
|siteUrl|Site (Web) URL|
|listName|List Title|
|Fix|*-Fix* parameter will try to fix the issue. Otherwise, will report the issue in the console only |

