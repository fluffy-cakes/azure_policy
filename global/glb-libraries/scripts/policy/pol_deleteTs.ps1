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



Write-Output "buildRepositoryName   : ${buildRepositoryName}"
Write-Output "Env:POLICY_ENVIRONMENT: ${Env:POLICY_ENVIRONMENT}"
Write-Output "Env:POLICY_TENANT     : ${Env:POLICY_TENANT}"



$thisRsgIni = Get-TsRsg `
    -BuildRepoName    $buildRepositoryName `
    -CurrentDirectory "initiatives" `
    -Environment      $Env:POLICY_ENVIRONMENT `
    -Tenant           $Env:POLICY_TENANT

$thisRsgAss = Get-TsRsg `
    -BuildRepoName    $buildRepositoryName `
    -CurrentDirectory "assignments" `
    -Environment      $Env:POLICY_ENVIRONMENT `
    -Tenant           $Env:POLICY_TENANT



Write-Output "thisRsgIni            : ${thisRsgIni}"
Write-Output "thisRsgAss            : ${thisRsgAss}"

# much easier to create an empty list and validate against it
# instead of repeating the same code over and over
$emptyList = @("", " ", $null)


# TODO - missing definition deletion, likely this should be done manually by a Cyber team to ensure no funny business?


foreach($initiative in $Env:POLICY_SETIDS_LIST_TS.Split(";")) {
    if($initiative -in $emptyList) { continue }
    if($initiative -ne "NONE") {
        Write-Output "`nDeleting ${thisRsgIni}/$(Write-OutputColour Red "${initiative}")  💥"

        Get-AzTemplateSpec `
            -Name              $initiative `
            -ResourceGroupName $thisRsgIni `
            -ErrorAction       "SilentlyContinue" |
                ForEach-Object {
                    $_ | Remove-AzTemplateSpec -Force -Verbose
                    "##vso[task.complete result=SucceededWithIssues;deleted]"
                }
    }
    else {
        Write-OutputColour Green "`n`nNo Initiative to delete!  🎉"
    }
}


foreach($assignment in $Env:POLICY_ASSIGNMENT_LIST_TS.Split(";")) {
    if($assignment -in $emptyList) { continue }
    if($assignment -ne "NONE") {
        Write-Output "`nDeleting ${thisRsgAss}/$(Write-OutputColour Red "${assignment}")  💥"

        Get-AzTemplateSpec `
            -Name              $assignment `
            -ResourceGroupName $thisRsgAss `
            -ErrorAction       "SilentlyContinue" |
            ForEach-Object {
                $_ | Remove-AzTemplateSpec -Force -Verbose
                "##vso[task.complete result=SucceededWithIssues;deleted]"
            }
    }
    else {
        Write-OutputColour Green "`n`nNo Assignment to delete!  🎉"
    }
}


<#
    .SYNOPSIS
        Delete policy Template Specs which are no longer required.

    .DESCRIPTION
        Once a policy Bicep file has been deleted from the repo, it also needs to be
        deleted from Azure Template Spec resource group. This script uses environment
        variables created in past tasks to determine which policies no longer exist
        and delete their counterpart Template Spec file.
#>
