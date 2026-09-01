[CmdletBinding()]
param(
    [string]$CsvPath = (Join-Path $PSScriptRoot 'ous.csv'),
    [Parameter(Mandatory)][string]$GroupName,
    [string]$StatePath = (Join-Path $PSScriptRoot 'state.json'),
    [string]$LogPath = 'Add-ComputersToGroup.log',
    [string]$AddLogPath = 'added-computers.log',
    [string]$ErrorLogPath = 'add-errors.log',
    [ValidateRange(1, 100)][int]$BatchSize = 5,
    [string]$SortBy = 'Name',
    [switch]$IncludeSubOus,
    [switch]$ResetState
)

$ErrorActionPreference = 'Stop'

$libsPath = Join-Path $PSScriptRoot 'libs'
. (Join-Path $libsPath 'Write-Log.ps1')
. (Join-Path $libsPath 'Get-OuListFromCsv.ps1')
. (Join-Path $libsPath 'Get-ScriptState.ps1')
. (Join-Path $libsPath 'Save-ScriptState.ps1')
. (Join-Path $libsPath 'Get-NextComputers.ps1')
. (Join-Path $libsPath 'Add-ComputerToGroup.ps1')
. (Join-Path $libsPath 'Write-AddLog.ps1')
. (Join-Path $libsPath 'Write-ErrorLog.ps1')
. (Join-Path $libsPath 'Get-DatedLogPath.ps1')

foreach ($logVar in @('LogPath', 'AddLogPath', 'ErrorLogPath')) {
    $value = (Get-Variable -Name $logVar -ValueOnly)
    if (-not ([IO.Path]::IsPathRooted($value) -or $value.Contains([IO.Path]::DirectorySeparatorChar) -or $value.Contains('/'))) {
        Set-Variable -Name $logVar -Value (Join-Path -Path $PSScriptRoot -ChildPath $value)
    }
    Set-Variable -Name $logVar -Value (Get-DatedLogPath -BasePath (Get-Variable -Name $logVar -ValueOnly))
}

Import-Module ActiveDirectory

if ($ResetState) {
    if (Test-Path -Path $StatePath) {
        Remove-Item -Path $StatePath -Force
        Write-Log -Message "State file removed. Progress reset." -LogPath $LogPath
    }
}

Write-Log -Message '=== Run started ===' -LogPath $LogPath

$ous = Get-OuListFromCsv -Path $CsvPath
Write-Log -Message "Loaded $($ous.Count) OU(s) from $CsvPath" -LogPath $LogPath

$state = Get-ScriptState -Path $StatePath

if ($state.CurrentOuIndex -ge $ous.Count) {
    Write-Log -Message 'All OUs in the list are complete. Use -ResetState to start over.' -LogPath $LogPath
    exit 0
}

try {
    $group = Get-ADGroup -Identity $GroupName -Properties Member -ErrorAction Stop
} catch {
    Write-Log -Message "Could not find group '$GroupName': $($_.Exception.Message)" -Level ERROR -LogPath $LogPath
    exit 1
}

$groupDn = $group.DistinguishedName
Write-Log -Message "Target group: $groupDn" -LogPath $LogPath

$memberDns = [System.Collections.Generic.HashSet[string]]::new()
foreach ($member in @($group.Member)) {
    if ($member) { [void]$memberDns.Add($member) }
}

$processedDns = [System.Collections.Generic.HashSet[string]]::new()
foreach ($dn in @($state.ProcessedDns)) {
    if ($dn) { [void]$processedDns.Add($dn) }
}

$failedDns = [System.Collections.Generic.HashSet[string]]::new()
foreach ($dn in @($state.FailedDns)) {
    if ($dn) { [void]$failedDns.Add($dn) }
}

$added = 0

while ($added -lt $BatchSize -and $state.CurrentOuIndex -lt $ous.Count) {
    $currentOu = $ous[$state.CurrentOuIndex]
    $excludeDns = @($processedDns) + @($failedDns)
    $candidates = @(Get-NextComputers -OuDn $currentOu -SortBy $SortBy -ExcludeDns $excludeDns -IncludeSubOus:$IncludeSubOus)

    if ($candidates.Count -eq 0) {
        Write-Log -Message "Finished OU '$currentOu'. Moving to next OU." -LogPath $LogPath
        $state.CurrentOuIndex++
        continue
    }

    $computer = $candidates[0]
    $computerDn = $computer.DistinguishedName

    try {
        $result = Add-ComputerToGroup -Computer $computer -GroupDn $groupDn -MemberDns $memberDns
        [void]$processedDns.Add($computerDn)
        if ($result -eq 'Added') {
            $added++
            Write-AddLog -Path $AddLogPath -Computer $computer -GroupName $group.Name -GroupDn $groupDn
            Write-Log -Message "Added $computerDn ($added/$BatchSize)" -LogPath $LogPath
        } else {
            Write-Log -Message "Already a member, skipping without counting toward batch: $computerDn" -LogPath $LogPath
        }
    } catch {
        [void]$failedDns.Add($computerDn)
        Write-ErrorLog -Path $ErrorLogPath -Computer $computer -GroupName $group.Name -GroupDn $groupDn -ErrorRecord $_
        Write-Log -Message "Failed to add $computerDn : $($_.Exception.Message)" -Level ERROR -LogPath $LogPath
    }
}

Save-ScriptState -Path $StatePath -CurrentOuIndex $state.CurrentOuIndex -ProcessedDns @($processedDns) -FailedDns @($failedDns)

Write-Log -Message "Run finished. Added $added computer(s). OU progress: index $($state.CurrentOuIndex) of $($ous.Count)." -LogPath $LogPath

if ($state.CurrentOuIndex -ge $ous.Count) {
    Write-Log -Message 'All OUs in the list are now complete.' -LogPath $LogPath
}
