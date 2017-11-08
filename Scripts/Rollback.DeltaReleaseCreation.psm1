<#
.SYNOPSIS
    Create Delta Release
.DESCRIPTION
    Create folder that contains files that have been created or modified by a code release
.PARAMETER WebsiteFolderPath
    Path of the origin website folder in the file system
.PARAMETER ReleaseTag
    Name of the release tag in source control - $RELEASE_GIT_TAG in Jenkins - Format: Release/YYYYMMDD  
.PARAMETER ReleaseBaseFolderPath
    Path of the release base folder in the file system  
#>

function New-DeltaRelease {
	param([string]$WebsiteFolderPath,[string]$ReleaseTag,[string]$ReleaseBaseFolderPath)

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
	$releaseTempCopyFolder = $ReleaseBaseFolderPath + "/Temp/" + (Split-Path $WebsiteFolderPath -leaf) + "/"

	$releaseDestinationChangedFolderPath = $releaseDestinationFolderPath + "/changed/"
	$releaseDestinationAddedFolderPath = $releaseDestinationFolderPath + "/added/"
	$releaseDestinationDeletedFolderPath = $releaseDestinationFolderPath + "/deleted/"

	if (!(Test-Path $releaseDestinationFolderPath))
	{
		md $releaseDestinationFolderPath
		md $releaseDestinationChangedFolderPath
		md $releaseDestinationAddedFolderPath
		md $releaseDestinationDeletedFolderPath
	}

	# Compare temp folder with website folder to detect new and modified files

	$SourceDocs = Get-ChildItem -Path $releaseTempCopyFolder -Recurse | foreach  {Get-FileHash -Path $_.FullName}

	$DestDocs = Get-ChildItem -Path $WebsiteFolderPath -Recurse | foreach  {Get-FileHash -Path $_.FullName}

	$diffFilesArray = (Compare-Object -ReferenceObject $SourceDocs -DifferenceObject $DestDocs -Property hash -PassThru).Path

	$diffFilesMessage = "Found " + $diffFilesArray.Count + " different file(s)!"

	Write-Host $diffFilesMessage

	# Loop through the list of different files and store them in the correct sub-release folders (changed, added, deleted)
	ForEach ($diffFile In $diffFilesArray)
	{
		# Changed file
		If ($diffFile.StartsWith($releaseTempCopyFolder.Replace("/","\"),"CurrentCultureIgnoreCase") -And ($diffFilesArray -contains $diffFile.Replace($releaseTempCopyFolder.Replace("/","\"),($WebsiteFolderPath + "\"))))
		{
			$destinationPath = $releaseDestinationChangedFolderPath + ((Split-Path $diffFile).Replace($releaseTempCopyFolder.Replace("/","\"),"")) + "\" + (Split-Path $diffFile -leaf)
			$destinationFolder = $releaseDestinationChangedFolderPath + ((Split-Path $diffFile).Replace($releaseTempCopyFolder.Replace("/","\"),""))
			New-Item -ItemType Directory -Force -Path $destinationFolder
			Copy-Item -Path $diffFile -Destination $destinationPath
		}
		# Added file
		ElseIf ($diffFile.StartsWith($WebsiteFolderPath,"CurrentCultureIgnoreCase") -And !($diffFilesArray -contains $diffFile.Replace(($WebsiteFolderPath + "\"),$releaseTempCopyFolder.Replace("/","\"))))
		{
			$destinationPath = $releaseDestinationAddedFolderPath + ((Split-Path $diffFile).Replace($WebsiteFolderPath,"")) + "\" + (Split-Path $diffFile -leaf)
			$destinationFolder = $releaseDestinationAddedFolderPath + ((Split-Path $diffFile).Replace($WebsiteFolderPath,""))
			New-Item -ItemType Directory -Force -Path $destinationFolder
			Copy-Item -Path $diffFile -Destination $destinationPath
		}
		# Deleted file
		ElseIf ($diffFile.StartsWith($releaseTempCopyFolder.Replace("/","\"),"CurrentCultureIgnoreCase") -And !($diffFilesArray -contains $diffFile.Replace($releaseTempCopyFolder.Replace("/","\"),($WebsiteFolderPath + "\"))))
		{
			$destinationPath = $releaseDestinationDeletedFolderPath + ((Split-Path $diffFile).Replace($releaseTempCopyFolder.Replace("/","\"),"")) + "\" + (Split-Path $diffFile -leaf)
			$destinationFolder = $releaseDestinationDeletedFolderPath + ((Split-Path $diffFile).Replace($releaseTempCopyFolder.Replace("/","\"),""))
			New-Item -ItemType Directory -Force -Path $destinationFolder
			Copy-Item -Path $diffFile -Destination $destinationPath
		}
	}

	# Delete the Temp folder
	Remove-Item -Path $releaseTempCopyFolder -Recurse
}
export-modulemember -function New-DeltaRelease