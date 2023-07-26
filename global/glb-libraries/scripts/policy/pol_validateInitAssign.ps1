[CmdletBinding()]
param(
    # the name of the management group for where the policies reside
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$mgmtGroupName
)



$PSVersionTable
$ErrorActionPreference = "stop"
Update-AzConfig -DisplayBreakingChangeWarning $false

Import-Module "${Env:SYSTEM_DEFAULTWORKINGDIRECTORY}/glb-libraries/scripts/modules/module_install_modules.psm1"
Import-Module "${Env:SYSTEM_DEFAULTWORKINGDIRECTORY}/glb-libraries/scripts/modules/PolicyDeploymentUtilities"
Set-PSModule -Name "Az"
Set-PSModule -Name "Az.ResourceGraph"




$listPolicyDefIds            = @()
$listPolicySetIds            = @()
$listPolicyAssignment        = @()

$policyDef                   = Get-AzPolicyDefinition    -Custom -ManagementGroupName $mgmtGroupName
$policyDefSets               = Get-AzPolicySetDefinition -Custom -ManagementGroupName $mgmtGroupName



# Get policy assignments from mgmt and sub level scopes
[PSObject]$policyAssignments = @()

Write-Output "Adding policy objects for: $(Write-OutputColour Green "/providers/Microsoft.Management/managementGroups/${mgmtGroupName}")"
Get-AzPolicyAssignment -Scope "/providers/Microsoft.Management/managementGroups/${mgmtGroupName}" |
    ForEach-Object {
        Write-Output " └─ $($_.Name)"
        $policyAssignments += $_
    }

$subList = Search-AzGraph `
    -ManagementGroup $mgmtGroupName `
    -Query           "ResourceContainers | where type == 'microsoft.resources/subscriptions'"

foreach($sub in $subList) {
    Write-Output "Adding policy objects for: $(Write-OutputColour Green $sub.name)"
    $thisSubId  = $sub.id.Split("/")[2]

    Set-AzContext -SubscriptionId $thisSubId | Out-Null
    Get-AzPolicyAssignment -Scope "/subscriptions/${thisSubId}" |
        ForEach-Object {
            Write-Output " └─ $($_.Name)"
            $policyAssignments += $_
        }
}




"Current working directory: $((Get-Location).Path)"
Get-ChildItem -Path "." -File


$allBicepFiles = Get-ChildItem `
    -File `
    -Include "*.bicep" `
    -Path "." `
    -Recurse


$tsObj = Get-Content -Path "./tsObj.json" |
    ConvertFrom-Json -Depth 99 -AsHashtable




###
# definitions
###

Write-OutputColour Green "`n`n`nValidating deleted Definintions"
$deleteTs              = @()
$currentAppliedPolDefs = @()


$policyDef |
    Sort-Object -Property "Name" |
        Where-Object {
            $_.Name -match "^p-glb-"
        } |
            ForEach-Object {
                $currentAppliedPolDefs += $_.Name
            }

Write-Output "👇 Definitions deployed to Azure:"
$currentAppliedPolDefs

$currentAppliedPolDefs |
    ForEach-Object {
        $thisPolicy = $_

        if($thisPolicy -notin $tsObj.definitions) {
            Write-OutputColour Red "${thisPolicy}`e[0m - Definintion policy to be deleted"
            $deleteTs += $thisPolicy
        }
    }


if($deleteTs -ge 1) {
    Write-Output "`n👇 Template Specs not linked to Bicep files"
    $deleteTs

    foreach($item in $deleteTs) {
        Write-OutputColour Magenta "`n📄 ${item}"
        Write-OutputColour Yellow " └─ Definition used, policyDefId 🌳 🚜"
        $listPolicyDefIds += $item

        $getPol = ($policyDef |
            Where-Object {
                $_.Name -eq $item
            }).PolicyDefinitionId

        $policyDefSets |
            Where-Object {
                $getPol -in $_.Properties.PolicyDefinitions.policyDefinitionId
            } |
                ForEach-Object {
                    Write-OutputColour Yellow " └─ Initiative used, policySetId 🌳 🚜"
                    $getDefSet         = $_
                    $listPolicySetIds += $getDefSet.Name

                    $policyAssignments |
                        Where-Object {
                            $_.Properties.PolicyDefinitionId -eq $getDefSet.PolicySetDefinitionId
                        } |
                            ForEach-Object {
                                Write-OutputColour Yellow " └─ Initiative assigned, policyAssignment 🌳 🚜"
                                $listPolicyAssignment += $_.Name
                            }
                }
    }
}




