function Write-OutputColour {
    [CmdletBinding()]
    param(
        # the colour to output the text as
        [Parameter(Mandatory=$true, Position=1)]
        [ValidateSet('Blue','Cyan', 'Green', 'Magenta', 'Red', 'Yellow')]
        [ValidateNotNullOrEmpty()]
        [string]$Colour,

        # the text for which the colour will be applied
        [Parameter(Mandatory=$true, Position=2)]
        [ValidateNotNullOrEmpty()]
        [string]$String
    )

    switch($Colour) {
        "Blue"    { $printColour = "`e[34m" }
        "Cyan"    { $printColour = "`e[36m" }
        "Green"   { $printColour = "`e[32m" }
        "Magenta" { $printColour = "`e[35m" }
        "Red"     { $printColour = "`e[31m" }
        "Yellow"  { $printColour = "`e[33m" }
    }

    $newString = $String.Replace("`n", "`n${printColour}")

    Write-Output "${printColour}${newString}`e[0m"
}


<#
    .SYNOPSIS
        A simple way to change the colour of text for readability in Azure DevOps.

    .DESCRIPTION
        Azure DevOps can only output a max of 4bit colour. It can only change the
        colour per line, thus every line break will need the colour added to the
        start so it can terminate at the end.
#>
