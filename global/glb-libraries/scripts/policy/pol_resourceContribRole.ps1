[CmdletBinding()]
param (
    # the name of the management group for where the policies reside
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$mgmtGroupName,

    # which function to perform for role assignments
    [Parameter(Mandatory=$true)]
    [ValidateSet('apply', 'remove')]
    [ValidateNotNullOrEmpty()]
    [string]$assignType
)



$PSVersionTable
$ErrorActionPreference = "Stop"
Import-Module "${Env:SYSTEM_DEFAULTWORKINGDIRECTORY}/glb-libraries/scripts/modules/PolicyDeploymentUtilities"



$checkRole = Get-AzRoleAssignment `
    -ObjectId            $Env:COMMON_SVCCONNECTIONUAAOBJID `
    -RoleDefinitionName "Resource Policy Contributor" `
    -Scope              "/providers/Microsoft.Management/managementGroups/${mgmtGroupName}"


switch($assignType) {
    "apply"  {
        if(-not $checkRole) {
            Write-OutputColour Green "`n`nApplying role assignment for principal `"${Env:COMMON_SVCCONNECTIONUAA}`""

            New-AzRoleAssignment `
                -ObjectId           $Env:COMMON_SVCCONNECTIONUAAOBJID `
                -RoleDefinitionName "Resource Policy Contributor" `
                -Scope              "/providers/Microsoft.Management/managementGroups/${mgmtGroupName}" `
                -Verbose
        }
        else {
            Write-OutputColour Red "`n`nRole assignment already applied for principal `"${Env:COMMON_SVCCONNECTIONUAA}`""
        }
    }
    "remove" {
        if($checkRole) {
            Write-OutputColour Red "`n`nRemoving role assignment for principal `"${Env:COMMON_SVCCONNECTIONUAA}`""

            Remove-AzRoleAssignment `
                -ObjectId           $Env:COMMON_SVCCONNECTIONUAAOBJID `
                -RoleDefinitionName "Resource Policy Contributor" `
                -Scope              "/providers/Microsoft.Management/managementGroups/${mgmtGroupName}" `
                -Verbose
        }
        else {
            Write-OutputColour Yellow "`n`nRole assignment already removed for principal `"${Env:COMMON_SVCCONNECTIONUAA}`""
        }
    }
}


<#
    .SYNOPSIS
        Update the policy service principal permisions to allow for remediation to take place.

    .DESCRIPTION
        The service principal used does not have Resource Policy Contributor assigne to it by default.
        This script will temporarily assign and remove the role in order for the following
        remediation task to take place.
#>
