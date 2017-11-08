<#
.SYNOPSIS
    Deploy Website and Create Delta Release
.DESCRIPTION
    This script will deploy a website and create a delta release
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
    Deploy and Create Delta Release
    
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

Import-Module ./Rollback.CopyWebsite.psm1 -Force
Import-Module ./Rollback.DeltaReleaseCreation.psm1 -Force
Import-Module ./Rollback.ReleaseTracking.psm1 -Force
Import-Module ./Rollback.ReleaseRollback.psm1 -Force

if (!$Rollback)
{
    Copy-Website -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseBaseFolderPath $ReleaseBaseFolderPath

    robocopy $WebsiteSourceFolderPath $WebsiteDestFolderPath /E /PURGE /S /XD .svn
    if ($lastexitcode -gt 3)
    {
        Write-Host "Error - Failed to deploy website using robocopy!"
        Exit 1
    }

    New-DeltaRelease -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseTag $ReleaseTag -ReleaseBaseFolderPath $ReleaseBaseFolderPath

    Add-ReleaseToListFile -ReleaseListLogFile $ReleaseListLogFile -ReleaseTag $ReleaseTag
}
else {
    Undo-Release -WebsiteFolderPath $WebsiteDestFolderPath -RollbackReleaseTag $ReleaseTag -ReleaseBaseFolderPath $ReleaseBaseFolderPath -ReleaseListLogFile $ReleaseListLogFile
}