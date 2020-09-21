[CmdletBinding()]
param(    
    # Server URI
    [Parameter(Mandatory=$true)]
    [string] $Server,

    # Collection Name
    [Parameter(Mandatory=$true)]
    [string] $CollectionName,

    # PAT (Personal Access Token) for authentication
    [Parameter(Mandatory=$true)]
    [string] $AccessToken,

    # List of projects to delete
    [array] $ProjectMames,

    # Team Foundation CLI Client path (Default: Visual studio 2019 Community)
    [string] $TFClientPath = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\tf.exe",
    
    # enables "/preview" flag on TF command
    [switch] $WhatIf = $False
)

Write-Host "Validating project existence"
$headers = @{
    Authorization = "Basic $AccessToken"
}

# $deletedProjects = Invoke-RestMethod -Method "GET" -Headers $headers -Uri "http://$Server/$CollectionName/_apis/projects?stateFilter=deleted&api-version=5.0-preview.1"

# if (-not [Array]::Empty($existingProjects)) {
#     $existingProjects = Invoke-RestMethod -Method "GET" -Headers $headers -Uri "http://$Server/$CollectionName/_apis/projects?stateFilter=wellFormed&api-version=5.0-preview.1"
# }

$defaultOption = 1
$options = @(
    New-Object System.Management.Automation.Host.ChoiceDescription "&Delete","Deletes all refered projects"
    New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel","Cancels the operation"
)

Write-Warning "The following projects will be permanently deleted."

$projectsToPurge | ForEach-Object {
    Write-Warning "${ $projectsToPurge.IndexOf($_) }: $_.Name - $_.State"
  }


$selectedOption = $Host.UI.PromptForChoice("TFS Purge Tool", "The operation cannot be undone. Proceed?", $options, $defaultOption))
if ($selectedOption -eq 0) {
    Write-Host "Purging TFS projects in ""$CollectionName"" collection database..."

    $command = "$TFClientPath destroy /i /startcleanup /collection $Server/$collectionName /loginType:OAuth /login:.,$AccessToken)"

    $projectsToPurge | foreach-object {
        "$$/$_"
    }
    
    if ($WhatIf) {
        Write-Information "WhatIf flag enabled. This is a preview only. No content will be deleted."
        $command += " /preview"
    }

    & $command

    Write-Host "All projects deleted."
}
else {
    Write-Host "Operation canceled. Exiting..."
}