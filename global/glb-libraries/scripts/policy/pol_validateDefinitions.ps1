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




"Current working directory: $((Get-Location).Path)"
tree



Write-OutputColour Green "`n`n`nValidating deleted Definintions"
$deleteTemplateSpec = @()
$filesBicep         = @()
$filesTemplateSpec  = @()


(Get-ChildItem `
    -File `
    -Include "*.bicep" `
    -Path "." `
    -Recurse |
        Where-Object {
            $_.DirectoryName -match "definitions\$((Get-Location).Provider.ItemSeparator)\w+"
        }).BaseName |
            Sort-Object |
                ForEach-Object {
                    $filesBicep += $_
                }


Write-Output "👇 Bicep files found"
$filesBicep


$thisRsgDef = Get-TsRsg `
    -BuildRepoName    "glb" `
    -CurrentDirectory "definitions" `
    -Tenant           $Env:POLICY_TENANT

Write-Output "`nRetrieving template specs - definitions - ${thisRsgDef}"
(Get-AzTemplateSpec -ResourceGroupName $thisRsgDef).Name.ForEach({ $filesTemplateSpec += $_ })


$filesTemplateSpec |
    ForEach-Object {
        if($_ -notin $filesBicep) {
            $deleteTemplateSpec += $_
        }
    }



if($deleteTemplateSpec -ge 1) {
    Write-Output "`n👇 Template Specs not linked to Bicep files"
    $deleteTemplateSpec

    foreach($item in $deleteTemplateSpec) {
        Write-Output "`nDeleting ${thisRsgDef}/$(Write-OutputColour Red "${item}  💥")"

        Get-AzTemplateSpec `
            -Name              $item `
            -ResourceGroupName $thisRsgDef |
                Remove-AzTemplateSpec -Force -Verbose
    }
}


<#
    .SYNOPSIS
        A script to identify if any Bicep files have been deleted and remove their counterpart
        Template Spec.

    .DESCRIPTION
        A simple comparison to identify Bicep files that reisde in the current running repository
        and remove their counterpart Template Spec file if the Bicep file no longer exists.
        Essentially if someone deletes a policy from the repository because it's no longer needed,
        then it will also be removed from Azure.
#>