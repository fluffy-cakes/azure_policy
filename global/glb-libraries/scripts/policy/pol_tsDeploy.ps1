[CmdletBinding()]
param(
    # the full repository name used to identify the file path for the Template Spec files reside locally
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$buildRepositoryName
)



$PSVersionTable
$ErrorActionPreference = "stop"

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



function Remove-MetaData {
    param($node)

    # STRIP BICEP BINARY METADATA
    # We use bicep build to generate template specs. The command `bicep build` adds it's binary metdata data into the template
    # spec about the versioned used and its hash value. This causes an issue when you've made NO changes to the bicep file but
    # the template spec portal comparison thinks you have because it's just comparing JSON line-by-line. In order to bypass
    # this we need to strip any objects that contain the binary metadata using the keyword "_generator", as it's more unique.

    # "metadata": {
    #     "_generator": {
    #       "name": "bicep",
    #       "version": "0.4.1008.15138",                <- offending line
    #       "templateHash": "9914162448113979868"       <- offending line
    #     }

    if($node -is [PSCustomObject]) {
        foreach($prop in $node.PSObject.Properties) {
            if($prop.Name -eq "_generator") {
                $node.PSObject.Properties.Remove($prop.Name)
                Write-Output "Removed $($prop.Name)"
            } else {
                Remove-MetaData -node $prop.Value
            }
        }
    # Handle properties that contain arrays. eg.
    # "dependsOn": [
    #     "[resourceId('Microsoft.OperationalInsights/workspaces', parameters('p_workspaceName'))]"
    # ]
    } elseif($node -is [array]) {
        foreach($item in $node) {
            Remove-MetaData -node $item
        }
    }
}




function Set-ThisTemplateSpec {
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [string]$tsName,

        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [string]$tsRsg
    )

    Write-Output "`n`n`n##[section]🖖 function`tSet-ThisTemplateSpec"

    Write-Output "##[command]🐽`tGet-Content -Path `"./${tsName}.json`""
    $newFile = Get-Content -Path "./${tsName}.json" | ConvertFrom-Json

    $buildTags            = [PSObject]@{
        "buildBranch"     = $Env:BUILD_SOURCEBRANCHNAME
        "buildEngineer"   = $Env:BUILD_QUEUEDBY
        "buildId"         = $Env:BUILD_BUILDID
        "buildRepo"       = $Env:BUILD_REPOSITORY_NAME
        "buildTime"       = $Env:SYSTEM_PIPELINESTARTTIME
        "buildUrl"        = "${Env:SYSTEM_TEAMFOUNDATIONSERVERURI}${Env:SYSTEM_TEAMPROJECT}/_build/results?buildId=${Env:BUILD_BUILDID}&view=results"
    }

    $azTemplateSpecParams = @{
        Description       = $newFile.variables.v_policyDescription
        DisplayName       = $newFile.variables.v_policyName
        Location          = "uksouth"
        Name              = $newFile.variables.v_policyName
        ResourceGroupName = $tsRsg
        Tag               = $buildTags
        TemplateFile      = "./${tsName}.json"
        Version           = $newFile.resources[0].properties.metadata.version
    }

    Write-Output "Template Spec parameters:"
    $azTemplateSpecParams



    Write-Output "`n##[command]🐽`tGet-AzTemplateSpec `"$($newFile.variables.v_policyName)`" 🚶"
    $getTs = Get-AzTemplateSpec -Name $newFile.variables.v_policyName -ResourceGroupName $tsRsg  -ErrorAction "SilentlyContinue"


    if(($getTs) -and ($getTs.Versions)) {
        $currentTsVersions = $getTs.Versions.Name.ForEach({[version]$_})
            | Sort-Object # create new array of 'versions', else they will be 'strings' that you cannot sort properly

        Write-Output "Template Spec exists. The current versions are:"
        $currentTsVersions.ForEach({[string]$_})

        if($newFile.resources[0].properties.metadata.version -in $getTs.Versions.Name) {
            # if the generated template spec 'version' already exists as a version in the portal, use that for comparing differences
            $getThisVersion = $newFile.resources[0].properties.metadata.version
        }
        else {
            # if the generated template spec 'version' doesn't exist as a version in the portal, compare the latest one
            $getThisVersion = ([string]$currentTsVersions[-1])
        }

        (Get-AzTemplateSpec `
            -Name              $newFile.variables.v_policyName `
            -ResourceGroupName $tsRsg `
            -Version           $getThisVersion).Versions.MainTemplate |
                Out-File -FilePath  "./portal_${tsName}.json"
        $portal = Get-Content -Path "./portal_${tsName}.json" | ConvertFrom-Json



        Write-Output "`n##[debug]🐞`tLooking for changes  👀"
        $oldCompareFile = Get-Content -Path "./portal_${tsName}.json" -Raw | ConvertFrom-Json
        $newCompareFile = Get-Content -Path "./${tsName}.json"        -Raw | ConvertFrom-Json

        Remove-MetaData -node $oldCompareFile
        Remove-MetaData -node $newCompareFile

        # Copy files out of directory and rename template spec for publishing to pipeline
        $newCompareFile |
            ConvertTo-Json -Depth 100 |
                Out-File -FilePath "${Env:SYSTEM_DEFAULTWORKINGDIRECTORY}/cleaned_${tsName}.json"

        # Set pipeline variable to upload cleaned template spec
        Write-Output "##vso[task.setvariable variable=tsCleanUpload]true"

        $compare = Compare-Object `
            -ReferenceObject  $($oldCompareFile | ConvertTo-Json -Depth 100) `
            -DifferenceObject $($newCompareFile | ConvertTo-Json -Depth 100)

        if(-not $compare) {
            Write-Output "`n##[debug]🐞`tBicep Template Spec with version output $($portal.resources[0].properties.metadata.version) matches the portal, skipping push  🎉"
        } else {
            Write-Output "`n##[debug]🐞`tChanges detected. Current Version: $($portal.resources[0].properties.metadata.version)"

            if([version]$newFile.resources[0].properties.metadata.version -le [version]$portal.resources[0].properties.metadata.version) {
                $versionError = "🤯 New version number is < or = to the existing one. Did someone forget to bump the Bicep file?"

                if( ($env:BUILD_SOURCEBRANCH -match "^refs/heads/main$") -or
                    ($env:BUILD_SOURCEBRANCH -match "^refs/tags/release-v\d\.\d\.\d$")) {
                    $fileContentSameBruv = "`n$versionError"
                    throw $fileContentSameBruv
                } else {
                    Write-Output "##[warning]`t${versionError}"
                    Write-Output "##vso[task.complete result=SucceededWithIssues;]${versionError}"
                }
            }

            Write-Output "##[debug]🐞`tNew Version: $($newFile.resources[0].properties.metadata.version)  🦄"
            Write-Output "##[command]🐽`tSet-AzTemplateSpec"

            Write-OutputColour Yellow "###############################################################"
            Write-OutputColour Yellow "~ Bicep Template Spec differs from the portal, updating  🌴  🚜"
            Write-OutputColour Yellow "###############################################################"

            Set-AzTemplateSpec @azTemplateSpecParams
        }
    } else {
        Write-Output "`n##[command]🐽`tNew-AzTemplateSpec`nNo Template Spec in the portal, creating  🌱"
        New-AzTemplateSpec @azTemplateSpecParams

        # Set pipeline variable to NOT upload cleaned template spec
        Write-Output "##vso[task.setvariable variable=tsCleanUpload]false"
    }
}



