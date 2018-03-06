<#
.SYNOPSIS
    Create Delta Release
.DESCRIPTION
	Create folder that contains files that have been created or modified by a code release
.PARAMETER Rollback
	Switch to identify delta creation during a rollback process
.PARAMETER WebsiteFolderPath
    Path of the origin website folder in the file system
.PARAMETER ReleaseTag
    Name of the release tag in source control - $RELEASE_GIT_TAG in Jenkins - Format: Release/YYYYMMDD  
.PARAMETER ReleaseBaseFolderPath
	Path of the release base folder in the file system  
.PARAMETER CopyFolderName
	Name of the copy folder in the file system
.PARAMETER PathsToExclude
	List of relative paths in Website folder to exclude from being compared
.PARAMETER VerboseLog
    Switch to execute a release rollback
#>

function New-DeltaRelease {
	param(
		[switch]$Rollback,
		[string]$WebsiteFolderPath,
		[string]$ReleaseTag,
		[string]$ReleaseBaseFolderPath,
		[string]$CopyFolderName,
		[[string]]$PathsToExclude
	)

	$ErrorActionPreference = 'Stop'

	if(!$WebsiteFolderPath)
	{
		Write-Host "Website Folder Path parameter cannot be empty!"
		Exit 1
	}

	if(!$ReleaseTag)
	{
		Write-Host "Release Tag parameter cannot be empty!"
		Exit 1
	}

	if(!$ReleaseBaseFolderPath)
	{
		Write-Host "Release Base Folder Path parameter cannot be empty!"
		Exit 1
	}

	# Create destination delta release folder
	$releaseTagCheck = $ReleaseTag.StartsWith("Release/")
	$releaseDestinationFolder = $releaseTag
	if ($releaseTagCheck)
	{
		$releaseDestinationFolder = $releaseDestinationFolder.Replace("Release/","")
	}
	$releaseDestinationFolderPath = $ReleaseBaseFolderPath + "/" + $releaseDestinationFolder
	$releaseTempCopyFolder = $ReleaseBaseFolderPath + "/" + $CopyFolderName + "/" + (Split-Path $WebsiteFolderPath -leaf) + "/"

	$releaseDestinationChangedFolderPath = $releaseDestinationFolderPath + "/changed"
	$releaseDestinationAddedFolderPath = $releaseDestinationFolderPath + "/added"
	$releaseDestinationDeletedFolderPath = $releaseDestinationFolderPath + "/deleted"

	if (!(Test-Path $releaseDestinationFolderPath))
	{
		md $releaseDestinationFolderPath
		md $releaseDestinationChangedFolderPath
		md $releaseDestinationAddedFolderPath
		md $releaseDestinationDeletedFolderPath
	}
	
	# Create RegexEx to exclude paths from comparison
	[regex] $excludeMatchRegEx = '(?i)' + (($PathsToExclude |foreach {[regex]::escape($_)}) -join "|") + ''

	# Compare temp folder with website folder to detect new and modified files

	$SourceDocs = Get-ChildItem -Path $releaseTempCopyFolder -Recurse | where { $_.FullName.Replace($from, "") -notmatch $excludeMatchRegEx} | foreach  {Get-FileHash -Path $_.FullName}

	$DestDocs = Get-ChildItem -Path $WebsiteFolderPath -Recurse | where { $_.FullName.Replace($from, "") -notmatch $excludeMatchRegEx} | foreach  {Get-FileHash -Path $_.FullName}

	$diffFilesArray = (Compare-Object -ReferenceObject $SourceDocs -DifferenceObject $DestDocs -Property hash -PassThru).Path

	$diffFilesMessage = "Found " + $diffFilesArray.Count + " different file(s)!"

	Write-Host $diffFilesMessage

	$releaseTempCopyFolder = $releaseTempCopyFolder.Replace("/","\").TrimEnd("\")
	Write-Host ("ReleaseTempCopyFolder = " + $releaseTempCopyFolder)
	$WebsiteFolderPath = $WebsiteFolderPath.Replace("/","\").TrimEnd("\")
	Write-Host ("WebsiteFolderPath = " + $WebsiteFolderPath)

	# Loop through the list of different files and store them in the correct sub-release folders (changed, added, deleted)
	ForEach ($diffFile In $diffFilesArray)
	{
		# Normalize paths
		$diffFile = $diffFile.Replace("/","\")
		$releaseDestinationChangedFolderPath = $releaseDestinationChangedFolderPath.Replace("/","\")
		$releaseDestinationAddedFolderPath = $releaseDestinationAddedFolderPath.Replace("/","\")
		$releaseDestinationDeletedFolderPath = $releaseDestinationDeletedFolderPath.Replace("/","\")
		$filepath = Split-Path $diffFile
		$filename = Split-Path $diffFile -leaf

		# Changed file
		If ($diffFile.StartsWith($releaseTempCopyFolder,"CurrentCultureIgnoreCase") -And ($diffFilesArray -contains $diffFile.Replace($releaseTempCopyFolder,($WebsiteFolderPath))))
		{
			$relativePath = $filepath.Replace($releaseTempCopyFolder,"").TrimEnd("\")
			Write-Host ("ChangedFile - RelativePath = " + $relativePath)
			$destinationPath = $releaseDestinationChangedFolderPath + $relativePath + "\" + $filename
			Write-Host ("ChangedFile - DestinationPath = " + $destinationPath)
			$destinationFolder = $releaseDestinationChangedFolderPath + $relativePath
			Write-Host ("ChangedFile - DestinationFolder = " + $destinationFolder)
			New-Item -ItemType Directory -Force -Path $destinationFolder
			Copy-Item -Path $diffFile -Destination $destinationPath
		}
		# Added file
		ElseIf ($diffFile.StartsWith($WebsiteFolderPath,"CurrentCultureIgnoreCase") -And !($diffFilesArray -contains $diffFile.Replace(($WebsiteFolderPath),$releaseTempCopyFolder)))
		{
			$relativePath = $filepath.Replace($WebsiteFolderPath,"").TrimEnd("\")
			Write-Host ("AddedFile - RelativePath = " + $relativePath)
			$destinationPath = $releaseDestinationAddedFolderPath + $relativePath + "\" + $filename
			Write-Host ("AddedFile - DestinationPath = " + $destinationPath)
			$destinationFolder = $releaseDestinationAddedFolderPath + $relativePath
			Write-Host ("AddedFile - DestinationFolder = " + $destinationFolder)
			New-Item -ItemType Directory -Force -Path $destinationFolder
			Copy-Item -Path $diffFile -Destination $destinationPath
		}
		# Deleted file
		ElseIf ($diffFile.StartsWith($releaseTempCopyFolder,"CurrentCultureIgnoreCase") -And !($diffFilesArray -contains $diffFile.Replace($releaseTempCopyFolder,($WebsiteFolderPath))))
		{
			$relativePath = $filepath.Replace($releaseTempCopyFolder,"").TrimEnd("\")
			Write-Host ("DeletedFile - RelativePath = " + $relativePath)
			$destinationPath = $releaseDestinationDeletedFolderPath + $relativePath + "\" + $filename
			Write-Host ("DeletedFile - DestinationPath = " + $destinationPath)
			$destinationFolder = $releaseDestinationDeletedFolderPath + $relativePath
			Write-Host ("DeletedFile - DestinationFolder = " + $destinationFolder)
			New-Item -ItemType Directory -Force -Path $destinationFolder
			Copy-Item -Path $diffFile -Destination $destinationPath
		}
	}

	if (!$Rollback -And (Test-Path $releaseTempCopyFolder))
	{
		# Delete the Temp folder
		Remove-Item -Path $releaseTempCopyFolder -Recurse
	}
}
export-modulemember -function New-DeltaRelease