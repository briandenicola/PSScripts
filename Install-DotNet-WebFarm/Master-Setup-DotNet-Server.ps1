[CmdletBinding(SupportsShouldProcess=$true)]
param(
	
	[ValidateSet("all", "copy", "base", "iis", "dotnet","el", "gac", "farm")]
	[string]
	$operation = "all",
    
	[ValidateSet("create", "join", "stand-alone")]
	[string]
	$farm = "stand-alone",

    [string] $farm_name = [String]::Empty,
    [string] $service_account = [String]::Empty,
	[string] $controller = [String]::Empty,
	[switch] $record
)

. .\Libraries\BootStrap_Functions.ps1

#Set Variables
$cfg = [xml] ( gc ".\Config\web_server_setup.xml")

$source = $cfg.parameters.source 
$gac_source = $cfg.parameters.gac
$url = $cfg.parameters.url 
$scripts_home = $cfg.parameters.scripts
$utils_home = $cfg.parameters.utils
$webpi = $cfg.parameters.webpi
$wff_installer_location = $cfg.parameters.wff
$logs_home = $cfg.parameters.logs

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
	cd  (Join-Path $ENV:SCRIPTS_HOME "iis\install")
	.\install_and_config_iis7.ps1
}

function Setup-DotNet
{
	#Install .Net Apps
	Write-Host "[ $(Get-Date) ] - Installing MVC3, ARR, and DotNet 4 . . ."
	&$webpi /Install /Products:MVC3 /accepteula /SuppressReboot 
	&$webpi /Install /Products:NETFramework4 /accepteula /SuppressReboot 
	&$webpi /Install /Products:ARR /accepteula /SuppressReboot 
	&$webpi /List /ListOption:Installed
	C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet_regiis.exe -iru
}

function Install-EnterpriseLibrary
{
    cd  (Join-Path $ENV:SCRIPTS_HOME "Install-DotNet-WebFarm")
    .\InstallTo-GlobalAssembliesCache.ps1 (Join-Path $source "EnterpriseLibrary3.1")
}

function Install-ToGAC
{
    cd  (Join-Path $ENV:SCRIPTS_HOME "Install-DotNet-WebFarm")
    .\InstallTo-GlobalAssembliesCache.ps1 $gac_source
}

function Update-Audit 
{
    $audit = audit-Servers -Servers $ENV:COMPUTERNAME
    WriteTo-SPListViaWebService -url $url -list AppServers -Item $(Convert-ObjectToHash $audit) -TitleField SystemName  
}

function Add-ServiceAccount
{
    if( ( Get-LocalAdmins -Computer $ENV:COMPUTERNAME ) -notcontains $service_account ) {
        Write-Host "[ $(Get-Date) ] - Adding $service_account to $($ENV:COMPUTERNAME)"
        net.exe localgroup administrators /add $service_account
    }
}

function Install-WebFarm-Software
{
	Write-Host "[ $(Get-Date) ] - Installing Web Farm Framework via Web Platform Installer. . ."
	&(Join-Path $wff_installer_location "install_webfarm_frameworkv2.ps1")
	Read-Host "[ $(Get-Date) ] - Press any key to continue install is complete . . "
}

function Create-Farm
{
	Add-ServiceAccount
	Install-WebFarm-Software

	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1") 
	$creds = Get-Credential $service_account
	
	Write-Host "[ $(Get-Date) ] - Creating Farm - $farm_name . . ."
	Create-WebFarm -name $farm_name -primary $ENV:COMPUTERNAME -creds $creds
	Start-Service WebFarmService
}

function Join-WebFarm
{
	Add-ServiceAccount
	Install-WebFarm-Software
	
	$sb = {
		param (
			[string] $farm,
			[string] $sever
		)
		. (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1") 
		
		if( (Get-WebFarmServers -name $farm) -notcontains $server ) {
		
			Write-Host "[ $(Get-Date) ] - Joining farm - $farm  . . ."
			Add-ServersToWebFarm -name $farm -members $server
			Sync-WebFarm -name $farm
		}
		else {
			Write-Host "$server is already a member of $farm_name . . ."
		}
	}
	
	Invoke-Command -Computer $controller -ScriptBlock $sb -ArgumentList $farm_name, $ENV:COMPUTERNAME
}

function main
{	
	Set-ExecutionPolicy unrestricted -force
	if( -not (Test-Path $logs_home) ) { 
		mkdir $logs_home
		mkdir (Join-Path $logs_home "Trace")
		net share Logs=$logs_home /Grant:Everyone,Read
	}
	
	if( $farm -eq "create" -or $farm -eq "join" ) {
		if( [String]::IsNullorEmpty($farm_name) ) {
			throw "Can not join $ENV:COMPUTERNAME to farm without a name . . . "	
		}
		if( [String]::IsNullorEmpty($service_account) ) {
			throw "Can not join $ENV:COMPUTERNAME to $farm_name without a service account . . . "	
		}
	}
	
	if( $farm -eq "join" -and [String]::IsNullorEmpty($controller) ) {
		throw "Can not join $ENV:COMPUTERNAME to farm without a controller . . . "	
	}
	
	$log = ".\Logs\System-Setup-" + $ENV:COMPUTERNAME + "-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".log"
	&{Trap{continue};Start-Transcript -Append -Path $log}
        
	if( $operation -eq "all" -or $operation -eq "copy" ) { Copy-Files; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "base" ) { Setup-Base; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "iis" ) { Setup-IIS; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "dotnet" ) { Setup-DotNet; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "el" ) { Install-EnterpriseLibrary; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "gac" ) { Install-ToGAC; $operation = "all" }
	if( $farm -eq "create" ) { Create-Farm }
	if( $farm -eq "join" ) { Join-WebFarm }
	if( $record ) { Update-Audit } 
    
	Stop-Transcript
	
}
main