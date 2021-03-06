<#
.SYNOPSIS
    Rollback to a past Release
.DESCRIPTION
    Rollback to a specific past code release
.PARAMETER WebsiteFolderPath
    Path of the deployed website folder in the file system
.PARAMETER RollbackReleaseTag
    Name of the release tag in source control to rollback to - $ROLLBACK_GIT_TAG in Jenkins - Format: Release/YYYYMMDD  
.PARAMETER ReleaseBaseFolderPath
    Path of the release base folder in the file system
.PARAMETER ReleaseListLogFile
    Path of the release list log file   
#>
function Undo-Release {
    param(
        [string]$WebsiteFolderPath,
        [string]$RollbackReleaseTag,
        [string]$ReleaseBaseFolderPath,
        [string]$ReleaseListLogFile
    )

    $ErrorActionPreference = 'Stop'

    If(!$WebsiteFolderPath)
    {
        Write-Host "WebsiteFolderPath parameter cannot be empty!"
        Exit 1
    }

    If(!$RollbackReleaseTag)
    {
        Write-Host "RollbackReleaseTag parameter cannot be empty!"
        Exit 1
    }

    If(!$ReleaseBaseFolderPath)
    {
        Write-Host "ReleaseBaseFolderPath parameter cannot be empty!"
        Exit 1
    }

    If(!$ReleaseListLogFile)
    {
        Write-Host "ReleaseListLogFile parameter cannot be empty!"
        Exit 1
    }

    $lastDeploymentReleaseTag = ''
    $lastDeploymentStartingReleaseTag = ''
    $numberOfLinesInReleaseListLogFile = (Get-Content $ReleaseListLogFile | Measure-Object -Line).Lines
    If ($numberOfLinesInReleaseListLogFile -gt 2)
    {
        $lastDataRow = (Get-Content $ReleaseListLogFile)[-1]
        $lastDeploymentStartingReleaseTag = ($lastDataRow.Split(','))[0]
        $lastDeploymentReleaseTag = ($lastDataRow.Split(','))[1]
    }
    Else {
        Write-Host 'The delta release for the selected rollback target release is not available. The rollback cannot be executed.'
        Exit 1
    }

    # If the rollback release is the latest release
    If ($lastDeploymentReleaseTag.CompareTo($RollbackReleaseTag) -eq 0)
    {
        Write-Host 'The selected rollback release tag matches the latest release tag. No rollback needed.'
        Exit 0 
    }

    # If only one delta release has been saved so far
    If ($lastDeploymentStartingReleaseTag.CompareTo('') -eq 0)
    {
        Write-Host 'The delta release for the selected rollback target release is not available. The rollback cannot be executed.'
        Exit 1
    }
    # Otherwise identify the release to go back to and execute the rollback
    Else
    {
        # Find the number of the line that contains a starting tag that matches the rollback release tag
        $startingReleaseTagPattern = '^' + $RollbackReleaseTag + ','
        $lineNumber = Select-String -Path $ReleaseListLogFile -Pattern $startingReleaseTagPattern | Select-Object -Expand LineNumber

        # Rollback any intermediate release between the last release and the target rollback release
        For ($i = ($numberOfLinesInReleaseListLogFile); $i -gt $lineNumber-1; $i--)
        {
            $intermediateReleaseTag = (((Get-Content $ReleaseListLogFile)[$i-1]).Split(','))[0]
            $intermediateRollbackTag = (((Get-Content $ReleaseListLogFile)[$i-1]).Split(','))[1]

            $rollbackIntermediateMsg = 'Rolling back to the intermediate release ' + $intermediateReleaseTag
            Write-Host $rollbackIntermediateMsg
                    
            # Select Delta Release Folder
            $releaseTagCheck = $intermediateRollbackTag.StartsWith('Release/')
            $releaseDestinationFolder = $intermediateRollbackTag
            if ($releaseTagCheck)
            {
                $releaseDestinationFolder = $releaseDestinationFolder.Replace('Release/','')
            }
            $releaseDestinationFolderPath = $ReleaseBaseFolderPath + '/' + $releaseDestinationFolder

            $releaseDestinationChangedFolderPath = $releaseDestinationFolderPath + '/changed'
            $releaseDestinationAddedFolderPath = $releaseDestinationFolderPath + '/added'
            $releaseDestinationDeletedFolderPath = $releaseDestinationFolderPath + '/deleted'

            $releaseDestinationChangedFolderPath = $releaseDestinationChangedFolderPath.Replace("/","\")
            $releaseDestinationAddedFolderPath = $releaseDestinationAddedFolderPath.Replace("/","\")
            $releaseDestinationDeletedFolderPath = $releaseDestinationDeletedFolderPath.Replace("/","\")

            # Execure Rollback
            # 1 - Copy the changed files
            Write-Host "Rolling back changed files..."
            $changedFiles = Get-ChildItem -Path $releaseDestinationChangedFolderPath -Recurse | foreach {Get-FileHash -Path $_.FullName}
            ForEach ($changedFile in $changedFiles)
            {
                $changedFilePath = $changedFile.Path
                $filepath = Split-Path $changedFilePath
                $filename = Split-Path $changedFilePath -leaf
                Write-Host ("Rolling back " + $changedFilePath)
                $destinationPath = $WebsiteFolderPath + ($filepath.Replace($releaseDestinationChangedFolderPath,"")) + "\" + $filename
                Copy-Item -Path $changedFilePath -Destination $destinationPath
            }
            # 2 - Restore the deleted files
            Write-Host "Rolling back deleted files..."
            $deletedFiles = Get-ChildItem -Path $releaseDestinationDeletedFolderPath -Recurse | foreach {Get-FileHash -Path $_.FullName}
            ForEach ($deletedFile in $deletedFiles)
            {
                $deletedFilePath = $deletedFile.Path
                $filepath = Split-Path $deletedFilePath
                $filename = Split-Path $deletedFilePath -leaf
                Write-Host ("Rolling back " + $deletedFilePath)
                $destinationPath = $WebsiteFolderPath + ($filepath.Replace($releaseDestinationDeletedFolderPath,"")) + "\" + $filename
                $destinationFolder = $WebsiteFolderPath + ($filepath.Replace($releaseDestinationDeletedFolderPath,""))
                New-Item -ItemType Directory -Force -Path $destinationFolder
                Copy-Item -Path $deletedFilePath -Destination $destinationPath
            }
            # 3 - Remove the added files
            Write-Host "Rolling back added files..."
            $addedFiles = Get-ChildItem -Path $releaseDestinationAddedFolderPath -Recurse | foreach {Get-FileHash -Path $_.FullName}
            ForEach ($addedFile in $addedFiles)
            {
                $addedFilePath = $addedFile.Path
                Write-Host ("Rolling back " + $addedFilePath)
                $pathToDelete = $addedFilePath.Replace($releaseDestinationAddedFolderPath,$WebsiteFolderPath)
                if (Test-Path $pathToDelete)
                {
                    Remove-Item $pathToDelete
                }
            }
        }
    }
}
export-modulemember -function Undo-Release