#requires -version 2.0
[CmdletBinding()]

param (
    [ParaMeter(Mandatory=$true)][string] $cache,
    [ParaMeter(Mandatory=$true)][string] $cache_host,
    [int] $port = 22233
)

. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
Import-Module (Join-Path $ENV:SCRIPTS_HOME "Libraries\credentials.psm1")

$sb = { 
    param (
        [ParaMeter(Mandatory=$true)][string] $cache,
        [int] $port = 22233
    )

    Import-Module DistributedCacheAdministration
    Use-CacheCluster

    Set-Variable -Name assembly_path -Value 'C:\Program Files\AppFabric 1.1 for Windows Server\Microsoft.ApplicationServer.Caching.Client.dll'
    if((Test-Path $assembly_path)) {
        [Reflection.Assembly]::LoadFrom($assembly_path) | Out-Null
    }
    else {
        throw "Could not find $assembly_path"
    }

    Set-Variable -Name Key -Value "TestAppFabricKey" -Option Constant
    Set-Variable -Name value -Value (Get-Random)

    $end_points = New-Object -TypeName "Microsoft.ApplicationServer.Caching.DataCacheServerEndpoint" -ArgumentList $ENV:COMPUTERNAME, $port
    $config = New-Object -TypeName "Microsoft.ApplicationServer.Caching.DataCacheFactoryConfiguration"
    $config.Servers = [Microsoft.ApplicationServer.Caching.DataCacheServerEndpoint[]]($end_points)
 
    $factory = New-Object -TypeName "Microsoft.ApplicationServer.Caching.DataCacheFactory" -ArgumentList $config
    $data_cache = $factory.GetCache($cache)

    Write-Host ("[{0}] - Writing {1} value to cache {2} on {3}" -f (Get-Date), $value.ToString(), $cache, $ENV:COMPUTERNAME)
    $data_cache.Put($key, $value);

    Write-host ("[{0}] - Getting {1} value back from cache {2}" -f (Get-Date), $value.ToString(), $cache)
    [int]$returned_value = $data_cache.Get($key);

    if ($returned_value -eq $value) {
        Write-Host ("[{0}] - Values Match!" -f (Get-Date))
    }
    else {
        Write-Host ("[{0}] - Values DO NOT Match!" -f (Get-Date))
    }

    $data_cache.Remove($key) | Out-Null
}

Invoke-Command -ComputerName $cache_host -ScriptBlock $sb -Credential (Get-Creds) -Authentication Credssp -ArgumentList $cache, $port