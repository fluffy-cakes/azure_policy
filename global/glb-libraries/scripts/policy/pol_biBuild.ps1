Function Set-BicepBuild {
    (Get-ChildItem -Recurse -Include "*.bicep").Name |
        Sort-Object |
            ForEach-Object -Parallel {
                $file = $_
                Write-Output "##[command]🐽`taz bicep build -f ${file}"


                # the "bicep" binary file is built into the Azure CLI task
                # thus "bicep build {file}" can be used
                # whereas "az bicep build..." requires the binary to download
                # every time the command is executued, which unfortunately
                # causes write issues when saving the binary to local disk
                # during each parallel job

                $cmd = Start-Process `
                    -PassThru `
                    -NoNewWindow `
                    -Wait `
                    'bicep' `
                    -ArgumentList "build ${file}"

                if($cmd.ExitCode -ne 0) {
                    Write-Output "##[error]❗`t🤯 Error creating ARM template from `"${file}`""
                    throw
                }

            } -AsJob -ThrottleLimit 20 |
                Wait-Job |
                    Receive-Job

    Write-Output "`nARM templates:"
    (Get-ChildItem -Recurse -Include "*.json").Name | Sort-Object
}



if(Get-ChildItem -Directory) {
    foreach($folder in Get-ChildItem -Directory) {
        $directory = $folder.FullName
        Write-Output "`n`n##[debug]🐞`tChanging to directory ${directory}:"
        Set-Location -Path $directory
        Set-BicepBuild
    }
}
else {
    $directory = (Get-Location).Path
    Write-Output "`n`n##[debug]🐞`tDirectory set to ${directory}:"
    Set-BicepBuild
}


<#
    .SYNOPSIS
        A simple script to create ARM template JSON files from Bicep code.

    .DESCRIPTION
        Depending upon which folder of a repo this script is run from, it
        will either Bicep build definitions, initiatives or assignements
        to be later consumed for Template Spec deployment in the following
        tasks. Note that the "definitions" folder will contain sub-folders
        below it, thus it will hit the first condition and loop over each
        sub folder.
#>
