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


$PSVersionTable
$ErrorActionPreference = "Stop"
Import-Module "${Env:SYSTEM_DEFAULTWORKINGDIRECTORY}/glb-libraries/scripts/modules/module_install_modules.psm1"
Import-Module "${Env:SYSTEM_DEFAULTWORKINGDIRECTORY}/glb-libraries/scripts/modules/PolicyDeploymentUtilities"
Set-PSModule -Name "Az"



$ssvTsSub = Get-AzSubscription |
    Where-Object {
        $_.Name -match "\w{3}-glb-ssv-ts"
    }

Write-Output "`n`n##[debug]🐞`tSetting to subscription: $($ssvTsSub.Name)"
Set-AzContext -SubscriptionId $ssvTsSub.Id -Scope "CurrentUser" -Force
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



# we need to export each subscription context for use inside parallelism
# if we don't do this and we switch the default context, it switches it
# for all processes and causes some randome issues

Get-AzContext -ListAvailable |
    ForEach-Object {
        Rename-AzContext -TargetName $_.Subscription.Name -InputObject $_ -Scope "CurrentUser" -Force
    }

Write-OutputColour Green "`nAvailable Azure contexts:"
(Get-AzContext -ListAvailable).Name |
    Sort-Object |
        ForEach-Object {
            Write-Output " - $($_)"
        }




