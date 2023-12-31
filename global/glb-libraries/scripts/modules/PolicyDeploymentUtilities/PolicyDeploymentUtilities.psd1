#
# Module manifest for module 'PolicyDeploymentUtilities'
#
# Generated by: Paul MacKinnon
#


@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'PolicyDeploymentUtilities.psm1'

    # Version number of this module.
    ModuleVersion = '0.0.1'

    # ID used to uniquely identify this module
    GUID = '1708e380-9693-483b-9fab-6ca3bd0d1a1a'

    # Author of this module
    Author = 'Paul MacKinnon'

    # Copyright statement for this module
    Copyright = '(c) Paul MacKinnon. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Functions to aid the deployment function of Azure policies using Template Specs'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @(
        "Compare-TheseParams.psm1"
        "Get-AssignmentDeploymentScope.psm1"
        "Get-TsRsg.psm1"
        "Write-OutputColour.psm1"
    )

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        "Compare-TheseParams"
        "Get-AssignmentDeploymentScope"
        "Get-TsRsg"
        "Write-OutputColour"
    )

    # Variables to export from this module
    VariablesToExport = '*'
}