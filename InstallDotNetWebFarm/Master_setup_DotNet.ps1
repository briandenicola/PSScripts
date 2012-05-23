[CmdletBinding(SupportsShouldProcess=$true)]
param(
	
	[ValidateSet("all", "copy", "base", "iis", "dotnet")]
	[string]
	$operation = "all"
)

$source = ""
$dest = ""
$url = ""
$scripts_home = "D:\Scripts\"
$utils_home = "D:\Utils\"

function Copy-Files
{
	xcopy /e/v/f/s (Join-Path $source "Scripts") $scripts_home
	xcopy /e/v/f/s (Join-Path $source "Utils") $utils_home
	xcopy /e/v/f/s (Join-Path $source "EnterpriseLibrary3.1") (Join-Path $dest "EL3.1")
}

function Setup-BaseSystem
{
	#Setup Sysem
	Disable-InternetExplorerESC
	Disable-UserAccessControl

	Enable-PSRemoting -force
	Enable-WSmanCredSSP -role server -force
	Enable-WSManCredSSP -role client -delegate * -Force

	cscript.exe //H:cscript
	setx -m SCRIPTS_HOME $scripts_home

	New-Item -Path "HKLM:SOFTWARE\Policies\Microsoft\Windows NT\" -Name "Reliability" 
	New-ItemProperty -Path "HKLM:SOFTWARE\Policies\Microsoft\Windows NT\Reliability" -Name "ShutdownReasonOn" -Value "0" -PropertyType dword
}

function Setup-IIS
{
	cd (Joint-Path $scripts_home "iis\iis7.5_install")
	.\install_and_config_iis7.ps1
}

function Setup-DotNet
{
	&$utils_home\WebPI\Webpi_installer.exe
	&$utils_home\WebPI\WebpiCmdLine.exe /Products:MVC3 /accepteula /SuppressReboot 
	&$utils_home\WebPI\WebpiCmdLine.exe /Products:NETFramework4 /accepteula /SuppressReboot 
	&$utils_home\WebPI\WebpiCmdLine.exe /Products:WebFarmFrameworkv2 /accepteula /SuppressReboot
	
	Stop-Process (Get-Process "WebPlatformInstaller").Id
	C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet_regiis.exe -iru

	cd (Join-Path $dest "EL3.1")
	.\deploy_to_gac.bat
		
	#Source library files now that they are copied over. Will need them by later functions
	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")
	audit-Servers -Servers . | % {
		WriteTo-SPListViaWebService -url $url -list AppServers -Item $(Convert-ObjectToHash $_) -TitleField SystemName 
	} 
}

function main
{	
	#Start Log
	Set-ExecutionPolicy unrestricted -force
	if( -not (Test-Path D:\Logs) ) 
	{ 
		mkdir D:\Logs 
		mkdir D:\Logs\Trace
		cmd.exe /c "net share Logs=D:\Logs /Grant:Everyone,Read"
	}
	
	$log = "D:\Logs\System-Setup-" + $ENV:COMPUTERNAME + "-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".log"
	&{Trap{continue};Start-Transcript -Append -Path $log}

	if( $operation -eq "all" -or $operation -eq "copy") { Copy-Files; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "base") { Setup-BaseSystem; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "iis") { Setup-IIS; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "dotnet") { Setup-DotNet; $operation = "all" }
	
	Stop-Transcript
	
}
main



