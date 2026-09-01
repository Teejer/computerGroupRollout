function Get-NextComputers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$OuDn,
        [string]$SortBy = 'Name',
        [string[]]$ExcludeDns = @(),
        [switch]$IncludeSubOus
    )

    $searchScope = if ($IncludeSubOus) { 'Subtree' } else { 'OneLevel' }

    $computers = @(Get-ADComputer -Filter * -SearchBase $OuDn -SearchScope $searchScope -ErrorAction Stop)

    if ($computers.Count -gt 0 -and $ExcludeDns) {
        $exclude = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($dn in $ExcludeDns) {
            if ($dn) { [void]$exclude.Add($dn) }
        }
        $computers = @($computers | Where-Object { -not $exclude.Contains($_.DistinguishedName) })
    }

    return @($computers | Sort-Object -Property $SortBy)
}
