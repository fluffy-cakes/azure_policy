[CmdletBinding()]
param(
    # the name of the management group for where the policies reside
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$mgmtGroupName
)



$PSVersionTable
$ErrorActionPreference = "stop"

Import-Module "${Env:SYSTEM_DEFAULTWORKINGDIRECTORY}/glb-libraries/scripts/modules/module_install_modules.psm1"
Import-Module "${Env:SYSTEM_DEFAULTWORKINGDIRECTORY}/glb-libraries/scripts/modules/PolicyDeploymentUtilities"
Set-PSModule -Name "Az"



$ssvTsSub = Get-AzSubscription |
    Where-Object {
        $_.Name -match "\w{3}-glb-ssv-ts"
    }

# Ensure focus on current subscription
Write-Output "`n`n##[debug]🐞`tSetting to subscription: $($ssvTsSub.Name)"
Set-AzContext -SubscriptionId $ssvTsSub.Id
if((Get-AzContext).Subscription.Id -ne $ssvTsSub.Id) {
    Write-Output '
     _______________________________
    / Subscription has not been set \
    \          correctly!           /
     -------------------------------
            \   ^__^
             \  (oo)\_______
                (__)\       )\/\
                    ||----w |
                    ||     ||'
    throw "CowSay!"
}




switch -Regex ($mgmtGroupName.ToLower()) {
    "^pr"   { $buildRepositoryName = "pr"  }
    default { $buildRepositoryName = "glb" }
}



$tsObj = [PSObject]@{
    "definitions" = @()
    "initiatives" = @()
    "assignments" = @()
}



$thisRsgDef = Get-TsRsg `
    -BuildRepoName    "glb" `
    -CurrentDirectory "definitions" `
    -Tenant           $Env:POLICY_TENANT

Write-Output "Retrieving template specs - definitions - ${thisRsgDef}"
(Get-AzTemplateSpec -ResourceGroupName $thisRsgDef).Name.ForEach({ $tsObj.definitions += $_ })



$thisRsgIni = Get-TsRsg `
    -BuildRepoName    $buildRepositoryName `
    -CurrentDirectory "initiatives" `
    -Environment      $Env:POLICY_ENVIRONMENT `
    -Tenant           $Env:POLICY_TENANT

Write-Output "Retrieving template specs - initiatives - ${thisRsgIni}"
(Get-AzTemplateSpec -ResourceGroupName $thisRsgIni).Name.ForEach({ $tsObj.initiatives += $_ })



$thisRsgAss = Get-TsRsg `
    -BuildRepoName    $buildRepositoryName `
    -CurrentDirectory "assignments" `
    -Environment      $Env:POLICY_ENVIRONMENT `
    -Tenant           $Env:POLICY_TENANT

Write-Output "Retrieving template specs - assignments - ${thisRsgAss}"
(Get-AzTemplateSpec -ResourceGroupName $thisRsgAss).Name.ForEach({ $tsObj.assignments += $_ })



Write-OutputColour Green "`n`nTemplate spec object:"
$tsObj |
    ConvertTo-Json -Depth 99

$tsObj |
    ConvertTo-Json -Depth 99 |
        Out-File -FilePath "./tsObj.json"


<#
    .SYNOPSIS
        A simple script to list the policies deployed in Template Spec subscription.

    .DESCRIPTION
        By using the supplied management group name, this script will locate the
        resource group for where its policy Template Spec files reside and export
        them as a JSON object for us in later pipelines. This had to be done as a
        standalone script due to the inbability for the Policy service principal
        to read Azure resources.
#>
