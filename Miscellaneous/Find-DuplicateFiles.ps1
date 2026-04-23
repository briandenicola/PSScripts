
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [switch]$Delete
)

Write-Host "Scanning: $Path`n"

$groups = Get-ChildItem -Path $Path -File -Recurse |
    Group-Object Length |
    Where-Object { $_.Count -gt 1 } |
    Select-Object -ExpandProperty Group |
    Get-FileHash |
    Group-Object Hash |
    Where-Object { $_.Count -gt 1 }

if (-not $groups) {
    Write-Host "No duplicates found." -ForegroundColor Green
    return
}

foreach ($group in $groups) {

    # Sort by LastWriteTime (oldest first)
    $sorted = $group.Group |
        ForEach-Object {
            $file = Get-Item $_.Path
            [PSCustomObject]@{
                Path = $file.FullName
                LastWriteTime = $file.LastWriteTime
            }
        } | Sort-Object LastWriteTime

    $keep = $sorted | Select-Object -First 1
    $remove = $sorted | Select-Object -Skip 1

    Write-Host "`nDuplicate Group:" -ForegroundColor Yellow
    Write-Host "KEEP (oldest): $($keep.Path)" -ForegroundColor Green

    foreach ($file in $remove) {
        if ($Delete) {
            Write-Host "DELETE: $($file.Path)" -ForegroundColor Red
            Remove-Item -Path $file.Path -Force
        } else {
            Write-Host "WOULD DELETE: $($file.Path)" -ForegroundColor DarkYellow
        }
    }
}

if (-not $Delete) {
    Write-Host "`nRun again with -Delete to actually remove files." -ForegroundColor Cyan
}