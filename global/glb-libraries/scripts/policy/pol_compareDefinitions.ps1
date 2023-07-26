[CmdletBinding()]
param(
    # the name of the management group for where the policies reside
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$mgmtGroupName
)


$ErrorActionPreference = "Stop"
Import-Module "${Env:SYSTEM_DEFAULTWORKINGDIRECTORY}/glb-libraries/scripts/modules/PolicyDeploymentUtilities"



$policyDefIds     = @()
$policySetIds     = @()
$policyAssignment = @()



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



# we don't want these inside the loop, it's in efficient to run the same things multiple times for the same results
$availableSubscriptions      = Get-AzSubscription
$policyDef                   = Get-AzPolicyDefinition    -Custom -ManagementGroupName $mgmtGroupName
$policyDefSets               = Get-AzPolicySetDefinition -Custom -ManagementGroupName $mgmtGroupName
$policyAssignments_mgmtGroup = Get-AzPolicyAssignment    -Scope "/providers/Microsoft.Management/managementGroups/${mgmtGroupName}"



$tsRsg = (Get-AzResourceGroup |
    Where-Object {
        $_.ResourceGroupName -match "^uks-\w{3}-glb-definitions-rsg$"
}).ResourceGroupName

Write-Output "`n`n##[debug]🐞`tSetting Resource Group to: ${tsRsg}"
$allTs = (Get-AzTemplateSpec -ResourceGroupName $tsRsg).Name | Sort-Object
$allTs



foreach($item in $allTs){
    Write-OutputColour Magenta "`n`n📄 ${item}"
    $thisTemplateSpec        = Get-AzTemplateSpec -Name $item -ResourceGroupName $tsRsg
    $templateSpecs           = $thisTemplateSpec.Versions.name.ForEach({[version]$_}) | Sort-Object
    [string]$latestTsVersion = $templateSpecs[-1]


    $templateSpec = (Get-AzTemplateSpec `
        -Name              $item `
        -ResourceGroupName $tsRsg `
        -Version           $latestTsVersion).Versions.MainTemplate |
            ConvertFrom-Json -AsHashtable

    $getPol = $policyDef |
        Where-Object {
            $_.Name -eq $item
        }


    if($getPol) {
        Write-Output " └─ Scope: $($deploymentScopeObject.type)"

        [version]$policyDefVer = $getPol.Properties.Metadata.version
        $defId                 = $getPol.PolicyDefinitionId

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

                Compare-TheseParams -Scope "Definition Parameters" `
                    -ObjNew      $templateSpec.resources.properties.parameters `
                    -ObjExisting ($getPol.Properties.Parameters | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100) # this is a bit hacky just to turn it into a hashtable, really need to think of a better way

                if($Global:paramChanged) {
                    Write-Output "##vso[task.complete result=SucceededWithIssues;updateRequired]"
                    Write-OutputColour Yellow " └─ Parameters differ, policyDefId 🌳 🚜"
                    $policyDefIds += $getPol.Name

                    $getDefSet = $policyDefSets |
                        Where-Object {
                            $defId -in $_.Properties.PolicyDefinitions.policyDefinitionId
                        }

                    if($getDefSet) {
                        Write-OutputColour Yellow " └─ Initiative used, policySetId 🌳 🚜"
                        $policySetIds += $getDefSet.Name


                        # find out which scope the initiative is at so we can remove the assignment it's deployed to
                        $deploymentScopeObject = Get-AssignmentDeploymentScope -MgmtGroupName $mgmtGroupName -TsName $getDefSet.Name

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
                                $_.Properties.PolicyDefinitionId -eq $getDefSet.PolicySetDefinitionId
                            } |
                                ForEach-Object {
                                    Write-OutputColour Yellow " └─ Initiative assgned, policyAssignment 🌳 🚜"
                                    $policyAssignment += $_.Name
                                }
                    }
                }
                else {
                    Write-Output " └─ Definition can be updated in place  ☑️"
                }
            }
            else {
                Write-Output " └─ Definition can be updated in place  ☑️"
            }
        }
        else {
            Write-Output " └─ Definition can be updated in place  ☑️"
        }
    }
    else {
        Write-Output " └─ Definition not in portal  🌱"
    }
}



Write-Output "`n`n"
$policyAssignment = $policyAssignment | Sort-Object -Unique
$policySetIds     = $policySetIds     | Sort-Object -Unique
$policyDefIds     = $policyDefIds     | Sort-Object -Unique


Write-Output "##vso[task.setvariable variable=1_policy_Assignment_List]$($policyAssignment -join ";")"
foreach ($assignment in $policyAssignment){
    Write-Output "🗑️ ${assignment}"
}


Write-Output "##vso[task.setvariable variable=1_policy_SetIds_List]$($policySetIds -join ";")"
foreach ($defSetId in $policySetIds){
    Write-Output "🗑️ ${defSetId}"
}


Write-Output "##vso[task.setvariable variable=1_policy_DefIds_List]$($policyDefIds -join ";")"
foreach ($defId in $policyDefIds){
    Write-Output "🗑️ ${defId}"
}


<#
    .SYNOPSIS
        The ability to compare definitions that been deployed to Azure with ones that currently
        reside in a repository to identify if definitions, initiatives or assignments need to be
        removed before being applied.

    .DESCRIPTION
        In order to minimise the downtime for any policy definitions, initiatives or assignments
        not applied in Azure, this script will identify that when a policy definition is updated
        whether or not any initiatives or assignments depend upon it, and if the definition can
        be updated in place, or not.

        It seems that once an input parameter is changed in anyway for a changed/updated definition
        that it will require it's dependant initiatives and assignments to be removed first before
        being updated. However, if only the content inside the definition is updated, then the
        policy can be updated in place without having to remove its dependants.

        This script will identify those that need to be removed and export their values to a
        variable for later use in the pipeline.
#>
