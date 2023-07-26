[CmdletBinding()]
param(
    # the full file path to the config.yml file to use for environment variables
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ConfigYml
)


Write-Output "Using ${ConfigYml}"
$content = Get-Content -Path $ConfigYml

foreach($line in $content) {
    if ($line.Contains("#")) { continue }

    $line        = $line.TrimStart() -Split "\s*:\s*"
    $envVarName  = $line[0]
    $envVarValue = $line[1]

    if($envVarName  -notmatch "\w+") { continue }
    if($envVarValue -notmatch "\w+") { continue }
    if($envVarValue  -match "\`$\[") { continue } # These are glb-common variables that can not currently be matched.

    if($envVarName -notin (Get-ChildItem -Path "Env:").Name) {
        Write-Output "`nExporting ${envVarName}`n`t 👉 ${envVarValue}"
        Write-Output "##vso[task.setvariable variable=${envVarName}]${envVarValue}"
    }
}


<#
    .SYNOPSIS
        A simple script to turn a config.yml file contents into environment variables.

    .DESCRIPTION
        Not all config.yml files can be used in the same initiate pipeline. This script
        allows a config.yml file from a repo to be used in order to perform the token
        replacement context in the following task.
#>
