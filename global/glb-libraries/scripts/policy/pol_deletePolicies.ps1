[CmdletBinding()]
param (
    # the name of the management group for where the policies reside
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$mgmtGroupName,

    # the policy scope type for which this script runs under
    # ie; definition, initiative or assignment
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$scope
)



$PSVersionTable
$ErrorActionPreference = "Stop"
Import-Module "${Env:SYSTEM_DEFAULTWORKINGDIRECTORY}/glb-libraries/scripts/modules/PolicyDeploymentUtilities"



# much easier to create an empty list and validate against it
# instead of repeating the same code over and over
$emptyList = @("", " ", $null)



switch($scope) {
    "assignments"{
        # we don't want this inside the loop, it's in efficient to run the same things multiple times for the same results
        $availableSubscriptions = Get-AzSubscription

        $Env:POLICY_ASSIGNMENT_LIST.Split(";") |
            ForEach-Object {
                if($_ -in $emptyList) { continue }

                $thisName              = $_
                $deploymentScopeObject = Get-AssignmentDeploymentScope -MgmtGroupName $mgmtGroupName -TsName $thisName

                switch($deploymentScopeObject.type) {
                    "subscription" {
                        $availableSubscriptions |
                            Where-Object {
                                $_.Name -match $deploymentScopeObject.subRegex
                            } |
                                ForEach-Object {
                                    $thisSubId = $_.Id
                                    Set-AzContext -SubscriptionId $thisSubId | Out-Null

                                    Get-AzPolicyAssignment -Scope "/subscriptions/${thisSubId}" |
                                        Where-Object {
                                            $_.Name -eq $thisName
                                        } |
                                            ForEach-Object {
                                                Write-Output "💥 $(Write-OutputColour Red $thisName.PadRight(20, " ")) 👉 /subscriptions/${thisSubId}"
                                                $_ | Remove-AzPolicyAssignment -Verbose
                                                "##vso[task.complete result=SucceededWithIssues;deleted]"
                                            }
                                }
                    }
                    "mgmtGroup"    {
                        Get-AzPolicyAssignment -Scope "/providers/Microsoft.Management/managementgroups/${mgmtGroupName}" |
                            Where-Object {
                                $_.Name -eq $thisName
                            } |
                                ForEach-Object {
                                    Write-Output "💥 $(Write-OutputColour Red $thisName.PadRight(20, " ")) 👉 ${mgmtGroupName}"
                                    $_ | Remove-AzPolicyAssignment -Verbose
                                    "##vso[task.complete result=SucceededWithIssues;deleted]"
                                }
                    }
                }
            }
    }


    "initiatives"{
        $Env:POLICY_SETIDS_LIST.Split(";") |
            ForEach-Object {
                if($_ -in $emptyList) { continue }

                $thisName = $_
                Get-AzPolicySetDefinition -Custom -ManagementGroupName $mgmtGroupName |
                    Where-Object {
                        $_.Name -eq $thisName
                    } |
                        ForEach-Object {
                            Write-Output "💥 $(Write-OutputColour Red $thisName.PadRight(20, " ")) 👉 ${mgmtGroupName}"
                            $_ | Remove-AzPolicySetDefinition -Force -Verbose
                            "##vso[task.complete result=SucceededWithIssues;deleted]"
                        }
            }
    }


    "definitions"{
        $Env:POLICY_DEFIDS_LIST.Split(";") |
            ForEach-Object {
                if($_ -in $emptyList) { continue }

                $thisName = $_
                Get-AzPolicyDefinition -Custom -ManagementGroupName $mgmtGroupName |
                    Where-Object {
                        $_.Name -eq $thisName
                    } |
                        ForEach-Object {
                            Write-Output "💥 $(Write-OutputColour Red $thisName.PadRight(20, " ")) 👉 ${mgmtGroupName}"
                            $_ | Remove-AzPolicyDefinition -Force -Verbose
                            "##vso[task.complete result=SucceededWithIssues;deleted]"
                        }
            }
    }
}


<#
    .SYNOPSIS
        A simple script to delete policies from either management group or subscription level.

    .DESCRIPTION
        By using environment variables set in previous pipeline tasks, this script is able to
        loop through any policies that require deleting from either definitions, intiatives
        or assignments. By using a custom PowerShell module, we are able to determine the
        deployment scope for assignments and switch between which PowerShell function can
        remove the assignment from Azure.
#>
