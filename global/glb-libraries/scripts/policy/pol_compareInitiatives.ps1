[CmdletBinding()]
param(
    # the name of the management group for where the policies reside
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$mgmtGroupName
)


$ErrorActionPreference = "Stop"
Import-Module "${Env:SYSTEM_DEFAULTWORKINGDIRECTORY}/glb-libraries/scripts/modules/PolicyDeploymentUtilities"



$policySetIds      = @()
$policyAssignment  = @()



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



# we don't want these inside the loop, it's in efficient to run the same things multiple times for the same results
$availableSubscriptions      = Get-AzSubscription
$policyDefSets               = Get-AzPolicySetDefinition -Custom -ManagementGroupName $mgmtGroupName
$policyAssignments_mgmtGroup = Get-AzPolicyAssignment    -Scope "/providers/Microsoft.Management/managementGroups/${mgmtGroupName}"



if($Env:BUILD_REPOSITORY_NAME.StartsWith("glb")) {
    $rsgName = "^uks-\w{3}-glb-initiatives-rsg$"
}
else {
    $rsgName = "^uks-\w{3}-${Env:POLICY_ENVIRONMENT}-initiatives-rsg$"
}



$tsRsg = (Get-AzResourceGroup |
    Where-Object {
        $_.ResourceGroupName -match $rsgName
}).ResourceGroupName

Write-Output "`n`n##[debug]🐞`tSetting Resource Group to: ${tsRsg}"
$allTs = (Get-AzTemplateSpec -ResourceGroupName $tsRsg).Name |
    Where-Object {
        $_ -match "^i-"
    } | Sort-Object
$allTs



foreach($item in $allTs){
    Write-OutputColour Magenta "`n`n`n📄 ${item}"
    $thisTempalteSpec        = Get-AzTemplateSpec -Name $item -ResourceGroupName $tsRsg
    $templateSpecs           = $thisTempalteSpec.Versions.name.ForEach({[version]$_}) | Sort-Object
    [string]$latestTsVersion = $templateSpecs[-1]


    $templateSpec = (Get-AzTemplateSpec `
        -Name              $item `
        -ResourceGroupName $tsRsg `
        -Version           $latestTsVersion).Versions.MainTemplate |
            ConvertFrom-Json -AsHashtable

    $getPol = $policyDefSets |
        Where-Object {
            $_.Name -eq $item
        }


    if($getPol){
        Write-Output " └─ Scope: $($deploymentScopeObject.type)"

        [version]$policyDefVer = $getPol.Properties.Metadata.version
        $defId                 = $getPol.PolicySetDefinitionId

        if($latestTsVersion -gt $policyDefVer) {
            Write-OutputColour Yellow " └─ v${latestTsVersion} > portal v$([string]${policyDefVer})"
            $verGreater = $true
        }

        # we need to cater for development, and don't want to keep bumping versions to test them out
        # so let's check if any params have changed, regardless of version bump

        if(($verGreater) -or ($templateSpec.resources.properties.parameters.Count -ne 0)) {
            if($templateSpec.resources.properties.parameters.Count -ne 0) {
                Write-Output " └─ Comparing parameters  👀"
                $Global:paramChanged = $false

                Compare-TheseParams -Scope "Defintion Parameters" `
                    -ObjNew      $templateSpec.resources.properties.parameters `
                    -ObjExisting ($getPol.Properties.Parameters | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100) # this is a bit hacky just to turn it into a hashtable, really need to think of a better way

                if($Global:paramChanged) {
                    Write-Output "##vso[task.complete result=SucceededWithIssues;updateRequired]"
                    Write-OutputColour Yellow " └─ Parameters differ, policySetId 🌳 🚜"
                    $policySetIds += $getPol.Name


                    # find out which scope the initiative is at so we can remove the assignment it's deployed to
                    $deploymentScopeObject = Get-AssignmentDeploymentScope -MgmtGroupName $mgmtGroupName -TsName $item

                    switch($deploymentScopeObject.type) {
                        "susbscription" {
                            [PSObject]$subscription_policyAssignments = @()

                            $availableSubscriptions |
                                Where-Object {
                                    $_.Name -match $deploymentScopeObject.subRegex
                                } |
                                    ForEach-Object {
                                        $thisSubId  = $_.SubscriptionId
                                        Set-AzContext -SubscriptionId $thisSubId
                                        (Get-AzPolicyAssignment -Scope "/subscriptions/${thisSubId}").ForEach({$subscription_policyAssignments += $_})
                                    }

                            $policyAssignments = $subscription_policyAssignments | Sort-Object -Property "Name" -Unique
                        }

                        "mgmtGroup"     {
                            $policyAssignments = $policyAssignments_mgmtGroup
                        }
                    }


                    $policyAssignments |
                        Where-Object {
                            $_.Properties.PolicyDefinitionId -eq $defId
                        } |
                            ForEach-Object {
                                Write-OutputColour Yellow " └─ Initiative assgned, policyAssignment 🌳 🚜"
                                $policyAssignment += $_.Name
                            }
                }
            }
            else {
                Write-Output " └─ Initiative can be updated in place  ☑️"
            }
        }
        else {
            Write-Output " └─ Initiative can be updated in place  ☑️"
        }
    }
    else {
        Write-Output " └─ Initiative not in portal  🌱"
    }
}



Write-Output "`n`n"
$policyAssignment = $policyAssignment | Sort-Object -Unique
$policySetIds     = $policySetIds     | Sort-Object -Unique


Write-Output "##vso[task.setvariable variable=2_policy_Assignment_List]$($policyAssignment -join ";")"
foreach ($assignment in $policyAssignment){
    Write-Output "🗑️ ${assignment}"
}


Write-Output "##vso[task.setvariable variable=2_policy_SetIds_List]$($policySetIds -join ";")"
foreach ($defSetId in $policySetIds){
    Write-Output "🗑️ ${defSetId}"
}


<#
    .SYNOPSIS
        The ability to compare initiatives that been deployed to Azure with ones that currently
        reside in a repository to identify if any assignments need to be removed before being applied.

    .DESCRIPTION
        In order to minimise the downtime for any policy initiatives or assignments which are
        not applied in Azure, this script will identify that when a policy initiative is updated
        whether or not any assignments depend upon it, and if the initiative can be updated in
        place, or not.

        It seems that once an input parameter is changed in anyway for a changed/updated initiative
        that it will require it's dependant assignments to be removed first before
        being updated. However, if only the content inside the initiative is updated, then the
        policy can be updated in place without having to remove its dependants.

        This script will identify those that need to be removed and export their values to a
        variable for later use in the pipeline.
#>
