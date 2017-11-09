<#
.SYNOPSIS
    Deploy Website and Create Delta Release
.DESCRIPTION
    This script will deploy a website and create a delta release
.PARAMETER Rollback
    Switch to execute a release rollback
.PARAMETER Unicorn
    Switch to execute robocopy of Unicorn serialized files
.PARAMETER WebsiteSourceFolderPath
    Path of the source website folder in the file system
.PARAMETER WebsiteDestFolderPath
    Path of the deployed website folder in the file system
.PARAMETER UnicornSourceFolderPath
    Path of the source Unicorn serialization folder in the file system
.PARAMETER UnicornDestFolderPath
    Path of the deployed Unicorn serialization folder in the file system
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
    Deploy with Unicorn files and Create Delta Release
    .\DeployRollback.ps1 -Unicorn -WebsiteSourceFolderPath "D:\Website" -WebsiteDestFolderPath "D:\Rollback\Website" -UnicornSourceFolderPath "D:\Data\Unicorn" -UnicornDestFolderPath "D:\Rollback\Data\Unicorn" -ReleaseBaseFolderPath "D:\Rollback\DeltaReleases" -ReleaseTag "Release/20171108-A" -ReleaseListLogFile "D:\Rollback\DeltaReleases\releases.txt"
.EXAMPLE
    Rollback
    .\DeployRollback.ps1 -Rollback -WebsiteDestFolderPath "D:\Rollback\Website" -ReleaseBaseFolderPath "D:\Rollback\DeltaReleases" -ReleaseTag "Release/20171108-A" -ReleaseListLogFile "D:\Rollback\DeltaReleases\releases.txt"

#>
[CmdletBinding(DefaultParametersetName='Deploy')]
param(
    [Parameter(ParameterSetName='Rollback',Mandatory=$false)] [switch]$Rollback,
    [Parameter(ParameterSetName='Rollback',Mandatory=$false)] [switch]$Unicorn,
    [Parameter(ParameterSetName='Rollback',Mandatory=$false)] [string]$WebsiteSourceFolderPath,
    [Parameter(Mandatory=$true)] [string]$WebsiteDestFolderPath,
    [Parameter(ParameterSetName='Rollback',Mandatory=$false)] [string]$UnicornSourceFolderPath,
    [Parameter(ParameterSetName='Rollback',Mandatory=$false)] [string]$UnicornDestFolderPath,
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
    $tempCopyFolderName = "TempWebsiteCopy"
    $latestCopyFolderName = "LatestWebsiteCopy"
    
    Copy-Website -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $tempCopyFolderName

    robocopy $WebsiteSourceFolderPath $WebsiteDestFolderPath /E /S /XD .svn
    if ($lastexitcode -gt 3)
    {
        Write-Host "Error - Failed to deploy website files using robocopy!"
        Exit 1
    }

    if ($Unicorn)
    {
        robocopy $UnicornSourceFolderPath $UnicornDestFolderPath /E /PURGE /S /XD .svn
        if ($lastexitcode -gt 3)
        {
            Write-Host "Error - Failed to deploy unicorn serialized files using robocopy!"
            Exit 1
        }
    }

    New-DeltaRelease -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseTag $ReleaseTag -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $tempCopyFolderName

    Add-ReleaseToListFile -ReleaseListLogFile $ReleaseListLogFile -ReleaseTag $ReleaseTag

    Copy-Website -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $latestCopyFolderName
}
else {
    # Create an extra delta release (to catch manual changes in website folder after last automated release)
    $preRollbackReleaseTag = "Release/" + (Get-Date -format "yyyyMMdd") + "-ManualChanges"
    New-DeltaRelease -Rollback -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseTag $preRollbackReleaseTag -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $latestCopyFolderName
    # Add extra release in release list log file
    Add-ReleaseToListFile -ReleaseListLogFile $ReleaseListLogFile -ReleaseTag $preRollbackReleaseTag
    # Execute the Rollback
    Undo-Release -WebsiteFolderPath $WebsiteDestFolderPath -RollbackReleaseTag $ReleaseTag -ReleaseBaseFolderPath $ReleaseBaseFolderPath -ReleaseListLogFile $ReleaseListLogFile
    # Create post-rollback delta release
    $postRollbackReleaseTag = "Release/" + (Get-Date -format "yyyyMMdd") + "-Rollback"
    Copy-Website -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $tempCopyFolderName
    New-DeltaRelease -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseTag $postRollbackReleaseTag -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $latestCopyFolderName
    Add-ReleaseToListFile -ReleaseListLogFile $ReleaseListLogFile -ReleaseTag $postRollbackReleaseTag
    Copy-Website -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $latestCopyFolderName
}