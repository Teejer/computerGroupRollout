function Get-OuListFromCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        throw "OU list CSV not found: $Path"
    }

    $rows = @(Import-Csv -Path $Path)

    if ($rows.Count -eq 0) {
        throw "No rows found in OU list CSV: $Path"
    }

    $columnName = ($rows[0].PSObject.Properties | Select-Object -First 1).Name

    $ous = foreach ($row in $rows) {
        $value = [string]$row.$columnName
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $value.Trim()
        }
    }

    if (-not @($ous).Count) {
        throw "No OU values found in column '$columnName' of $Path"
    }

    return @($ous)
}
