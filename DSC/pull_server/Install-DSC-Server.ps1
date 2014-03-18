param(
    [string] $web_site,
    [string] $url,
    [string] $path
)

Add-WindowsFeature DSC-Service
. (Join-Path $env:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")

Set-Variable -Name app_pool -Value "AppPool - DSC" -Option Constant

$settings = @(    @{ Key = "dbprovider"; Value = "System.Data.OleDb" },    @{ Key = "dbconnectionstr"; Value = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=C:\Program Files\WindowsPowerShell\DscService\Devices.mdb;" },    @{ Key = "ConfigurationPath"; Value = "C:\Program Files\WindowsPowerShell\DscService\Configuration" },    @{ Key = "ModulePath"; Value = "C:\Program Files\WindowsPowerShell\DscService\Modules" })

if( !(Test-Path $path) ){ 
    mkdir $path
    mkdir (Join-Path $path "bin")
}

cp $pshome\modules\psdesiredstateconfiguration\pullserver\Global.asax $path -Verbose
cp $pshome\modules\psdesiredstateconfiguration\pullserver\PSDSCPullServer.mof $path -Verbose
cp $pshome\modules\psdesiredstateconfiguration\pullserver\PSDSCPullServer.svc $path -Verbose
cp $pshome\modules\psdesiredstateconfiguration\pullserver\PSDSCPullServer.xml $path -Verbose
cp $pshome\modules\psdesiredstateconfiguration\pullserver\PSDSCPullServer.config (Join-Path $path "web.config")
cp $pshome\modules\psdesiredstateconfiguration\pullserver\Microsoft.Powershell.DesiredStateConfiguration.Service.dll (Join-Path $path "bin")

Create-IISAppPool -apppool $app_pool -version v4.0$pool = Get-ItemProperty -Path (Join-Path "IIS:\AppPools" $app_pool)$pool.processModel.identityType = "LocalSystem"$pool | set-item

Create-IISWebSite -site $web_site -path $path -header $url
Set-IISAppPoolforWebSite -apppool $app_pool -site $web_site
$appcmd = "$env:windir\system32\inetsrv\appcmd.exe" & $appCmd unlock config -section:access& $appCmd unlock config -section:anonymousAuthentication& $appCmd unlock config -section:basicAuthentication& $appCmd unlock config -section:windowsAuthentication

cp $pshome/modules/psdesiredstateconfiguration/pullserver/devices.mdb $env:programfiles\WindowsPowerShell\DscService\ -Verbose
$cfg = [xml] ( gc (Join-Path $path "web.config") ) foreach( $setting in $settings )  {    $add = $cfg.CreateNode( [System.Xml.XmlNodeType]::Element, "add", $null)
    $add.SetAttribute("key", $setting.Key)
    $add.SetAttribute("value", $setting.Value )
    $cfg.Configuration.appSettings.AppendChild($add)    $cfg.Save((Join-Path $path "web.config"))}