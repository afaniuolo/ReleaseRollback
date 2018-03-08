<#
.SYNOPSIS
    Clean Up of old Delta Releases
.DESCRIPTION
	Clean up of the delta releases, retaining the last N delta releases
.PARAMETER ReleaseBaseFolderPath
	Path of the release base folder in the file system  
.PARAMETER NumOfDeltaReleasesToRetain
	Name of the copy folder in the file system
.PARAMETER ReleaseListLogFile
    Path of the release list log file
#>

function Remove-DeltaReleases {
	param(
		[string]$ReleaseBaseFolderPath,
		[int]$NumOfDeltaReleasesToRetain,
		[string]$ReleaseListLogFile
	)

	$ErrorActionPreference = 'Stop'

	if(!$ReleaseBaseFolderPath)
	{
		Write-Host "Release Base Folder Path parameter cannot be empty!"
		Exit 1
	}
	
	if(!$NumOfDeltaReleasesToRetain)
	{
		Write-Host "NumOfDeltaReleasesToRetain parameter cannot be empty!"
		Exit 1
	}
	
	if(!$ReleaseListLogFile)
	{
		Write-Host "ReleaseListLogFile parameter cannot be empty!"
		Exit 1
	}

	# Read list of available releases from release tracking file
	if(Test-Path $ReleaseListLogFile)
	{
		if((Get-Content $ReleaseListLogFile | Measure-Object -Line).Lines -gt $NumOfDeltaReleasesToRetain+1)
		{
			$totNumLines = (Get-Content $ReleaseListLogFile | Measure-Object -Line).Lines
			$numOfLinesToDelete = $totNumLines - $NumOfDeltaReleasesToRetain
			
			For ($i=1; $i -le ($totNumLines - $NumOfDeltaReleasesToRetain - 1); $i++) 
			{
				# Read the line release tag
				$dataRow = (Get-Content $ReleaseListLogFile)[$i]
				$releaseTag = ($dataRow.Split(","))[1]
				
				# Delete the associated delta release folder
				$releaseDestinationFolder = $releaseTag.Replace("Release/","")
				$releaseDestinationFolderPath = $ReleaseBaseFolderPath + "\" + $releaseDestinationFolder
				if (Test-Path $releaseDestinationFolderPath)
				{
					Remove-Item -Path $releaseDestinationFolderPath -Recurse -Force
				}			
			}
			
			# Delete the lines of the deleted delta releases from the release file
			$tempFile = $ReleaseListLogFile + ".temp"
			Add-Content -Path $tempFile -Value (Get-Content $ReleaseListLogFile)[0]

			For ($i=($totNumLines-$NumOfDeltaReleasesToRetain); $i -lt $totNumLines; $i++) 
			{
				Add-Content -Path $tempFile -Value (Get-Content $ReleaseListLogFile)[$i]		
			}
			Set-Content -Path $ReleaseListLogFile -Value (Get-Content $tempFile)
			Remove-Item -Path $tempFile -Force
		}
	}
}
export-modulemember -function Remove-DeltaReleases