function Set-ThesePolicies {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [array]$oldDeployments,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$policyType,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [array]$tsList,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$thisMgmtGroupName
    )



    Write-OutputColour Cyan "`n`n#".PadRight(55, "#")
    Write-OutputColour Cyan "📂 ${templateSpecRsg} : ${policyType} @ $($tsList.Count) 👇"

    if(Test-Path -Path "./${policyType}/${thisMgmtGroupName}") {
        Write-Output "`nFiles found in ./${policyType}/${thisMgmtGroupName}/*.*"
        (Get-ChildItem -Path "./${policyType}/${thisMgmtGroupName}/").FullName |
            Sort-Object |
                ForEach-Object {
                    Write-Output " - $($_)"
                }
    }

    $availableSubscriptions = Get-AzSubscription


    # Bring custom functions in by turning them into strings, and then "using" them inside ForEach
    $funcDefGetAssignmentDeploymentScope = ${function:Get-AssignmentDeploymentScope}.ToString()
    $funcDefWriteOutputColour            = ${function:Write-OutputColour}.ToString()


    $tsList |
        ForEach-Object -Parallel {
            # Parallel jobs do not have access to script or global variables by default
            # "$Using:" pulls these variables in so they can be used in their own thread

            ${function:Get-AssignmentDeploymentScope} = $Using:funcDefGetAssignmentDeploymentScope
            ${function:Write-OutputColour}            = $Using:funcDefWriteOutputColour
            $eachAvailableSubscriptions               = $Using:availableSubscriptions
            $eachMgmtGroupName                        = $Using:thisMgmtGroupName
            $eachOldDeployments                       = $Using:oldDeployments
            $eachShortEnv                             = $Using:shortEnv
            $eachTsName                               = $_.Name
            $eachTsRsg                                = $_.ResourceGroupName

            $eachSsvSubName = ($eachAvailableSubscriptions |
                Where-Object {
                    $_.Name -match "\w{3}-glb-ssv-ts"
                }).Name


            try{
                $deploymentScopeObject = Get-AssignmentDeploymentScope `
                    -MgmtGroupName $eachMgmtGroupName `
                    -TsName        $eachTsName


                ###
                # Clear out old successful deployments
                ###

                switch($deploymentScopeObject.type) {
                    "subscription" {
                        $eachAvailableSubscriptions |
                            Where-Object {
                                ($_.Name -match "^${eachShortEnv}")  -and `
                                ($_.Name -match $deploymentScopeObject.subRegex)
                            } |
                                ForEach-Object {
                                    $context = Get-AzContext -Name $_.Name

                                    Get-AzDeployment -DefaultProfile $context |
                                        Where-Object {
                                            ($_.ProvisioningState -eq    "Succeeded") -and `
                                            ($_.DeploymentName    -match "^${eachTsName}_\d+$")
                                        } |
                                            ForEach-Object {
                                                $_ | Remove-AzDeployment -DefaultProfile $context
                                            }
                                }
                    }

                    "mgmtGroup" {
                        $eachOldDeployments |
                            Where-Object {
                                ( $_.ProvisioningState -eq    "Succeeded"           ) -and `
                                ( $_.DeploymentName    -match "^${eachTsName}_\d+$" )
                            } |
                                ForEach-Object {
                                    $_ | Remove-AzManagementGroupDeployment
                                }
                    }
                }



                ###
                # Retrieve template spec
                ###
                Get-AzSubscription -SubscriptionName $eachSsvSubName |
                    Set-AzContext -Scope "Process" |
                        Out-Null

                $loopTs = Get-AzTemplateSpec `
                -Name              $eachTsName `
                -ResourceGroupName $eachTsRsg

                [string]$latestVer = ($loopTs.Versions.Name.ForEach({[version]$_}) | Sort-Object)[-1]
                $deployTs          = Get-AzTemplateSpec `
                    -Name              $eachTsName `
                    -ResourceGroupName $eachTsRsg `
                    -Version           $latestVer


                switch -Regex ($eachTsName) {
                    "^a-" {
                        switch($deploymentScopeObject.type) {
                            "subscription" { $command = "New-AzDeployment               "; $scope = $deploymentScopeObject.subRegex }
                            "mgmtGroup"    { $command = "New-AzManagementGroupDeployment"; $scope = $eachMgmtGroupName              }
                        }
                    }
                    default {
                        $command = "New-AzManagementGroupDeployment"
                        $scope   = $eachMgmtGroupName
                    }
                }

                Write-OutputColour Green "`n📃 $(Get-Date -Format "HH:mm") - ${command} - $(Write-OutputColour Red $scope) 👉 $($deployTs.Name.PadRight(60, ".")) $(Write-OutputColour Red "v${latestVer}")"



                ###
                # Smashing parameters together
                ###

                # Not all policy files have parameters, so we preset the parameter
                # object to nothing in case none are found
                $params = [PSObject]@{}

                if($eachTsName -match "^a-") {
                    switch($deploymentScopeObject.type) {
                        "subscription" {
                            (Get-ChildItem `
                                -ErrorAction "stop" `
                                -File `
                                -Include "$($eachTsName.Replace('a-', '')).json" `
                                -Path    "${Env:SYSTEM_DEFAULTWORKINGDIRECTORY}/$($deploymentScopeObject.repo)/params/${eachShortEnv}/" `
                                -Recurse |
                                    Where-Object {
                                        $_.DirectoryName -match "assignments$"
                                    }).FullName | # there should only ever be 1 result, unless someone borks up the folder structure
                                        ForEach-Object {
                                            Write-OutputColour Green "`t└─ Assignment parameters:`e[0m $($_)"
                                            $params = Get-Content -Path $_ | ConvertFrom-Json -Depth 99 -AsHashtable
                                        }
                        }
                        "mgmtGroup" {
                            if(Test-Path -Path "./assignments/${eachMgmtGroupName}/*.json") {
                                # mgmt group assignments use a list to iterate over to assign the policy
                                # each parameter JSON file will be added to the main parameter file for the assignment to loop over
                                # thus we create 1x parameter object "p_assignmentParams" and give it the value of the assignment parameter array
                                $customParam = @()

                                if(Test-Path -Path "./assignments/${eachMgmtGroupName}/default.json") {
                                    $defaultObject = Get-Content -Path "./assignments/${eachMgmtGroupName}/default.json" |
                                        ConvertFrom-Json -AsHashtable -Depth 99
                                }

                                foreach($paramFile in (Get-ChildItem -File "./assignments/${eachMgmtGroupName}/*.json" -Exclude "*default.json" ).Name) {
                                    $customObject = Get-Content -Path "./assignments/${eachMgmtGroupName}/${paramFile}" |
                                        ConvertFrom-Json -AsHashtable -Depth 99

                                    if($defaultObject) {
                                        foreach($p in $defaultObject.Keys) {
                                            if(-not ($customObject.ContainsKey($p))) {
                                                $customObject.Add($p, $defaultObject[$p])
                                            }
                                        }
                                    }

                                    $customParam += $customObject
                                }
                                $params.Add("p_assignmentParams", $customParam)
                                $params |
                                    ConvertTo-Json -Depth 99 |
                                        Out-File -File "./assignments/${eachMgmtGroupName}/params.json" -Verbose

                                Write-OutputColour Green "`t└─ Assignments parameters:`e[0m ./assignments/${eachMgmtGroupName}/params.json"
                            }
                        }
                    }
                }

                if($params.count -eq 0){
                    Write-OutputColour Red "`t└─ No parameters"
                }
                else {
                    $params | ConvertTo-Json -Depth 99
                }




                ###
                # Deploy the policy
                ###

                $deployParams                 = @{
                    "Location"                = "uksouth"
                    "Name"                    = "${eachTsName}_${Env:BUILD_BUILDID}"
                    "TemplateParameterObject" = $params
                    "TemplateSpecId"          = $deployTs.Versions.Id
                }

                switch -Regex ($eachTsName) {
                    "^a-"   {
                        switch($deploymentScopeObject.type) {
                            "subscription" {
                                $eachAvailableSubscriptions |
                                    Where-Object {
                                        ($_.Name -match "^${eachShortEnv}")  -and `
                                        ($_.Name -match $deploymentScopeObject.subRegex)
                                    } |
                                        ForEach-Object {
                                            Write-OutputColour Green "`t└─ 👉`e[0m $($_.Name)"
                                            $context = Get-AzContext -Name $_.Name

                                            New-AzDeployment @deployParams -DefaultProfile $context | Out-Null
                                        }
                            }

                            "mgmtGroup"    {
                                $deployParams.Add("ManagementGroupId", $eachMgmtGroupName)
                                New-AzManagementGroupDeployment @deployParams | Out-Null
                            }
                        }
                    }
                    default {
                        # policy and initiatives get deployed at mgmt group level
                        $deployParams.Add("ManagementGroupId", $eachMgmtGroupName)
                        New-AzManagementGroupDeployment @deployParams | Out-Null
                    }
                }
            }
            catch {
                Write-Output "`n`n##[error]❗ Error with ${eachTsName}"
                Write-Output $_

                Write-OutputColour Green "Time to throw the error 🤮"
                throw
            }
        } -AsJob -ThrottleLimit 20 |
            Wait-Job |
                Receive-Job
}



Write-OutputColour Yellow "`n`n`tThe following deployments are run in a parrallel CPU thread in batches of 20, they"
Write-OutputColour Yellow     "`tappear not to be working, but they are hidden from view, running in their own process."
Write-OutputColour Yellow     "`tAzure has a limit of 800 deployments per scope; management group, subscription or resource group."
Write-OutputColour Yellow     "`tEach policy will clear its old successful deployments from Azure before re-deploying,"
Write-OutputColour Yellow     "`ttheir output will show once all batches of threads have run or an error is received.`n`n"



$mgmtGroupDeployments = Get-AzManagementGroupDeployment -ManagementGroupId $mgmtGroupName



if($Env:BUILD_REPOSITORY_NAME.StartsWith("glb")) {
    $tsRsgAssignments = "uks-${Env:POLICY_TENANT}-glb-assignments-rsg"
    $tsRsgInitiatives = "uks-${Env:POLICY_TENANT}-glb-initiatives-rsg"
}
else {
    $tsRsgAssignments = "uks-${Env:POLICY_TENANT}-${shortEnv}-assignments-rsg"
    $tsRsgInitiatives = "uks-${Env:POLICY_TENANT}-${shortEnv}-initiatives-rsg"
}

Write-Output "Resource Groups:"
Write-Output "uks-${Env:POLICY_TENANT}-glb-definitions-rsg"
$tsRsgAssignments
$tsRsgInitiatives



# definitions must run before initiatives so they can be referenced
foreach($templateSpecRsg in "uks-${Env:POLICY_TENANT}-glb-definitions-rsg", $tsRsgInitiatives, $tsRsgAssignments) {
    if(Get-AzResourceGroup -Name $templateSpecRsg -ErrorAction "SilentlyContinue") {


        $tsList = Get-AzTemplateSpec -ResourceGroupName $templateSpecRsg | Sort-Object -Property "Name"
        $defs   = $tsList | Where-Object { $_.Name -match "^p-\w{3}-.+$" }
        $inits  = $tsList | Where-Object { $_.Name -match "^i-.+$"       }
        $assign = $tsList | Where-Object { $_.Name -match "^a-\w+"       }


        if($null -eq $mgmtGroupDeployments) {
            $paramSplat = @{ thisMgmtGroupName = $mgmtGroupName}
        }
        else {
            $paramSplat = @{ thisMgmtGroupName = $mgmtGroupName; oldDeployments = $deployments }
        }


        if($defs) {
            Set-ThesePolicies `
                @paramSplat `
                -policyType "definitions" `
                -tsList     $defs
        }

        if($inits) {
            Set-ThesePolicies `
                @paramSplat `
                -policyType "initiatives" `
                -tsList     $inits
        }

        if($assign) {
            Set-ThesePolicies `
                @paramSplat `
                -policyType "assignments" `
                -tsList     $assign
        }
    }
    else {
        Write-OutputColour Yellow "No ${templateSpecRsg} found, skipping...  👨‍🦯"
    }
}


<#
    .SYNOPSIS
        Deploy all available Template Spec files that reside in management groups
        resource group for definitions, intiatives and assignments.

    .DESCRIPTION
        Knowing which resource groups the Template Sepc files reside, this script
        will loop over each type and publish/apply the corresponding policies. In
        order to speed up the deployment of each policy, this deployment runs in
        a PowerShell thread for each Template Spec deployment, triming down the
        time by 80% or more. Unfortunately this can also bring some difficulty in
        error handling, thus try/catch has been used in order to surface the
        appropriate thread causing the error.

        This script will find and apply the correct parameter JSON files for any
        assignments. Note that subscription level parameters reside in their own
        reposoitory, whereas management group level parameters will risde in the
        tst/glb-initiatives repositories.
#>
