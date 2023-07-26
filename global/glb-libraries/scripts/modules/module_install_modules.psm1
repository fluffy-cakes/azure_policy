Function Set-PSModule {
    [CmdletBinding()]
    param (
        [Parameter(Position=1, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$MinimumVersion,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$RequiredVersion
    )

    # Central location of the current min/req defaults
    switch ($Name) {
        "Az"                   { if(($MinimumVersion.Length -eq 0) -and ($RequiredVersion.Length -eq 0)) { $MinimumVersion  = "9.3.0" } }
        "Az.Resources"         { if(($MinimumVersion.Length -eq 0) -and ($RequiredVersion.Length -eq 0)) { $MinimumVersion  = "2.0.1" } }
        "Az.Subscription"      { if(($MinimumVersion.Length -eq 0) -and ($RequiredVersion.Length -eq 0)) { $RequiredVersion = "0.7.3" } }
        default {
            # We don't have to list out all the different sub-Az resource modules we want to install, or any modules, for that matter.
            # Just pass in the name, and/or minimum/required version, and the last 'If' statement will install it.
        }
    }

    Set-PSRepository -Name "PSGallery" -InstallationPolicy "Trusted"

    # Are the modules installed?
    if($MinimumVersion) {
        $moduleInstalled = Get-Module -ListAvailable |
            Where-Object {
                ($_.Name -eq $Name) -and
                ($_.Version.ToString() -ge $MinimumVersion)
            }

        if(-not $moduleInstalled) {
            Write-Verbose "Installing module .........🌱  ${Name} ≥ ${MinimumVersion}" -Verbose
            Install-Module -Name $Name -MinimumVersion $MinimumVersion -Repository "PSGallery" -AllowClobber -Confirm:$false -Force
        } else {
            Write-Verbose "Module already installed ..👌  ${Name} ≥ ${MinimumVersion}" -Verbose
        }


    } elseif($RequiredVersion) {
        $moduleInstalled = Get-Module -ListAvailable |
            Where-Object {
                ($_.Name -eq $Name) -and
                ($_.Version.ToString() -eq $RequiredVersion)
        }

        if(-not $moduleInstalled) {
            Write-Verbose "Installing module .........🌱  ${Name} == ${RequiredVersion}" -Verbose
            Install-Module -Name $Name -RequiredVersion $RequiredVersion -Repository "PSGallery" -AllowClobber -Confirm:$false -Force
            Import-Module  -Name $Name -RequiredVersion $RequiredVersion -Force
        } else {
            Write-Verbose "Module already installed ..👌  ${Name} == ${RequiredVersion}" -Verbose
        }


    } else {
        $moduleInstalled = Get-Module -ListAvailable |
            Where-Object { $_.Name -eq $Name }

        if(-not $moduleInstalled) {
            Write-Verbose "Installing module .........🌱  ${Name}" -Verbose
            Install-Module -Name $Name -Repository "PSGallery" -AllowClobber -Confirm:$false -Force
        } else {
            Write-Verbose "Module already installed ..👌  ${Name}" -Verbose
        }
    }

    $result = Get-Module -ListAvailable | Where-Object { $_.Name -eq $Name }
    Write-Host "##[debug]🐞`t$($result.Name) is $($result.Version)"
}


<#
    .SYNOPSIS
        A quick way to install default or custom modules.

    .DESCRIPTION
        A function used to reduce code duplication on installing modules, and a way to defining a set of project level minimum/required versions for modules. It has been noted that some modules need certain versions in order to run with the project codeset where they are defined here using switch statements.

    .PARAMETER Name
        The name of the module to be installed.

    .PARAMETER MinimumVersion
        The minimum version of the module to be installed.

    .PARAMETER RequiredVersion
        The required version of the module to be installed.
#>