$PSVersionTable
$ErrorActionPreference = "stop"




Import-Module "${Env:SYSTEM_DEFAULTWORKINGDIRECTORY}/glb-libraries/scripts/modules/module_install_modules.psm1"
Set-PSModule "Az.ResourceGraph"




function Set-TheOutput {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$key,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$value
    )

    Write-Host $key.PadRight(80, " ") $value
    Write-Host "##vso[task.setVariable variable=${key}]${value}"
}



Write-Host "`n`n##[debug]🐞`tDynamically generating Subscription ID variables"
$result = Search-AzGraph -Query "resourcecontainers | where type == 'microsoft.resources/subscriptions'"

foreach($sub in ($result | Sort-Object -Property "name")) {
    $nameSub = $sub.name.Replace("-", "_")

    Set-TheOutput `
        -Key  "dyn_sub_${nameSub}" `
        -Value $sub.subscriptionId
}



<#
    .SYNOPSIS
        Create variables from deployed resources using Azure Graph Explorer

    .DESCRIPTION
        This script will be utilised to create variables dynamically by a fail safe manner of
        searching for resources deployed using Azure Graph Explorer. These variables can then
        be used in parameter files and swapped out when the token-replacement step runs. This
        should cut down the need of hardcoded variables and many scripts.
#>
