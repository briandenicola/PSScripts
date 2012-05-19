[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[Parameter(Mandatory=$true)]
	[ValidateSet("central-admin", "member-server")]
	[string]
	$type, 
	
	[ValidateSet("all", "copy", "base", "iis", "appfabric", "sharepoint-install", "farm-install")]
	[string]
	$operation = "all",
	
	[string]
	$config = ".\config\setup.xml"
)


function CopyFiles
{
	#Copy Files 
	xcopy /e/v/f/s \\ent-nas-fs01.us.gt.com\app-ops\Installs\SharePoint2010-Utils-Scripts-1.0.0-20110318\Scripts D:\Scripts\
	xcopy /e/v/f/s \\ent-nas-fs01.us.gt.com\app-ops\Installs\SharePoint2010-Utils-Scripts-1.0.0-20110318\Utils D:\Utils\
	xcopy /e/v/f/s \\ent-nas-fs01.us.gt.com\app-ops\Installs\EnterpriseLibrary4.1 D:\Deploy\EL4.1\
	xcopy /e/v/f/s \\ent-nas-fs01.us.gt.com\app-ops\Installs\ReportViewers D:\Deploy\ReportViewers\
	copy \\ent-nas-fs01.us.gt.com\app-ops\Installs\WindowsServerAppFabricSetup_x64_6.1.exe D:\Deploy\
	copy \\ent-nas-fs01.us.gt.com\app-ops\Installs\SharePoint_Server_2010-SP1-14.0.6029.1000.zip D:\Deploy\
	D:\Utils\posix\unzip.exe D:\Deploy\SharePoint_Server_2010-SP1-14.0.6029.1000.zip -d D:\Deploy\
}

function BaseSetup
{
	#Setup Sysem
	Enable-PSRemoting -force
	Enable-WSmanCredSSP -role server -force
	cscript.exe //H:cscript
	D:\Scripts\Setup\config_shutdown_tracker.vbs
	D:\Scripts\Setup\config_additional_items.bat
}

function IISSetup
{
	#Install IIS, .NET4, SQL Client, and WebDeploy
	cd  D:\Scripts\iis\iis7.5_install\
	D:\Scripts\iis\iis7.5_install\install_and_config_iis7.ps1
	D:\utils\WebPI\WebpiCmdLine.exe /Products:NETFramework4 /accepteula /SuppressReboot 
	D:\utils\WebPI\WebpiCmdLine.exe /Products:SQLNativeClient2008 /accepteula /SuppressReboot
	D:\utils\WebPI\WebpiCmdLine.exe /Products:WDeployNoSMO /accepteula /SuppressReboot 
	C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet_regiis.exe -iru
}

function AppFabricSetup
{
	#Install AppFabric
	powershell.exe -ImportSystemModules -command { Add-WindowsFeature  AS-Web-Support;  Add-WindowsFeature  AS-HTTP-Activation }
	D:\Deploy\WindowsServerAppFabricSetup_x64_6.1.exe /install HostingServices
	while( (Get-Process | where { $_.ProcessName -eq "WindowsServerAppFabricSetup_x64_6.1" }) -ne $nul) { Sleep 5 }
}

function SharePointSetup
{
	#Install Enterprise Library to GAC
	cd D:\Deploy\EL4.1
	D:\Deploy\EL4.1\deploy_to_gac.bat
	
	#Install Reporting Services Viewers for SharePoint
	cd D:\Deploy\ReportViewers
	D:\Deploy\ReportViewers\ReportViewer2008.exe /q
	
	#Install SharePoint
	cd D:\Scripts\InstallSharePoint2010
	D:\Scripts\Database\create_sql_alias.bat $cfg.setup.database.alias $cfg.setup.database.instance $cfg.setup.database.port
	D:\Scripts\InstallSharePoint2010\Install-SharePointBits.ps1 -config $cfg.setup.config_path -setup $cfg.setup.setup_path
	D:\Scripts\InstallSharePoint2010\Disable-LoopbackCheck.bat
	cacls D:\Web\default_site /E /G IIS_IUSRS:R /T

	#Record system
	. D:\Scripts\Libraries\SharePoint_Functions.ps1
	. D:\Scripts\Libraries\Standard_Functions.ps1
	audit-Servers -Servers . | % { WriteTo-SPListViaWebService -url "http://collaboration.gt.com/site/SharePointOperationalUpgrade/" -list Servers -Item $(Convert-ObjectToHash $_) -TitleField SystemName } 
}

function FarmSetup
{
	cd D:\Scripts\InstallSharePoint2010
	if( $type -eq "central-admin")
	{	
		D:\Scripts\InstallSharePoint2010\Create-SharePointFarm.ps1 -db $cfg.setup.database.alias
	} 
	else
	{
		D:\Scripts\InstallSharePoint2010\Join-SharePointFarm.ps1 -db $cfg.setup.database.alias
	}
}

function main
{	
	#Start Log
	Set-ExecutionPolicy unrestricted -force
	if( -not (Test-Path D:\Logs) ) { mkdir D:\Logs }
	if( -not (Test-Path D:\Logs\Trace) ) { mkdir D:\Logs\Trace }
	
	$log = "D:\Logs\System-Setup-" + $ENV:COMPUTERNAME + "-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".log"
	&{Trap{continue};Start-Transcript -Append -Path $log}

	net share Logs=D:\Logs /Grant:everyone,Read

	if( $operation -eq "all" -or $operation -eq "copy") { CopyFiles; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "base") { BaseSetup; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "iis") { IISSetup; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "appfabric") { AppFabricSetup; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "sharepoint-install") { SharePointSetup; $operation = "all" }
	
	Read-Host "Press any key to continue to either create or join the farm. Please remember that only one system can run config wizard at a time."
	if( $operation -eq "all" -or $operation -eq "farm-install") { FarmSetup }
	Stop-Transcript
	
}
$cfg = [xml] (gc $config)
main