###
# initiatives
###

Write-OutputColour Green "`n`n`nValidating deleted Initiatives"
$bicepFiles  = @()
$deleteTs    = @()

$allBicepFiles |
    Where-Object {
        $_.DirectoryName -match "initiatives$"
    } |
        Sort-Object |
            ForEach-Object {
                if (($_.BaseName      -notmatch "^i-") -and `
                    ($_.DirectoryName -notmatch "(?!pr\d|glb)-initiatives")) {
                    $bicepFiles += "i-$($_.BaseName)"
                }
                else {
                    $bicepFiles += $_.BaseName
                }
            }

Write-Output "👇 Initiative files found in repos:"
$bicepFiles


$tsObj.initiatives |
    ForEach-Object {
        $thisTs  = $_

        if($thisTs -notin $bicepFiles) {
            Write-OutputColour Red "${thisTs}`e[0m - Initiative template spec NOT found"
            $deleteTs += $thisTs
        }
    }


if($deleteTs -ge 1) {
    Write-Output "`n👇 Template Specs not linked to Bicep files:"
    $deleteTs

    foreach($item in $deleteTs) {
        Write-OutputColour Magenta "`n📄 ${item}"
        Write-OutputColour Yellow " └─ Initiatve used, policySetId 🌳 🚜"
        $listPolicySetIds += $item

        $getPol = ($policyDefSets |
            Where-Object {
                $_.Name -eq $item
            }).PolicySetDefinitionId

        $policyAssignments |
            Where-Object {
                $_.Properties.PolicyDefinitionId -eq $getPol
            } |
                ForEach-Object {
                    Write-OutputColour Yellow " └─ Initiative assigned, policyAssignment 🌳 🚜"
                    $listPolicyAssignment += $_.Name
                }
    }
}




###
# assignments
###

Write-OutputColour Green "`n`n`nValidating deleted Assignments"
$bicepFiles  = @()
$deleteTs    = @()

$allBicepFiles |
    Where-Object {
        ($_.DirectoryName -match "assignments$") -and `
        ($_.DirectoryName -notmatch "(?!pr\d|glb)-initiatives")
    } |
        Sort-Object |
            ForEach-Object {
                if (($_.BaseName      -notmatch "^a-") -and `
                    ($_.DirectoryName -notmatch "(?!pr\d|glb)-initiatives")) {
                    $bicepFiles += "a-$($_.BaseName)"
                }
                else {
                    $bicepFiles += $_.BaseName
                }
            }

$allJsonFiles = (Get-ChildItem `
    -File `
    -Include "*.json" `
    -Path ${Env:SYSTEM_DEFAULTWORKINGDIRECTORY} `
    -Recurse |
        Where-Object {
            ($_.DirectoryName -match "assignments/${mgmtGroupName}") -and `
            ($_.DirectoryName -match "(?!pr\d|glb)-initiatives") -and `
            ($_.Name -notin "default.json", "params.json")
        }).FullName |
            Sort-Object

    foreach($file in $allJsonFiles) {
        $content     = Get-Content -Path $file | ConvertFrom-Json -Depth 99
        $bicepFiles += "a-$($content.initiativeName)"
    }

Write-Output "👇 Assignment files found in repos:"
$bicepFiles


$tsObj.assignments |
    ForEach-Object {
        $thisTs  = $_

        if($thisTs -eq "a-assignments") {
            Write-OutputColour Yellow "${thisTs}`e[0m - Skipping looping assignment template spec"
        }
        elseif($thisTs -notin $bicepFiles) {
            Write-OutputColour Red "${thisTs}`e[0m - Assignment template spec NOT found"
            $deleteTs += $thisTs
        }
    }


if($deleteTs -ge 1) {
    Write-Output "`n👇 Template Specs not linked to Bicep files"
    $deleteTs

    foreach($item in $deleteTs) {
        Write-OutputColour Magenta "`n📄 ${item}"
        Write-OutputColour Yellow " └─ Assignment used, policyAssignment 🌳 🚜"
        $listPolicyAssignment += $item
    }
}



