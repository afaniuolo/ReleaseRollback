<#
.SYNOPSIS
    Create Temp Website Folder
.DESCRIPTION
    Create folder that contains files that have been created or modified by a code release
.PARAMETER WebsiteFolderPath
    Path of the origin website folder in the file system
.PARAMETER ReleaseBaseFolderPath
	Path of the release base folder in the file system  
#>
function Copy-Website {
	param([string]$WebsiteFolderPath,[string]$ReleaseBaseFolderPath)

	$ErrorActionPreference = 'Stop'

	if(!$WebsiteFolderPath)
	{
		Write-Host "Website Folder Path parameter cannot be empty!"
		Exit 1
	}

	if(!$ReleaseBaseFolderPath)
	{
		Write-Host "Release Base Folder Path parameter cannot be empty!"
		Exit 1
	}

	# Create temp folder - copy of website folder
	$releaseTempCopyFolder = $ReleaseBaseFolderPath + "/Temp"

	if (Test-Path $releaseTempCopyFolder)
	{
		Remove-Item -Path $releaseTempCopyFolder -Recurse
	}

	md $releaseTempCopyFolder

	# Copy released website folder in temp folder
	Copy-Item -Path $WebsiteFolderPath -Destination $releaseTempCopyFolder -Recurse
}

export-modulemember -Function Copy-Website