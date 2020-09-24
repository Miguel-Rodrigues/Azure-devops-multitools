
[CmdletBinding()]
param (
    # Configuration file
    [Parameter(Mandatory=$true)]
    [string] $config
)

function LoadConfig([string] $configLocation) {
    
    # Accept jsonc (json with comments)
    $configFile = Get-Content $ConfigLocation -raw
    $configFile = $configFile -replace '(?m)(?<=^([^"]|"[^"]*")*)//.*' -replace '(?ms)/\*.*?\*/'
    $config = $configFile | ConvertFrom-Json

    if ($null -eq $config) {
        throw [ConfigurationException] "$ConfigLocation was not found is not correctly configured."
    }

    $config
}

try {
    $configObject = LoadConfig $config
    
    $configObject | ForEach-Object  {
        $definition = $_

        if (-not(Test-Path $definition.pool)) {
            New-Item $definition.pool -ItemType Directory
        }

        Set-Location $definition.pool

        $_.agents | ForEach-Object {

            if (-not(Test-Path $_.agent)) {
                New-Item $_.agent -ItemType Directory
            }

            if (-not(Test-Path $_.workingDir)) {
                New-Item $_.workingDir -ItemType Directory
            }

            Copy-Item -PassThru -Recurse -Path ..\..\vsts-agent-win-x64-2.144.2\* -Destination .\

            & $_.agent\config.cmd --url $definition.url --auth pat --token $definition.token --pool $definition.pool `
                --agent $_.agent --work $_.workingDir  --unattended --runAsService
        }

        Set-Location ..\
    }
}
catch {
    Write-Error $_
    Write-Host "Operation failed, check error above."
}