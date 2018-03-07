<#
.SYNOPSIS
    Create Temp Website Folder
.DESCRIPTION
    Create folder that contains files that have been created or modified by a code release
.PARAMETER WebsiteFolderPath
    Path of the origin website folder in the file system
.PARAMETER ReleaseBaseFolderPath
	Path of the release base folder in the file system  
.PARAMETER CopyFolderName
	Name of the copy folder in the file system
.PARAMETER PathsToExclude
	List of relative paths in Website folder to exclude from being copied
#>
function Copy-Website {
	param(
		[string]$WebsiteFolderPath,
		[string]$ReleaseBaseFolderPath,
		[string]$CopyFolderName,
		[string[]]$PathsToExclude
	)

	$ErrorActionPreference = 'Stop'

	if(!$WebsiteFolderPath)
	{
		Write-Host "WebsiteFolderPath parameter cannot be empty!"
		Exit 1
	}

	if(!$ReleaseBaseFolderPath)
	{
		Write-Host "ReleaseBaseFolderPath parameter cannot be empty!"
		Exit 1
	}

	if(!$CopyFolderName)
	{
		Write-Host "CopyFolderName parameter cannot be empty!"
		Exit 1
	}

	# Create temp folder - copy of website folder
	$releaseTempCopyFolder = $ReleaseBaseFolderPath + "/" + $CopyFolderName

	if (Test-Path $releaseTempCopyFolder)
	{
		Remove-Item -Path $releaseTempCopyFolder -Recurse -Force
	}

	md $releaseTempCopyFolder

	# Create RegexEx to exclude paths from copy
	[regex] $excludeMatchRegEx = '(?i)^(' + (($PathsToExclude |foreach {[regex]::escape($_)}) -join "|") + ')'
	
	# Copy released website folder in temp folder
	Get-ChildItem -Path $WebsiteFolderPath -Recurse | where {$_.FullName.Replace($WebsiteFolderPath, "") -notmatch $excludeMatchRegEx} | Copy-Item -Destination {
	  if ($_.PSIsContainer) {
	   Join-Path $releaseTempCopyFolder $_.Parent.FullName.Substring($WebsiteFolderPath.length)
	  } else {
	   Join-Path $releaseTempCopyFolder $_.FullName.Substring($WebsiteFolderPath.length)
	  }
	} -Force
}

export-modulemember -Function Copy-Website