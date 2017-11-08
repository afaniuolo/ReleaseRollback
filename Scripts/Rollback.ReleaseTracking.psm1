<#
.SYNOPSIS
    Add Release record to Release List log file
.DESCRIPTION
    Add Release record to Release List log file
.PARAMETER ReleaseListLogFile
    Path of the release list log file
.PARAMETER ReleaseTag
    Number of the current Jenkins build   
#>
function Add-ReleaseToListFile {	
	param([string]$ReleaseListLogFile,[string]$ReleaseTag)

	$ErrorActionPreference = 'Stop'

	if(!$ReleaseListLogFile)
	{
		Write-Host "ReleaseListLogFile parameter cannot be empty!"
		Exit 1
	}

	if(!$ReleaseTag)
	{
		Write-Host "ReleaseTag parameter cannot be empty!"
		Exit 1
	}

	# Verify that the ReleaseListLogFile file exists, otherwise create it with the header
	if (!(Test-Path $ReleaseListLogFile))
	{
		Write-Host "Creating Release List Log File..."
		New-Item -Path $ReleaseListLogFile
		"PreviousReleaseTag,CurrentReleaseTag" | Add-Content $ReleaseListLogFile
	}

	# Add latest build release record to ReleaseListLogFile file.
	$lastReleaseTag = ""
	if ((Get-Content $ReleaseListLogFile | Measure-Object –Line).Lines -gt 1)
	{
		$lastDataRow = (Get-Content $ReleaseListLogFile)[-1]
		$lastReleaseTag = ($lastDataRow.Split(","))[1];
	}
	$newDataRow = $lastReleaseTag + "," + $ReleaseTag
	$newDataRow | Add-Content $ReleaseListLogFile;

}
export-modulemember -function Add-ReleaseToListFile 