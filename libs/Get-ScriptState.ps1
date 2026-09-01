function Get-ScriptState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (Test-Path -Path $Path) {
        try {
            $saved = Get-Content -Path $Path -Raw | ConvertFrom-Json
            return [pscustomobject]@{
                CurrentOuIndex = [int]$saved.CurrentOuIndex
                ProcessedDns   = @($saved.ProcessedDns)
                FailedDns      = @($saved.FailedDns)
            }
        } catch {
            throw "State file '$Path' exists but could not be read as JSON: $($_.Exception.Message)"
        }
    }

    return [pscustomobject]@{
        CurrentOuIndex = 0
        ProcessedDns   = @()
        FailedDns      = @()
    }
}
