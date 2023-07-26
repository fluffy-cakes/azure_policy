function Get-TsRsg {
    [CmdletBinding()]
    param(
        # Current build repository running this pipeline
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$BuildRepoName,

        # Current directory where the bicep files are
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$CurrentDirectory,

        # Management group short name environment
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$Environment,

        # Current short name tenant
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Tenant
    )



    switch -Regex ($BuildRepoName) {
        "^pr" {
            switch($Environment) {
                # this would have more environments under the same tenant for different testing purposes
                # such as:
                # "asd" { $tsRsg = "uks-${Tenant}-tst-${CurrentDirectory}-rsg" }
                # "qwe" { $tsRsg = "uks-${Tenant}-tst-${CurrentDirectory}-rsg" }
                # "zxc" { $tsRsg = "uks-${Tenant}-tst-${CurrentDirectory}-rsg" }

                "tst" { $tsRsg = "uks-${Tenant}-tst-${CurrentDirectory}-rsg" }
                "ppd" { $tsRsg = "uks-${Tenant}-ppd-${CurrentDirectory}-rsg" }
                "prd" { $tsRsg = "uks-${Tenant}-prd-${CurrentDirectory}-rsg" }
            }
        }

        "^glb" {
            $tsRsg = "uks-${Tenant}-glb-${CurrentDirectory}-rsg"
        }
    }

    return $tsRsg
}


<#
    .SYNOPSIS
        A small function to determine the resource group for where Template Spec policies reside.

    .DESCRIPTION
        Template Specs resource groups do not have a consistent naming convention as the rest of
        Azure, thus this lookup table retuns the appropriate resource group name based on input
        values.
#>
