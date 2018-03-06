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
		Remove-Item -Path $releaseTempCopyFolder -Recurse
	}

	md $releaseTempCopyFolder

	# Copy released website folder in temp folder
	Copy-Item -Path $WebsiteFolderPath -Destination $releaseTempCopyFolder -Recurse
	
	# Delete excluded items from website copy
	ForEach ($path in $PathsToExclude)
    {
		$absolutePath = $releaseTempCopyFolder + "/" + $path
		if ((Test-Path($absolutePath))
		{
			Remove-Item -Path $absolutePath -Recurse
		}
	}
}

export-modulemember -Function Copy-Website