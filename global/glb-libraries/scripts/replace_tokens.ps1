[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$RegexDirectoryName
)



$PSVersionTable
$ErrorActionPreference = "stop"


Write-Host "`n`n##[debug]🐞`tWorking directory: $((Get-Location).Path)"
$failPipe = $false


$content = Get-ChildItem -Path "." -File -Recurse

if($RegexDirectoryName) {
    Write-Output "Applying regex pattern for directories matching: $($RegexDirectoryName)"
    $files = $content |
        Where-Object {
            $_.DirectoryName -match $RegexDirectoryName
        }
}
else {
    $files = $content
}


foreach($file in $files.FullName) {
    Write-Output "##[debug]🐞`t⏬ Replacing tokens in ${file} ⏬"

    foreach($variable in (Get-ChildItem -Path "env:")) {
        $pattern  = "#{variables\.$($variable.Name)}#"
        $count    = @(Select-String -Path $file -Pattern $pattern).Count

        if($count -gt 0) {
            $string  = $variable.Value
            Write-Output "${count}x of"
            Write-Output "  ❌ ${pattern}"
            Write-Output "  `t 👉 ${string}`n"

            # Case insensitive;  #{variables.common_resourceOwner}# is the same as #{variables.COMMON_RESOURCEOWNER}#
            (Get-Content -Path $file) -ireplace $pattern, $string |
                Set-Content -Path $file
        }
    }

    if(Select-String -Path $file -Pattern "#{variables\..+}#" -Quiet) {
        Write-Output "`n##[error]❗`tThe following patterns were missed:"
        Select-String -Path $file -Pattern "#{variables\..+}#"
        $failPipe = $true
    }
}

if($failPipe) {
    $varPatternsMissedBruh = "🤯 Some variable patterns were not token-replaced!"
    throw $varPatternsMissedBruh
}
