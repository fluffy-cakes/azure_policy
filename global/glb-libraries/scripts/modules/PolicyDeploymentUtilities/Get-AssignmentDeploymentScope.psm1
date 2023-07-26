function Get-AssignmentDeploymentScope {
    [CmdletBinding()]
    param(
        # the name of the management group for where the policies reside
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$MgmtGroupName,

        # the Template Spec name for which to match in the regex patterns
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$TsName
    )

    switch -Regex ($TsName) {
        # PR1
        "^[ai]-hubPlatform$"    { $deploymentRegex = "^\w{3}-pr1-hub-\d{2}$"; $deploymentRepository = "pr1-platform"; $deploymentType = "subscription" }

        # GLB
        "^[ai]-sharedServices$" { $deploymentRegex = "^\w{3}-glb-ssv-mgmt$";  $deploymentRepository = "glb-shared";   $deploymentType = "subscription" }

        default {
            $deploymentRegex = "na"
            $deploymentType  = "mgmtGroup"

            switch -Regex ($MgmtGroupName) {
                "^[Pp]roject1" { $deploymentRepository = "pr1-initiatives" }
                "^[Pp]roject2" { $deploymentRepository = "pr2-initiatives" }
                "^[Pp]roject3" { $deploymentRepository = "pr3-initiatives" }
                default        { $deploymentRepository = "glb-initiatives" }
            }
        }
    }

    return [PSObject]@{
        "repo"     = $deploymentRepository
        "subRegex" = $deploymentRegex
        "type"     = $deploymentType
    }
}


<#
    .SYNOPSIS
        A lookup table to identify the assignment scope of a policy initiative/assignment.

    .DESCRIPTION
        Some policy initiatives and assignments are scoped to a subscription level instead
        of management group. In order to determine the correct scoping, this lookup table
        is used along with regex to return an object with information on where/how that
        policy is applied.

        The "deploymentRegex" will be used to search for subscriptions that match the
        its regex pattern, which will then be used for assignment. If no pattern ("na") is
        returned, it will be deployed at management group level.
#>
