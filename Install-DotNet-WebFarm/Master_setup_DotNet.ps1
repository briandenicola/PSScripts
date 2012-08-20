[CmdletBinding(SupportsShouldProcess=$true)]
param(
	
	[ValidateSet("all", "copy", "base", "iis", "dotnet")]
	[string]
	$operation = "all"
)

function CopyFiles
{
	$source = "\\ent-nas-fs01.us.gt.com\app-ops\Installs\SharePoint2010-Utils-Scripts"

	xcopy /e/v/f/s (Join-Path $source "Scripts") D:\Scripts\
	xcopy /e/v/f/s (Join-Path $source "Utils") D:\Utils\
	
	#Copy Files 
	xcopy /e/v/f/s (Join-Path $source "EnterpriseLibrary3.1") D:\Deploy\EL3.1\
}

function BaseSetup
{
	#Setup Sysem
	Disable-InternetExplorerESC
	Disable-UserAccessControl

	Enable-PSRemoting -force
	Enable-WSmanCredSSP -role server -force
	Enable-WSManCredSSP -role client -delegate * -Force

	cscript.exe //H:cscript
	setx -m SCRIPTS_HOME D:\Scripts
	$ENV:SCRIPTS_HOME = "D:\Scripts"

	New-Item -Path "HKLM:SOFTWARE\Policies\Microsoft\Windows NT\" -Name "Reliability" 
	New-ItemProperty -Path "HKLM:SOFTWARE\Policies\Microsoft\Windows NT\Reliability" -Name "ShutdownReasonOn" -Value "0" -PropertyType dword
}

function IISSetup
{
	#Install IIS, .NET4, SQL Client, and WebDeploy
	cd  D:\Scripts\iis\iis7.5_install\
	D:\Scripts\iis\iis7.5_install\install_and_config_iis7.ps1
}


function dotnetSetup
{

	#Install .Net Apps
	D:\Utils\WebPI\Webpi_installer.exe
	D:\utils\WebPI\WebpiCmdLine.exe /Products:MVC3 /accepteula /SuppressReboot 
	D:\utils\WebPI\WebpiCmdLine.exe /Products:NETFramework4 /accepteula /SuppressReboot 
	D:\Utils\WebPI\WebpiCmdLine.exe /Products:WebFarmFrameworkv2 /AcceptEula /SuppressReboot
	Stop-Process (Get-Process "WebPlatformInstaller").Id
	C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet_regiis.exe -iru

	#Install Enterprise Library to GAC
	cd D:\Deploy\EL3.1
	D:\Deploy\EL3.1\deploy_to_gac.bat
		
	#Install GT Files to GAC

	#Record system
	#Source library files now that they are copied over. Will need them by later functions
	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
	audit-Servers -Servers . | % {
		$url = "http://collaboration.gt.com/site/SharePointOperationalUpgrade/applicationsupport/default.aspx"
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

	if( $operation -eq "all" -or $operation -eq "copy") { CopyFiles; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "base") { BaseSetup; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "iis") { IISSetup; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "dotnet") { dotnetSetup; $operation = "all" }
	
	Stop-Transcript
	
}
main



