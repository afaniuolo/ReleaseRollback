<#
.SYNOPSIS
    Deploy Website and Create Delta Release or Rollback Release
.DESCRIPTION
    This script will deploy a website and create a delta release or it will rollback code to a past release.
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

Import-Module ./Scripts/Rollback.CopyWebsite.psm1 -Force
Import-Module ./Scripts/Rollback.DeltaReleaseCreation.psm1 -Force
Import-Module ./Scripts/Rollback.ReleaseTracking.psm1 -Force
Import-Module ./Scripts/Rollback.ReleaseRollback.psm1 -Force

if (!$Rollback)
{
    $tempCopyFolderName = "TempWebsiteCopy"
    $latestCopyFolderName = "LatestWebsiteCopy"
    
    # 1. Make a temporary copy of the server website folder
	Copy-Website -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $tempCopyFolderName
	
	# 2a. Robocopy source website files to destination server website folder
    robocopy $WebsiteSourceFolderPath $WebsiteDestFolderPath /E /S /XD .svn
    if ($lastexitcode -gt 3)
    {
        Write-Host "Error - Failed to deploy website files using robocopy!"
        Exit 1
    }

	# 2b. If Unicorn is used, robocopy unicorn serialized files to destination server Unicorn serialization folder
    if ($Unicorn)
    {
        robocopy $UnicornSourceFolderPath $UnicornDestFolderPath /E /PURGE /S /XD .svn
        if ($lastexitcode -gt 3)
        {
            Write-Host "Error - Failed to deploy unicorn serialized files using robocopy!"
            Exit 1
        }
    }

	# 3. Create a delta release
    New-DeltaRelease -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseTag $ReleaseTag -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $tempCopyFolderName
	
	# 4. Track new release to listing tracking file
    Add-ReleaseToListFile -ReleaseListLogFile $ReleaseListLogFile -ReleaseTag $ReleaseTag
	
	# 5. Make a copy of the latest server website folder
    Copy-Website -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $latestCopyFolderName
}
else {
    # ROLLBACK EXECUTION
	# 1. Create an extra delta release (to catch manual changes in website folder after last automated release)
    $preRollbackReleaseTag = "Release/" + (Get-Date -format "yyyyMMdd") + "-ManualChanges"
    New-DeltaRelease -Rollback -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseTag $preRollbackReleaseTag -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $latestCopyFolderName
    # 2. Track extra release in listing tracking file
    Add-ReleaseToListFile -ReleaseListLogFile $ReleaseListLogFile -ReleaseTag $preRollbackReleaseTag
    # 3. Execute the code Rollback
    Undo-Release -WebsiteFolderPath $WebsiteDestFolderPath -RollbackReleaseTag $ReleaseTag -ReleaseBaseFolderPath $ReleaseBaseFolderPath -ReleaseListLogFile $ReleaseListLogFile
    # 4. Create post-rollback delta release
    $postRollbackReleaseTag = "Release/" + (Get-Date -format "yyyyMMdd") + "-Rollback"
    Copy-Website -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $tempCopyFolderName
    New-DeltaRelease -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseTag $postRollbackReleaseTag -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $latestCopyFolderName
    Add-ReleaseToListFile -ReleaseListLogFile $ReleaseListLogFile -ReleaseTag $postRollbackReleaseTag
    Copy-Website -WebsiteFolderPath $WebsiteDestFolderPath -ReleaseBaseFolderPath $ReleaseBaseFolderPath -CopyFolderName $latestCopyFolderName
}