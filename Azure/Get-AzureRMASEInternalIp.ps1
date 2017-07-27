[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string] $ASEName
)

Set-StrictMode -Version 5

try { 
    Get-AzureRmContext | Out-Null
}
catch { 
    Write-Verbose -Message ("[{0}] - Logging into Azure" -f $(Get-Date))
    Login-AzureRmAccount 
}

$result = @{}

$debug = $DebugPreference

$DebugPreference = 'continue'
$tmp_file = Join-Path -Path $ENV:TMP -ChildPath ([IO.Path]::GetRandomFileName())

$opts = @{
    ResourceGroupName = $ResourceGroupName
    ResourceType      = 'Microsoft.Web/hostingEnvironments/capacities'
    ResourceName      = ('{0}/virtualip' -f $ASEName)
    ApiVersion        = '2016-09-01'
}
Get-AzureRmResource  @opts *> $tmp_file

$result.InternalIpAddress = Select-String "InternalIpAddress" $tmp_file | Foreach { $_.Line.Split(":")[1].TrimStart(" `"").TrimEnd("`",") }
$result.ServiceIpAddress = Select-String "serviceIpAddress"  $tmp_file | Foreach { $_.Line.Split(":")[1].TrimStart(" `"").TrimEnd("`",") }

Remove-Item -Path $tmp_file -Force | Out-Null
$DebugPreference = $debug

return $result