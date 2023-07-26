function Compare-TheseParams {
    [CmdletBinding()]
    param(
        # the existing object to compare against
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$ObjExisting,

        # the new object to compare with
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$ObjNew,

        # the current depth/scope of the looping comparison
        [Parameter(Mandatory=$true)]
        [string]$Scope
    )

    Write-Output "`n`n## COMPARING SCOPE #${Scope} ##"
    Write-Output "Test NEW values are present in EXISTING object"
    :labelKey foreach($key in $ObjNew.Keys) {
        if($key -notin $ObjExisting.Keys) {
            Write-OutputColour Red "❗`t⛔  FAIL ${key} not in:"
            $ObjExisting.Keys
            $breakValueNew = $true
            break
        }
        else {
            Write-Output "`nParameter key: ${key}"
            foreach($subKey in $ObjNew[$key].Keys) {
                if($subKey -notin $ObjExisting[$key].Keys) {
                    Write-OutputColour Red "❗`t⛔  FAIL ${subKey} not in:"
                    $ObjExisting[$key].Keys
                    $breakValueNew = $true
                    break labelKey
                }
                else {
                    Write-Output "`tSub key: ${subKey}"

                    $ReferenceObject = $($ObjNew[$key][$subKey] | ConvertTo-Json)
                    if(-not $ReferenceObject) {
                        Write-OutputColour Yellow "❗`t${subKey} of ${key} in 'objNew' converted to NULL"
                    }

                    $DifferenceObject = $($ObjExisting[$key][$subKey] | ConvertTo-Json)
                    if(-not $DifferenceObject) {
                        Write-OutputColour Yellow "❗`t${subKey} of ${key} in 'objExisting' converted to NULL"
                    }

                    # If they are both converted to null don't compare
                    if((-not $ReferenceObject) -and (-not $DifferenceObject)) {
                        Write-OutputColour Yellow "❗`tBoth are converted to NULL"
                        continue
                    }

                    # If one is null but the other not, or they compare to be different
                    if( ((-not $ReferenceObject) -and $DifferenceObject) -or
                        ($ReferenceObject -and (-not $DifferenceObject)) -or
                        (Compare-Object -ReferenceObject $ReferenceObject -DifferenceObject $DifferenceObject)) {

                        Write-OutputColour Red "❗`t⛔  FAIL: ${subKey} of ${key}"
                        $ObjNew[$key][$subKey] | ConvertTo-Json
                        $breakValueNew = $true
                        break labelKey
                    }
                }
            }
        }
    }


    if(-not $breakValueNew) {
        Write-Output "`nFLIP!`nTest EXISTING values are present in NEW object"
        :labelKey foreach($key in $ObjExisting.Keys) {
            if($key -notin $ObjNew.Keys) {
                Write-OutputColour Red "❗`t⛔  FAIL ${key} not in:"
                $ObjNew.Keys
                $breakValueExisting = $true
                break
            }
            else {
                Write-Output "`tParameter key: ${key}"
                foreach($subKey in $ObjExisting[$key].Keys) {
                    if($subKey -notin $ObjNew[$key].Keys) {
                        Write-OutputColour Red "❗`t⛔  FAIL ${subKey} not in:"
                        $ObjNew[$key].Keys
                        $breakValueExisting = $true
                        break labelKey
                    }
                }
            }
        }
    }
    else {
        Write-OutputColour Red "❗`t⛔  Compare #${Scope} FAILED"
        $Global:paramChanged = $true

        Write-Output "`n`nNew Object"
        $ObjNew      | ConvertTo-Json

        Write-Output "`n`nExisting Object"
        $ObjExisting | ConvertTo-Json
    }


    if($breakValueExisting) {
        Write-OutputColour Red "❗`t⛔  Compare #${Scope} FAILED"
        $Global:paramChanged = $true

        Write-Output "`n`nNew Object"
        $ObjNew      | ConvertTo-Json

        Write-Output "`n`nExisting Object"
        $ObjExisting | ConvertTo-Json
    }
}


<#
    .SYNOPSIS
        A PowerShell function to determine if differences exist between to hashtable objects

    .DESCRIPTION
        This is used to determine if the contents of an existing parameter object differs
        with that of another, outputting a global parameter of "paramChanged" which is used
        as a flag in the calling script to note if they differ. The use of the global
        parameter negates using "return".
#>
