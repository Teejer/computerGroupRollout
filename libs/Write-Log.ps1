function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO',
        [string]$LogPath
    )

    if (-not $LogPath -and $script:LogPath) {
        $LogPath = $script:LogPath
    }

    $entry = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message

    if ($Level -eq 'ERROR') {
        Write-Host $entry -ForegroundColor Red
    } elseif ($Level -eq 'WARN') {
        Write-Host $entry -ForegroundColor Yellow
    } else {
        Write-Host $entry
    }

    if ($LogPath) {
        Add-Content -Path $LogPath -Value $entry -Encoding UTF8
    }
}
