param (
    [string] $guid
)

$guid | Add-Content -Encoding Ascii -Path ( Join-Path -Path "C:" -ChildPath $guid )