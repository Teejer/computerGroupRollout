function Get-DatedLogPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$BasePath
    )

    $leaf = Split-Path -Path $BasePath -Leaf
    $dir = Split-Path -Path $BasePath -Parent

    if ($leaf -match '_\d{4}_\d{2}(\.[^.]+)?$') {
        return $BasePath
    }

    $suffix = Get-Date -Format '_yyyy_MM'
    $stem = [IO.Path]::GetFileNameWithoutExtension($leaf)
    $ext = [IO.Path]::GetExtension($leaf)
    $newLeaf = '{0}{1}{2}' -f $stem, $suffix, $ext

    if ($dir) {
        return (Join-Path -Path $dir -ChildPath $newLeaf)
    }
    return $newLeaf
}
