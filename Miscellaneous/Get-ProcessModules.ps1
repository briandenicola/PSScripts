param(
    [Parameter(Mandatory = $false, ValueFromPipeline = $True)]
    [string] $processName
)

$modules = @()
$modules = Get-Process -Name $processName | Select-Object Name, Modules
return $modules 