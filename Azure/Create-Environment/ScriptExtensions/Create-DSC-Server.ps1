param(
    [ParaMeter(Mandatory=$true)]
    [string] $web_site,
    [ParaMeter(Mandatory=$true)]
    [string] $url,
    [ParaMeter(Mandatory=$true)]
    [string] $path
)

Add-WindowsFeature DSC-Service

Set-Variable -Name app_pool -Value "AppPool - DSC" -Option Constant
Set-Variable -Name app_pool_path -value 'IIS:\AppPools' -Option Constant

$settings = @(    @{ Key = "dbprovider"; Value = "System.Data.OleDb" },    @{ Key = "dbconnectionstr"; Value = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=C:\Program Files\WindowsPowerShell\DscService\Devices.mdb;" },    @{ Key = "ConfigurationPath"; Value = "C:\Program Files\WindowsPowerShell\DscService\Configuration" },    @{ Key = "ModulePath"; Value = "C:\Program Files\WindowsPowerShell\DscService\Modules" })

Get-Disk | Where { $_.PartitionStyle -eq "RAW" } | Initialize-Disk -PartitionStyle MBR 
Get-Disk | Where { $_.NumberOfPartitions -eq 0 } |   
    New-Partition -AssignDriveLetter -UseMaximumSize |
    Format-Volume -FileSystem NTFS -Force -Confirm:$false

if( !(Test-Path $path) ){ 
    New-Item $path -ItemType Directory
    New-Item (Join-Path $path "bin") -ItemType Directory
}

Copy-Item -Path $pshome\modules\psdesiredstateconfiguration\pullserver\Global.asax -Destination $path -Verbose
Copy-Item -Path $pshome\modules\psdesiredstateconfiguration\pullserver\PSDSCPullServer.mof -Destination $path -Verbose
Copy-Item -Path $pshome\modules\psdesiredstateconfiguration\pullserver\PSDSCPullServer.svc -Destination $path -Verbose
Copy-Item -Path $pshome\modules\psdesiredstateconfiguration\pullserver\PSDSCPullServer.xml -Destination $path -Verbose
Copy-Item -Path $pshome\modules\psdesiredstateconfiguration\pullserver\PSDSCPullServer.config -Destination (Join-Path $path "web.config")
Copy-Item -Path $pshome\modules\psdesiredstateconfiguration\pullserver\Microsoft.Powershell.DesiredStateConfiguration.Service.dll -Destination (Join-Path $path "bin")

New-WebAppPool -Name $app_pool
Set-ItemProperty (Join-Path $app_pool_path $app_pool) -name managedRuntimeVersion "v4.0"
$pool = Get-ItemProperty -Path (Join-Path $app_pool_path $app_pool)$pool.processModel.identityType = "LocalSystem"$pool | Set-Item

New-WebSite -PhysicalPath $path -Name $web_site -Port 80  -HostHeader $url
Set-ItemProperty (Join-path $path $site) -name applicationPool -value $app_pool
$appcmd = "$env:windir\system32\inetsrv\appcmd.exe" & $appCmd unlock config -section:access& $appCmd unlock config -section:anonymousAuthentication& $appCmd unlock config -section:basicAuthentication& $appCmd unlock config -section:windowsAuthentication

Copy-Item -Path $pshome/modules/psdesiredstateconfiguration/pullserver/devices.mdb -Destination $env:programfiles\WindowsPowerShell\DscService\ -Verbose
$cfg = [xml] ( gc (Join-Path $path "web.config") ) foreach( $setting in $settings )  {    $add = $cfg.CreateNode( [System.Xml.XmlNodeType]::Element, "add", $null)
    $add.SetAttribute("key", $setting.Key)
    $add.SetAttribute("value", $setting.Value )
    $cfg.Configuration.appSettings.AppendChild($add)    $cfg.Save((Join-Path $path "web.config"))}