$currentDir = (Get-Location).Drive.CurrentLocation.Split(((Get-Location).Provider.ItemSeparator))[-1]


# parallelism is not required as this doesn't take long to deploy
if($currentDir -eq "definitions") {
    $thisRsg = Get-TsRsg `
        -BuildRepoName    $buildRepositoryName `
        -CurrentDirectory $currentDir `
        -Tenant           $Env:POLICY_TENANT

    Get-ChildItem -Directory |
        ForEach-Object {
            $directory = $_.FullName

            Write-OutputColour Cyan "`n`n`n`n`n#".PadRight(70, "#")
            Write-OutputColour Cyan           "📂 ${directory} 👇"
            Set-Location -Path $directory

            (Get-ChildItem -Recurse -Include "*.json").BaseName |
                Sort-Object |
                    ForEach-Object {
                        Set-ThisTemplateSpec `
                            -tsName $_ `
                            -tsRsg  $thisRsg
                    }
        }
}
elseif($currentDir -in "assignments","initiatives") {
    $thisRsg = Get-TsRsg `
        -BuildRepoName    $buildRepositoryName `
        -CurrentDirectory $currentDir `
        -Environment      $Env:POLICY_ENVIRONMENT `
        -Tenant           $Env:POLICY_TENANT

    (Get-ChildItem -Recurse -Include "*.json").BaseName |
        Sort-Object |
            ForEach-Object {
                Set-ThisTemplateSpec `
                    -tsName $_ `
                    -tsRsg  $thisRsg
            }
}


<#
    .SYNOPSIS
        A script to deploy/update Template Specs in Azure.

    .DESCRIPTION
        This script will deploy any pre-built Bicep filesturned JSON from previous tasks
        into Azure. It will compare if any changes have been made, and update if need be.
        Note that the script will be able to overwrite Template Specs if it runs from a
        a development branch, but will error out if run from either "main" or "release"
        branch; this is to allow code to be worked on without needless bumping the version
        for testing, and to fail if running in DEV, PPD or PRD environments.
#>
