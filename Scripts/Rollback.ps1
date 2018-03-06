<#
.SYNOPSIS
    Create a Delta Release or Rollback a Release
.DESCRIPTION
    This script will create a delta release or it will rollback code to a past release.
.PARAMETER Rollback
    Switch to execute a release rollback
.PARAMETER WebsiteSourceFolderPath
    Path of the source website folder in the file system
.PARAMETER WebsiteDestFolderPath
    Path of the deployed website folder in the file system
.PARAMETER ReleaseBaseFolderPath
    Path of the release base folder in the file system
.PARAMETER ReleaseTag
    Name of the release tag in source control - $RELEASE_GIT_TAG in Jenkins - Format: Release/YYYYMMDD  
.PARAMETER ReleaseListLogFile
    Path of the release list log file
.EXAMPLE
    Create a Delta Release
    .\DeployRollback.ps1 -WebsiteSourceFolderPath "D:\Website" -WebsiteDestFolderPath "D:\Rollback\Website" -ReleaseBaseFolderPath "D:\Rollback\DeltaReleases" -ReleaseTag "Release/20171108-A" -ReleaseListLogFile "D:\Rollback\DeltaReleases\releases.txt"
.EXAMPLE
    Rollback
    .\DeployRollback.ps1 -Rollback -WebsiteDestFolderPath "D:\Rollback\Website" -ReleaseBaseFolderPath "D:\Rollback\DeltaReleases" -ReleaseTag "Release/20171108-A" -ReleaseListLogFile "D:\Rollback\DeltaReleases\releases.txt"

#>
[CmdletBinding(DefaultParametersetName='Deploy')]
param(
    [Parameter(ParameterSetName='Rollback',Mandatory=$false)] [switch]$Rollback,
    [Parameter(ParameterSetName='Rollback',Mandatory=$false)] [string]$WebsiteSourceFolderPath,
    [Parameter(Mandatory=$true)] [string]$WebsiteDestFolderPath,
    [Parameter(Mandatory=$true)] [string]$ReleaseBaseFolderPath,
    [Parameter(Mandatory=$true)] [string]$ReleaseTag,
    [Parameter(Mandatory=$true)] [string]$ReleaseListLogFile
)

Import-Module ./Scripts/Rollback.CopyWebsite.psm1 -Force
Import-Module ./Scripts/Rollback.DeltaReleaseCreation.psm1 -Force
Import-Module ./Scripts/Rollback.ReleaseTracking.psm1 -Force
Import-Module ./Scripts/Rollback.ReleaseRollback.psm1 -Force

$tempCopyFolderName = "TempWebsiteCopy"
$latestCopyFolderName = "LatestWebsiteCopy"

# Relative paths to exclude from comparison in Website folder
$pathsToExclude = ["App_Data","temp",]


if (!$Rollback)
{   
	# 1. Create a delta release
    if (!(Test-Path ($ReleaseBaseFolderPath + "/" + $latestCopyFolderName)))
    {
        New-DeltaRelease -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseTag $ReleaseTag -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $tempCopyFolderName
    }
    else {
        New-DeltaRelease -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseTag $ReleaseTag -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $latestCopyFolderName
    }
	
	# 2. Track new release to listing tracking file
    Add-ReleaseToListFile -ReleaseListLogFile $ReleaseListLogFile -ReleaseTag $ReleaseTag
	
	# 3. Make a copy of the latest server website folder
    Copy-Website -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $latestCopyFolderName
}
else {
    # ROLLBACK EXECUTION
	# 1. Create an extra delta release (to catch manual changes in website folder after last automated release)
    $preRollbackReleaseTag = $ReleaseTag + "-ManualChanges"
    New-DeltaRelease -Rollback -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseTag $preRollbackReleaseTag -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $latestCopyFolderName
    # 2. Track extra release in listing tracking file
    Add-ReleaseToListFile -ReleaseListLogFile $ReleaseListLogFile -ReleaseTag $preRollbackReleaseTag
    # 3. Execute the code Rollback
    Undo-Release -WebsiteFolderPath $WebsiteDestFolderPath -RollbackReleaseTag $ReleaseTag -ReleaseBaseFolderPath $ReleaseBaseFolderPath -ReleaseListLogFile $ReleaseListLogFile
    # 4. Create post-rollback delta release
    $postRollbackReleaseTag = "Release/" + (Get-Date -format "yyyyMMdd") + "-Rollback-" + $ReleaseTag.Replace('Release/','')
    Copy-Website -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $tempCopyFolderName -PathsToExclude $pathsToExclude
    New-DeltaRelease -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseTag $postRollbackReleaseTag -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $latestCopyFolderName
    Add-ReleaseToListFile -ReleaseListLogFile $ReleaseListLogFile -ReleaseTag $postRollbackReleaseTag
    Copy-Website -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $latestCopyFolderName -PathsToExclude $pathsToExclude
}

Exit 0