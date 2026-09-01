function Save-ScriptState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][int]$CurrentOuIndex,
        [string[]]$ProcessedDns = @(),
        [string[]]$FailedDns = @()
    )

    $state = [ordered]@{
        LastRunUtc     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        CurrentOuIndex = $CurrentOuIndex
        ProcessedDns   = @($ProcessedDns)
        FailedDns      = @($FailedDns)
    }

    $state | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding UTF8
}
