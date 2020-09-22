## TFDestroy - deletes and erases projects and it contents.

## TODO: Erase git repositories
##       Trigger database shrink
##       Maintenance steps (detach project, backup reattach)
##       Check if project and sources exist before erasing, to avoid errors using TF Tool

## WARNING!! This software is available "AS IS" with no liability or warranty.
## Be aware this is a very destructive tool!! Once executed the actions cannot be undone. Create a backup before using it.
## Read the code before using it and use the "-WhatIf" switch to simulate the execution. Do not EVER use this tool on a production directly!
## I'm not responsible for any your consequences by the misusage using this tool. You've been warned. :)

## Usage: 
## .\tfdestroy.ps1 -Server "http://localhost:8080/devops" -Collection "JohnDoe" -ProjectMames @("Project 1","Project 2","Project 3") -PurgeDeleted

[CmdletBinding()]
param(    
    # Server URI
    [Parameter(Mandatory = $true)]
    [string] $Server,

    # Collection Name
    [Parameter(Mandatory = $true)]
    [string] $CollectionName,

    # List of projects to delete
    [array] $ProjectMames = @(),

    # Purges already deleted files (required if there are projects listed in -ProjectMames parameter)
    [switch] $PurgeDeleted,
    
    # Enables "/preview" flag on TF destroy command, that executes the prompt but with no actions applied.
    [switch] $WhatIf,

    # Skips project validation (used on TFS 2017 or earlier for retrocompatibility)
    [switch] $SkipVerify,

    # Team Foundation CLI Client path (Default: Visual studio 2019 Community)
    [string] $TFClientPath = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer"
)

try {
    if (-not $SkipVerify) {
        Write-Host "Validating existing projects..."
        $deletedProjects = Invoke-RestMethod -UseDefaultCredentials -Method "GET" -Uri "$Server/$CollectionName/_apis/projects?stateFilter=deleted&api-version=5.0"

        [array] $projectsToPurge = @();

        if ($ProjectMames.Length -eq 0) {
            $projectsToPurge = $deletedProjects.value
        }
        else {
            $wellFormedProjects = Invoke-RestMethod -UseDefaultCredentials -Method "GET" -Uri "$Server/$CollectionName/_apis/projects?stateFilter=wellFormed&api-version=5.0"

            $projectsToPurge = $deletedProjects.value + $wellFormedProjects.value

            if ($PurgeDeleted) {
                $projectsToPurge = ($projectsToPurge | Where-Object { $_.name -in $ProjectMames -or $_.state -eq "Deleted" })
            }
            else {
                $projectsToPurge = ($projectsToPurge | Where-Object { $_.name -in $ProjectMames })
            }
        }

        $projectsToPurge = $projectsToPurge | Select-Object { $_.name }
    }   
    else {
        $projectsToPurge = $ProjectMames
    }

    if ($projectsToPurge.Length -eq 0) {
        $message = "There are no projects to be deleted."
        if (-not $PurgeDeleted -and -not$ProjectMames.Length -eq 0) {
            $message += " Apply -purgeDeleted flag to purge already deleted projects."
        }

        throw $message
    }


    $defaultOption = 1
    $options = @(
        New-Object System.Management.Automation.Host.ChoiceDescription "&Delete","Deletes all refered projects"
        New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel","Cancels the operation"
    )

    [string] $projectList
    $projectsToPurge | ForEach-Object {
        $projectList += "`t`t$($projectsToPurge.IndexOf( $_ )): $_`n"
    }
    
    Write-Warning "The following projects will be permanently deleted.`n$projectList"


    $selectedOption = $Host.UI.PromptForChoice("TFS Purge Tool", "The operation cannot be undone. Proceed?", $options, $defaultOption)
    if ($selectedOption -eq 0) {
        Write-Host "Purging TFS projects in ""$CollectionName"" collection database..."

        $projectList = [string]::Empty

        if ($WhatIf) {
            Write-Host "WhatIf flag enabled. This is a preview only. No content will be deleted."
        }

        $projectsToPurge | foreach-object {
            Write-Host "Deleting `"$CollectionName/$_`"..."

            if ($WhatIf) {
                & "$TFClientPath\TF.exe" destroy """`$/$_""" /i /startcleanup /s:"$Server/$CollectionName" /preview
            }
            else {
                & "$TFClientPath\TF.exe" destroy """`$/$_""" /i /startcleanup /s:"$Server/$CollectionName"
                & "$TFClientPath\TfsDeleteProject.exe" /q /force /collection:"$Server/$CollectionName" """$_"""
            }
        }       

        Write-Host "Done."
    }
    else {
        Write-Host "Operation canceled. Exiting..."
    }
}
catch {
    Write-Error "$_"
    Write-Error "Execution failed. Check log above."
}