﻿<#
 This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment. 

 THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, 
 INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  

 We grant you a nonexclusive, royalty-free right to use and modify the sample code and to reproduce and distribute the object 
 code form of the Sample Code, provided that you agree: 
    (i)   to not use our name, logo, or trademarks to market your software product in which the sample code is embedded; 
    (ii)  to include a valid copyright notice on your software product in which the sample code is embedded; and 
    (iii) to indemnify, hold harmless, and defend us and our suppliers from and against any claims or lawsuits, including 
          attorneys' fees, that arise or result from the use or distribution of the sample code.

Please note: None of the conditions outlined in the disclaimer above will supercede the terms and conditions contained within 
             the Premier Customer Services Description.
#>

param(
  [Parameter(Mandatory=$true)]
  $ApplicationId,
  [Parameter(Mandatory=$true)]
  $siteUrl,
  [Parameter(Mandatory=$true)]
  $listName, 
  [switch]
  $Fix
)

# For Debug Mode adding Test data
$Debug = $false

Connect-PnPOnline $siteUrl -ApplicationId $ApplicationId -Interactive

$allfolderList = [System.Collections.ArrayList]::new()
$missingfolderList = [System.Collections.ArrayList]::new()

(Get-PnPListItem -List $listName -PageSize 5000 -Fields ("FileRef")).FieldValues |% { 
  $folderpath = $_.FileRef.SubString(0, $_.FileRef.LastIndexOf("/"));
  if (!$allfolderList.contains($folderpath))
  {
    $returnedlen = $allfolderList.Add($folderpath);
  }
}

function Add-MissingFolderList($folderPath)
{
   if (!$missingfolderList.contains($folderPath))
   {
     Write-Host "Missing Folder: " $folderPath
     $returnlen = $missingfolderList.Add($folderPath)
   }
}

## ----
## DEBUG
## 
##   Disable those lines when used in prod
##-----
if ($Debug)
{
  # Add dummy folder here to check if we can appropriately identify the missing folder from the logic.
  $returnlen = $allfolderList.Add("/Shared Documents/General/subfolder1/subfolder2")
  # Add dummy missing folder (that actually exists) here to test the folder/file move behavior.
  # File Move should have error, because source and dest are the same on this dummy test
  Add-MissingFolderList -folderPath "/Shared Documents/General/subfolder1/subfolder3"
}
## -----

$tempFolderPath = $null;
$allfolderList |% {
  try
  {
    $tempFolderPath = $_;
    if ((Get-PnPFolder -Url $tempFolderPath -Includes "Exists").Exists -eq $true)
    {
      ## folder exists - expected hence do nothing
    }
    else
    {
      ## folder not exists
      Add-MissingFolderList -folderPath $tempFolderPath      
    }
  }
  catch
  {
    if ($_.Exception.HResult -eq -2146233079)
    {
      ## folder not exists
      Add-MissingFolderList -folderPath $tempFolderPath
    }
    else
    {
      throw $_;
    }
  }
}

if ($Fix)
{
  $missingfolderList |% {
    $folder = Resolve-PnPFolder $_
    Write-Host "Folder Created: " $_
    (Get-PnPListItem -List $listName -FolderServerRelativeUrl ((Get-PnPWeb).ServerRelativeUrl + $_)) |% {
      if ($_.FieldValues.FSObjType -eq 1)
      {
        Move-PnPFolder -Folder $_.Folder -TargetFolder $_.FieldValues.FileDirRef 
      }
      else
      {
        Move-PnPFile -SourceUrl $_.FieldValues.FileRef -TargetUrl $_.FieldValues.FileDirRef -Force
      }
    }
  }
}


