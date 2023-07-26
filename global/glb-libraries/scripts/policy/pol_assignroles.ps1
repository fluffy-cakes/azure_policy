[CmdletBinding()]
param(
    # the name of the management group for where the policies reside
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$mgmtGroupName,

    # the environment short name for which the policies run
    # ie; dev, ppd, prd
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$shortEnv
)



$ErrorActionPreference = "Stop"
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




if($Env:BUILD_REPOSITORY_NAME.StartsWith("glb")) {
    $tsRsgAssignments = "uks-${Env:POLICY_TENANT}-glb-assignments-rsg"
}
else {
    $tsRsgAssignments = "uks-${Env:POLICY_TENANT}-${shortEnv}-assignments-rsg"
}


$availableSubscriptions = Get-AzSubscription
$tsList                 = Get-AzTemplateSpec -ResourceGroupName $tsRsgAssignments |
    Where-Object {
        $_.Name -match "^a-\w+"
    } |
        Sort-Object -Property "Name"



function Set-PolicyScopeRoles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [PSObject[]]$roles,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$scope
    )


    # if AzCli is needed:
    # $appId  = (az policy assignment identity show --name $assignmentName --scope $scope | ConvertFrom-Json).principalId

    # else use Pwsh:
    $appId = (Get-AzPolicyAssignment -Name $assignmentName -Scope $scope).Identity.PrincipalId

    Write-Output "Roles:"
    $roles | ConvertTo-Json -Depth 99

    foreach($role in ($roles | Sort-Object -Property "name")) {
        $roleName  = $role.name
        $roleScope = $role.scope

        # if AzCli is needed:
        # $getAssignment = az role assignment list --assignee $appId --role $roleName --scope $roleScope | Convertfrom-Json

        # else use Pwsh:
        $getAssignment = Get-AzRoleAssignment `
            -ObjectId               $appId `
            -RoleDefinitionName     $roleName `
            -Scope                  $roleScope `
            -ErrorAction            "SilentlyContinue"

        if($null -eq $getAssignment) {
            Write-Output " - Assigning.......: $(Write-OutputColour Red $roleName.PadRight(40, " ")) 👉 ${roleScope}"

            # if AzCli is needed:
            # az role assignment create --assignee-object-id $appId --assignee-principal-type 'ServicePrincipal' --role $roleName --scope $roleScope

            # else use Pwsh:
            New-AzRoleAssignment `
                -ObjectId           $appId `
                -RoleDefinitionName $roleName `
                -Scope              $roleScope |
                    Out-Null
        }
        else {
            Write-Output " - Already Assigned: $(Write-OutputColour Green $roleName.PadRight(40, " ")) 👉 ${roleScope}"
        }
    }
}



foreach($ts in $tsList) {
    $deploymentScopeObject = Get-AssignmentDeploymentScope `
        -MgmtGroupName $mgmtGroupName `
        -TsName        $ts.Name


    switch($deploymentScopeObject.type) {
        "subscription" {
            (Get-ChildItem `
                -ErrorAction "stop" `
                -File `
                -Include "$($ts.Name.Replace('a-', '')).json" `
                -Path    "${Env:SYSTEM_DEFAULTWORKINGDIRECTORY}/$($deploymentScopeObject.repo)/params/${eachShortEnv}/" `
                -Recurse |
                    Where-Object {
                        $_.DirectoryName -match "assignments$"
                    }).FullName | # there should only ever be 1 result, unless someone borks up the folder structure
                        ForEach-Object {
                            $initiative     = Get-Content -Path $_ | ConvertFrom-Json -Depth 99 -AsHashtable
                            $assignmentName = "a-$($initiative.p_assignmentParams.initiativeName)"
                            Write-OutputColour Green "`n`nAssignment ${assignmentName}"

                            $availableSubscriptions |
                                Where-Object {
                                    ($_.Name -match "^${shortEnv}")  -and `
                                    ($_.Name -match $deploymentScopeObject.subRegex)
                                } |
                                    ForEach-Object {
                                        Set-AzContext -SubscriptionName $_.Name -Scope "Process" | Out-Null
                                        Write-Output " └─ $($_.Name)"

                                        if($initiative.p_assignmentParams.keys -contains "roles" ) {
                                            Set-PolicyScopeRoles `
                                                -roles $initiative.p_assignmentParams.roles `
                                                -scope "/subscriptions/$($_.Id)"
                                        }
                                        else {
                                            Write-Output "No roles defined"
                                        }
                                    }
                        }
        }


        "mgmtGroup"    {
            foreach($initiative in (Get-Content -Path "./assignments/${mgmtGroupName}/params.json" | ConvertFrom-Json -AsHashtable).p_assignmentParams) {
                $assignmentName = "a-$($initiative.initiativeName)"
                Write-OutputColour Green "`n`nAssignment ${assignmentName}"

                if($initiative.keys -contains "roles" ) {
                    Set-PolicyScopeRoles `
                        -roles $initiative.roles `
                        -scope "/providers/Microsoft.Management/managementgroups/${mgmtGroupName}"}
                else {
                    Write-Output "No roles defined"
                }
            }
        }
    }
}


<#
    .SYNOPSIS
        Applies RBAC permissions for policy assignments mentioned in its parameter object.

    .DESCRIPTION
        Some policy assignments require specific RBAC permissions to function. This script
        will pull those permissions and their scopes mentioned inside the policy parameter
        object and apply it to the management group or subscription.

    .EXAMPLE
        Example parameter object continaining roles:

            {
                "initiativeName": "pr1-mon-root",
                "initiativeParams": {
                        "logAnalyticsWorkspaceId": {
                                "value": "/subscriptions/--SUBID--/resourceGroups/--RSG--/providers/microsoft.operationalinsights/workspaces/--RSG--law-01"
                        },
                        "storageId": {
                                "value": "/subscriptions/--SUBID--/resourceGroups/--RSG--/providers/Microsoft.Storage/storageAccounts/--STG--"
                        }
                    },
                    "roles": [
                    {
                            "name": "Contributor",
                            "scope": "/providers/Microsoft.Management/managementGroups/project1"
                    },
                    {
                            "name": "Security Admin",
                            "scope": "/providers/Microsoft.Management/managementGroups/project1"
                    },
                    {
                            "name": "Monitoring Contributor",
                            "scope": "/providers/Microsoft.Management/managementGroups/project1"
                    },
                    {
                            "name": "Network Contributor",
                            "scope": "/providers/Microsoft.Management/managementGroups/project1"
                    },
                    {
                            "name": "Log Analytics Contributor",
                            "scope": "/providers/Microsoft.Management/managementGroups/project1"
                    },
                    {
                            "name": "Monitoring Contributor",
                            "scope": "/subscriptions/--SUBID--/resourcegroups/--RSG--/providers/microsoft.operationalinsights/workspaces/--RSG--law-01"
                    },
                    {
                            "name": "Log Analytics Contributor",
                            "scope": "/subscriptions/--SUBID--/resourcegroups/--RSG--/providers/microsoft.operationalinsights/workspaces/--RSG--law-01"
                    },
                    {
                            "name": "Storage Account Contributor",
                            "scope": "/subscriptions/--SUBID--/resourcegroups/--RSG--/providers/Microsoft.Storage/storageAccounts/--STG--"
                    }
                ]
            }
#>
