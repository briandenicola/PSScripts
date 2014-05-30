[CmdletBinding(SupportsShouldProcess=$true)]
param(
	
	[ValidateSet("all", "copy", "base", "iis", "dotnet","el", "gac")]
    [string] $operation = "all",
    [string] $config = ".\Config\web_server_setup.xml",
    [switch] $record
)

. .\Libraries\BootStrap_Functions.ps1

#Set Variables
Set-Variable -name cfg -Value ( [xml] ( Get-Content $config ) )
Set-Variable -name source -Value $cfg.parameters.source 
Set-Variable -name gac_source -Value $cfg.parameters.gac
Set-Variable -name url -Value $cfg.parameters.url 
Set-Variable -name scripts_home -Value $cfg.parameters.scripts
Set-Variable -name utils_home -Value $cfg.parameters.utils
Set-Variable -name webpi -Value $cfg.parameters.webpi
Set-Variable -name logs_home -Value $cfg.parameters.logs
Set-Variable -Name gac_install -Value (Join-Path $env:SCRIPTS_HOME "WebFarm\InstallTo-GlobalAssembliesCache.ps1" )

function Copy-Files
{
	xcopy /e/v/f/s (Join-Path $source "Scripts") $scripts_home
	xcopy /e/v/f/s (Join-Path $source "Utils") $utils_home
}

function Setup-Base
{
	cscript.exe //H:cscript
	setx -m SCRIPTS_HOME $scripts_home
	$ENV:SCRIPTS_HOME = $scripts_home

	Disable-InternetExplorerESC
	Disable-UserAccessControl

	Enable-PSRemoting -force
	Enable-WSmanCredSSP -role server -force
	Enable-WSManCredSSP -role client -delegate * -Force

	New-Item -Path "HKLM:SOFTWARE\Policies\Microsoft\Windows NT\" -Name "Reliability" 
	New-ItemProperty -Path "HKLM:SOFTWARE\Policies\Microsoft\Windows NT\Reliability" -Name "ShutdownReasonOn" -Value "0" -PropertyType dword
}

function Setup-IIS
{
    Push-Location $PWD.Path

	cd  (Join-Path $ENV:SCRIPTS_HOME "iis\install")
	$iis7 = (Join-Path $ENV:SCRIPTS_HOME "iis\install\install_and_config_iis7.ps1")
    $iis8 = (Join-Path $ENV:SCRIPTS_HOME "iis\install\install_and_config_iis8.ps1")

	$ver = Get-WMIObject win32_operatingSystem | Select -Expand name
	if( $ver -imatch "2008 R2" ) { 
		&$iis7
	} elseif( $ver -imatch "2012" ) { 
		&$ii8
	} else { 
		throw "Invalid Operating System Detected . . ."
	}

    Pop-Location
}

function Setup-DotNet
{
	#Install .Net Apps
	Write-Host "[ $(Get-Date) ] - Installing MVC3, ARR, and DotNet 4 . . ."
	&$webpi /Install /Products:MVC3 /accepteula /SuppressReboot 
	&$webpi /Install /Products:NETFramework4 /accepteula /SuppressReboot 
	&$webpi /Install /Products:ARR /accepteula /SuppressReboot 
    &$webpi /Install /Products:WDeplolyNoSMO /accepteula /SuppressReboot 
	&$webpi /List /ListOption:Installed
	C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet_regiis.exe -iru
}

function Install-EnterpriseLibrary
{
    &$gac_install (Join-Path $source "EnterpriseLibrary3.1")
}

function Install-ToGAC
{
    &$gac_install $gac_source
}

function Update-Audit 
{
    $audit = Audit-Servers -Servers $ENV:COMPUTERNAME
    WriteTo-SPListViaWebService -url $url -list AppServers -Item $(Convert-ObjectToHash $audit) -TitleField SystemName  
}

function main
{	
	Set-ExecutionPolicy unrestricted -force
	if( !(Test-Path $logs_home) ) { 
		mkdir $logs_home
		mkdir (Join-Path $logs_home "Trace")
		net share Logs=$logs_home /Grant:Everyone,Read
	}
		
	$log = ".\Logs\System-Setup-" + $ENV:COMPUTERNAME + "-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".log"
	&{Trap{continue};Start-Transcript -Append -Path $log}
        
	if( $operation -eq "all" -or $operation -eq "copy" ) { Copy-Files; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "base" ) { Setup-Base; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "iis" ) { Setup-IIS; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "dotnet" ) { Setup-DotNet; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "el" ) { Install-EnterpriseLibrary; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "gac" ) { Install-ToGAC; $operation = "all" }
	if( $record ) { Update-Audit } 
    
	Stop-Transcript
}
main