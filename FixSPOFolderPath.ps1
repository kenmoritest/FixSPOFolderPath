<#
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
# Resume
$list = Get-PnPList -Identity $listName
$missingfolderFile = ("missingfolder_" + $list.Id + ".txt")
$ApplicationId = "901bb72d-20fa-4034-b76d-9d654298edf2";
function Add-MissingFolderList($folderPath)
{
   if (!$missingfolderList.contains($folderPath))
   {
     Write-Host "Missing Folder: " $folderPath
     $returnlen = $missingfolderList.Add($folderPath)
   }
}

function Ensure-SPFolder($folderPath, [switch] $dummy)
{
  $retfolder = Resolve-PnPFolder $folderPath
  if ($retfolder)
  {
    if ($dummy)
    {
      Write-Host "Dummy Folder Created: " $folderPath    <# Action when all if and elseif conditions are false #>
    }
    else 
    {
      Write-Host "Folder Created: " $folderPath    <# Action when all if and elseif conditions are false #>
    }
  }
}

function Remove-DummySPFolder($folderpath, $folderServerRelativePath)
{
    if ((Get-PnPFolder -Url $folderpath).ItemCount -eq 0)
    {
      $ret = Remove-PnPFolder -Folder $folderServerRelativePath.SubString(0, $folderServerRelativePath.LastIndexOf("/")) -Name $folderServerRelativePath.SubString($folderServerRelativePath.LastIndexOf("/")) -Force
      Write-Host ("Dummy Folder Removed: " + $folderpath)
    }
    else 
    {
      Write-Host ("Dummy Folder is kept: " + $folderpath)      <# Action when all if and elseif conditions are false #>
    }
}

## ----
## DEBUG
## 
##   Disable those lines when used in prod
##-----
if ($Debug)
{
  Write-Host "---Debug Mode---"
  # Add dummy folder here to check if we can appropriately identify the missing folder from the logic.
  $returnlen = $allfolderList.Add("/Shared Documents/General/subfolder1/subfolder2")
  # Add dummy missing folder (that actually exists) here to test the folder/file move behavior.
  # File Move should have error, because source and dest are the same on this dummy test
  Add-MissingFolderList -folderPath "/Shared Documents/General/subfolder1/subfolder3"
}
## -----

Write-Host "---Detection Process---"
# Load from previous assessment. To avoid loss from crash or error.
if (Test-Path $missingfolderFile)
{
  Get-Content $missingfolderFile | ForEach-Object {
    Add-MissingFolderList -folderPath $_
  }
}

(Get-PnPListItem -List $listName -PageSize 5000 -Fields ("FileRef")).FieldValues |ForEach-Object { 
  $folderpath = $_.FileRef.SubString(0, $_.FileRef.LastIndexOf("/"));
  if (!$allfolderList.contains($folderpath))
  {
    $returnedlen = $allfolderList.Add($folderpath);
  }
}

$tempFolderPath = $null;
$allfolderList |ForEach-Object {
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
$missingfolderList | Add-Content $missingfolderFile

if ($Fix)
{
  Write-Host
  Write-Host "---Fix Process---"
  $missingfolderList |ForEach-Object {
    $folder = Ensure-SPFolder $_
    #Dummy Folder
    $dummyFolderPath = ($_ + "_" + $ApplicationId.Replace("-", "_"));
    $dummyFolderServerRelativePath = ((Get-PnPWeb).ServerRelativeUrl + $dummyFolderPath);
    Ensure-SPFolder $dummyFolderPath -Dummy

    (Get-PnPListItem -List $listName -FolderServerRelativeUrl ((Get-PnPWeb).ServerRelativeUrl + $_)) |ForEach-Object {
      if ($_.FieldValues.FSObjType -eq 1)
      {
        $ret = Move-PnPFolder -Folder $_.Folder -TargetFolder $dummyFolderServerRelativePath;
        $ret = Move-PnPFolder -Folder ($dummyFolderServerRelativePath + "/" + $_.FieldValues.FileLeafRef) -TargetFolder $_.FieldValues.FileDirRef
        Write-Host ("Folder Moved: " + $_.FieldValues.FileRef)
      }
      else
      {
        $ret = Move-PnPFile -SourceUrl $_.FieldValues.FileRef -TargetUrl $dummyFolderServerRelativePath -Force
        $ret = Move-PnPFile -SourceUrl ($dummyFolderServerRelativePath + "/" + $_.FieldValues.FileLeafRef) -TargetUrl $_.FieldValues.FileDirRef -Force
        Write-Host ("File Moved: " + $_.FieldValues.FileRef)
      }
    }
    Remove-DummySPFolder -folderpath $dummyFolderPath -folderServerRelativePath $dummyFolderServerRelativePath
  }
}


