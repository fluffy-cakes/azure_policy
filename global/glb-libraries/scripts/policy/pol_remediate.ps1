[CmdletBinding()]
param (
    # the name of the management group for where the policies reside
    [ValidateNotNullOrEmpty()]
    [string]$mgmtGroupName
)



$PSVersionTable
$ErrorActionPreference = "Stop"
Import-Module "${Env:SYSTEM_DEFAULTWORKINGDIRECTORY}/glb-libraries/scripts/modules/module_install_modules.psm1"
Import-Module "${Env:SYSTEM_DEFAULTWORKINGDIRECTORY}/glb-libraries/scripts/modules/PolicyDeploymentUtilities"
Set-PSModule "Az.ResourceGraph"



(Search-AzGraph -ManagementGroup $mgmtGroupName -Query "ResourceContainers | where type == 'microsoft.resources/subscriptions'").id |
    ForEach-Object {
        if((Get-AzSubscription -SubscriptionId $_.Split("/")[2]).State -ne "Enabled") {
            continue
        }
        else {
            Set-AzContext -Subscription $_.Split("/")[2] -Verbose
        }


        $nonCompliantPolicies = Get-AzPolicyState |
            Where-Object {
                ($_.ComplianceState        -eq "NonCompliant") -and `
                ($_.PolicyDefinitionAction -eq "deployIfNotExists")
            }


        if($nonCompliantPolicies) {
            Write-OutputColour Green "Policies found for remediation"

            foreach($policy in $nonCompliantPolicies) {
                try {
                    Start-AzPolicyRemediation `
                        -Name                        "rem.$($policy.PolicyDefinitionName)" `
                        -PolicyAssignmentId          $policy.PolicyAssignmentId `
                        -PolicyDefinitionReferenceId $policy.PolicyDefinitionReferenceId `
                        -Verbose
                }
                catch {
                    Write-Host "`n##[Warning]`tPolicy remediation may already taking place:"
                    $_
                }
            }
        }
        else {
            Write-OutputColour Red "No policies found that requires remediation`n`n`n`n"
        }
    }


<#
    .SYNOPSIS
        Remediate any oustanding policies.

    .DESCRIPTION
        A policy may not be able to rectify existing non-compliant resources in Azure.
        This script will run after new policy deployments to rectify any out of scope
        resources.
#>
