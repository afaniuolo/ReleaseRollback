<#
.SYNOPSIS
    Create a Delta Release or Rollback a Release
.DESCRIPTION
    This script will create a delta release or it will rollback code to a past release.
.PARAMETER Rollback
    Switch to execute a release rollback
.PARAMETER WebsiteDestFolderPath
    Path of the deployed website folder in the file system
.PARAMETER ReleaseBaseFolderPath
    Path of the release base folder in the file system
.PARAMETER ReleaseTag
    Name of the release tag in source control - $RELEASE_GIT_TAG in Jenkins - Format: Release/YYYYMMDD  
.PARAMETER ReleaseListLogFile
    Path of the release list log file
.PARAMETER PathsToExclude
    List of relative paths in Website folder to exclude from being copied or compared
.EXAMPLE
    Create a Delta Release
    .\Rollback.ps1 -WebsiteSourceFolderPath "D:\Website" -WebsiteDestFolderPath "D:\Rollback\Website" -ReleaseBaseFolderPath "D:\Rollback\DeltaReleases" -ReleaseTag "Release/20171108-A" -ReleaseListLogFile "D:\Rollback\DeltaReleases\releases.txt" -PathsToExclude "obj","App_Data","temp"
.EXAMPLE
    Rollback
    .\Rollback.ps1 -Rollback -WebsiteDestFolderPath "D:\Rollback\Website" -ReleaseBaseFolderPath "D:\Rollback\DeltaReleases" -ReleaseTag "Release/20171108-A" -ReleaseListLogFile "D:\Rollback\DeltaReleases\releases.txt" -PathsToExclude "obj","App_Data","temp"

#>
[CmdletBinding(DefaultParametersetName='Deploy')]
param(
    [Parameter(ParameterSetName='Rollback',Mandatory=$false)] [switch]$Rollback,
    [Parameter(Mandatory=$true)] [string]$WebsiteDestFolderPath,
    [Parameter(Mandatory=$true)] [string]$ReleaseBaseFolderPath,
    [Parameter(Mandatory=$true)] [string]$ReleaseTag,
    [Parameter(Mandatory=$true)] [string]$ReleaseListLogFile,
	[Parameter(Mandatory=$false)] [string[]]$PathsToExclude
)

$ScriptDir = Split-Path -parent $MyInvocation.MyCommand.Path
Import-Module $ScriptDir\Rollback.CopyWebsite.psm1 -Force
Import-Module $ScriptDir\Rollback.DeltaReleaseCreation.psm1 -Force
Import-Module $ScriptDir\Rollback.ReleaseTracking.psm1 -Force
Import-Module $ScriptDir\Rollback.ReleaseRollback.psm1 -Force
Import-Module $ScriptDir\Rollback.CleanUp.psm1 -Force

$tempCopyFolderName = "TempWebsiteCopy"
$latestCopyFolderName = "LatestWebsiteCopy"

if (!$Rollback)
{   
	# 1. Create a delta release
    if (!(Test-Path ($ReleaseBaseFolderPath + "/" + $latestCopyFolderName)))
    {
        New-DeltaRelease -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseTag $ReleaseTag -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $tempCopyFolderName -PathsToExclude $PathsToExclude
    }
    else {
        New-DeltaRelease -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseTag $ReleaseTag -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $latestCopyFolderName -PathsToExclude $PathsToExclude
    }
	
	# 2. Track new release to listing tracking file
    Add-ReleaseToListFile -ReleaseListLogFile $ReleaseListLogFile -ReleaseTag $ReleaseTag
	
	# 3. Make a copy of the latest server website folder
    Copy-Website -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $latestCopyFolderName -PathsToExclude $PathsToExclude
	
	# 4. Clean Up old Delta Releases
	Remove-DeltaReleases -ReleaseBaseFolderPath $ReleaseBaseFolderPath -NumOfDeltaReleasesToRetain 10 -ReleaseListLogFile $ReleaseListLogFile
}
else {
    # ROLLBACK EXECUTION
	# 1. Create an extra delta release (to catch manual changes in website folder after last automated release)
    $preRollbackReleaseTag = $ReleaseTag + "-ManualChanges"
    New-DeltaRelease -Rollback -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseTag $preRollbackReleaseTag -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $latestCopyFolderName -PathsToExclude $PathsToExclude
    # 2. Track extra release in listing tracking file
    Add-ReleaseToListFile -ReleaseListLogFile $ReleaseListLogFile -ReleaseTag $preRollbackReleaseTag
    # 3. Execute the code Rollback
    Undo-Release -WebsiteFolderPath $WebsiteDestFolderPath -RollbackReleaseTag $ReleaseTag -ReleaseBaseFolderPath $ReleaseBaseFolderPath -ReleaseListLogFile $ReleaseListLogFile
    # 4. Create post-rollback delta release
    $postRollbackReleaseTag = "Release/" + (Get-Date -format "yyyyMMdd") + "-Rollback-" + $ReleaseTag.Replace('Release/','')
    Copy-Website -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $tempCopyFolderName -PathsToExclude $PathsToExclude
    New-DeltaRelease -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseTag $postRollbackReleaseTag -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $latestCopyFolderName -PathsToExclude $PathsToExclude
    Add-ReleaseToListFile -ReleaseListLogFile $ReleaseListLogFile -ReleaseTag $postRollbackReleaseTag
    Copy-Website -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $latestCopyFolderName -PathsToExclude $PathsToExclude
}

Exit 0