$listPolicyAssignment = $listPolicyAssignment | Sort-Object -Unique
$listPolicySetIds     = $listPolicySetIds     | Sort-Object -Unique
$listPolicyDefIds     = $listPolicyDefIds     | Sort-Object -Unique



# much easier to create an empty list and validate against it
# instead of repeating the same code over and over
$emptyList = @("", " ", $null)


# create new combined arrays to pass through pipeline
# Env:1 and Env:2 are made up from the comparison task
# which runs before this

$new_POLICY_DEFIDS_LIST     = @()
$new_POLICY_SETIDS_LIST     = @()
$new_POLICY_ASSIGNMENT_LIST = @()



# input first set of variables into arrays
foreach($item in $Env:1_POLICY_DEFIDS_LIST.Split(";")) {
    if( ($item -notin $emptyList) -and `
        ($item -notin $new_POLICY_DEFIDS_LIST)) {
        $new_POLICY_DEFIDS_LIST += $item
    }
}

foreach($item in $Env:1_POLICY_SETIDS_LIST.Split(";")) {
    if( ($item -notin $emptyList) -and `
        ($item -notin $new_POLICY_SETIDS_LIST)) {
        $new_POLICY_SETIDS_LIST += $item
    }
}

foreach($item in $Env:1_POLICY_ASSIGNMENT_LIST.Split(";")) {
    if( ($item -notin $emptyList) -and `
        ($item -notin $new_POLICY_ASSIGNMENT_LIST)) {
        $new_POLICY_ASSIGNMENT_LIST += $item
    }
}



# combine second items
foreach($item in $Env:2_POLICY_SETIDS_LIST.Split(";")) {
    if( ($item -notin $emptyList) -and `
        ($item -notin $new_POLICY_SETIDS_LIST)) {
        $new_POLICY_SETIDS_LIST += $item
    }
}

foreach($item in $Env:2_POLICY_ASSIGNMENT_LIST.Split(";")) {
    if( ($item -notin $emptyList) -and `
        ($item -notin $new_POLICY_ASSIGNMENT_LIST)) {
        $new_POLICY_ASSIGNMENT_LIST += $item
    }
}



# combine deleted bicep/json files
# and create separate variable to delete Template Specs on their own
$new_POLICY_ASSIGNMENT_LIST_TS = @()
$new_POLICY_SETIDS_LIST_TS     = @()
$new_POLICY_DEFIDS_LIST_TS     = @()

foreach($item in $listPolicyDefIds) {
    if( ($item -notin $emptyList) -and `
        ($item -notin $new_POLICY_DEFIDS_LIST)) {
        $new_POLICY_DEFIDS_LIST    += $item
        $new_POLICY_DEFIDS_LIST_TS += $item
    }
}

foreach($item in $listPolicySetIds) {
    if( ($item -notin $emptyList) -and `
        ($item -notin $new_POLICY_SETIDS_LIST)) {
        $new_POLICY_SETIDS_LIST    += $item
        $new_POLICY_SETIDS_LIST_TS += $item
    }
}

foreach($item in $listPolicyAssignment) {
    if( ($item -notin $emptyList) -and `
        ($item -notin $new_POLICY_ASSIGNMENT_LIST)) {
        $new_POLICY_ASSIGNMENT_LIST    += $item
        $new_POLICY_ASSIGNMENT_LIST_TS += $item
    }
}



Get-Variable |
    Where-Object {
        $_.Name -match "^new_"
    } |
        Sort-Object -Property "Name" |
            ForEach-Object {
                $exportName  = $_.Name.Replace("new_", "")
                $exportValue = $_.Value -join ";"

                if($_.Value.Count -ge 1) {
                    Write-Output           "##vso[task.complete result=SucceededWithIssues;updateRequired]"
                    Write-Output           "##vso[task.setvariable variable=${exportName};isOutput=true]${exportValue}"
                    Write-OutputColour Red "`n`n$($exportName.Replace("_", " ")) deletion 🗑️:"
                    $_.Value
                }
                else {
                    Write-Output             "##vso[task.setvariable variable=${exportName};isOutput=true]NONE"
                    Write-OutputColour Green "`n`n$($exportName.Replace("_", " ")) OK!  🎉"
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
        then it will also be removed from Azure in later tasks by using the environment variables
        set within this script.
#>
