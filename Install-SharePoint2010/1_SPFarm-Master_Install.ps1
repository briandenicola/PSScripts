[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[ValidateSet("all", "copy", "base", "iis", "database", "sharepoint-install", "farm-install")]
	[string]
	$operation = "all",
	
	[string]
	$config = ".\config\setup.xml"
)

# Source Required Libraries
. .\Libraries\Standard_Functions.ps1
. .\Libraries\SharePoint_Functions.ps1
	
#Global Varibles
$global:server_type = $null
$global:farm_type = $null
$global:source = $null
$global:scripts_home = $null
$global:utils_home = $null
$global:deploy_home = $null
$global:sp_version = $null
$global:audit_url = $null

function Get-Variables
{

	Write-Host "Using the following Varibles - " 
	$cfg.SharePoint.BaseConfig
	
	$global:source = $cfg.SharePoint.Setup.master_file_location
	$global:scripts_home = $cfg.SharePoint.BaseConfig.ScriptsHome
	$global:utils_home = $cfg.SharePoint.BaseConfig.UtilsHome
	$global:deploy_home = $cfg.SharePoint.BaseConfig.DeployHome
	$global:sp_version = $cfg.SharePoint.BaseConfig.SPVersion
	$global:audit_url = $cfg.SharePoint.BaseConfig.AuditUrl
	
	$xpath = "/SharePoint/Farms/farm/server[@name='" + $ENV:COMPUTERNAME + "']"
	$node = Select-Xml -xpath $xpath  $cfg 
	
	$global:farm_type = $node.Node.ParentNode.name
	$global:server_type = $node.Node.Role
	
	if( $global:server_type -ne $null )
	{
		Write-Host "Found $ENV:COMPUTERNAME in $global:farm_type Farm Configuration as a $global:server_type server"
	}
	else
	{
		throw "Could not find $ENV:COMPUTERNAME in configuration. Must exit"
	}
}

function Unzip-File
{
	param (
		[string] $zip,
		[string] $folder
	)
	
	$zip = dir $zip | Select -Expand FullName #To Eliminate any double \\ in string
	$shell_app=new-object -com shell.application 
	$zip_file = $shell_app.namespace($zip)
	$destination = $shell_app.namespace($folder)
	$destination.Copyhere($zip_file.items())

}

function CopyFiles
{
	
	xcopy /e/v/f/s "$global:source\SharePoint2010-Utils-Scripts\Scripts" "$global:scripts_home\"
	xcopy /e/v/f/s "$global:source\SharePoint2010-Utils-Scripts\Utils" "$global:utils_home\"
		
	#Copy Files 
	xcopy /e/v/f/s "$global:source\SharePoint2010-Utils-Scripts\EnterpriseLibrary4.1" "$global:$deploy_home\EL4.1\"
	xcopy /e/v/f/s "$global:source\SharePoint2010-Utils-Scripts\ReportViewers" "$global:deploy_home\ReportViewers\"
	copy "$global:source\$sp_version.zip" $global:deploy_home
	Unzip-File -zip "$deploy_home\$global:sp_version.zip" -folder $global:deploy_home
}

function BaseSetup
{
	#Setup Sysem
	Disable-InternetExplorerESC
	Disable-UserAccessControl
	
	Enable-PSRemoting -force
	Enable-WSmanCredSSP -role server -force
	
	cscript.exe //H:cscript
	setx -m SCRIPTS_HOME $global:scripts_home
	
	New-Item -Path "HKLM:SOFTWARE\Policies\Microsoft\Windows NT\" -Name "Reliability" 
	New-ItemProperty -Path "HKLM:SOFTWARE\Policies\Microsoft\Windows NT\Reliability" -Name "ShutdownReasonOn" -Value "0" -PropertyType dword
	
	if( -not ( $cfg.SharePoint.BaseConfig.HouseKeeping.Name -eq $null ) )
	{
		$house_keeping = $cfg.SharePoint.BaseConfig.HouseKeeping
		$creds = Get-Credential ( $ENV:USERDOMAIN + "\" + $house_keeping.user)
		schtasks /Create /TN $house_keeping.Name /RU $house_keeping.user /RP $creds.GetNetworkCredential().Password /SC $house_keeping.Schedule /ST $house_keeping.start_time /TR $house_keeping.process /NP
	}
}

function IISSetup
{
	#Install IIS, .NET4, SQL Client, and WebDeploy
	cd  "$global:scripts_home\iis\install\"
	.\install_and_config_iis7.ps1
	
	&"$global:utils_home\WebPI\WebpiCmdLine.exe" /Products:NETFramework4 /accepteula /SuppressReboot 
	&"$global:utils_home\WebPI\WebpiCmdLine.exe" /Products:SQLNativeClient2008 /accepteula /SuppressReboot
	&"$global:utils_home\WebPI\WebpiCmdLine.exe" /Products:WDeployNoSMO /accepteula /SuppressReboot 
	C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet_regiis.exe -iru
	
	#Install Enterprise Library to GAC
	cd "$global:deploy_home\EL4.1"
	&"$global:deploy_home\EL4.1\deploy_to_gac.bat"
	
	#Install Reporting Services Viewers for SharePoint
	cd "$global:deploy_home\ReportViewers"
	&"$global:deploy_home\ReportViewers\ReportViewer2008.exe" /q
}

function DatabaseAliasSetup
{
	New-Item -Path "HKLM:SOFTWARE\Microsoft\MSSQLServer\Client" -Name ConnectTo
	$cfg.SharePoint.Databases.Database | % { 
		Write-Host "Creating SQL Alias - " $_.name " - that points to " $_.instance " on port " $_.port
		$connection_string = "DBMSSOCN,{0},{1}" -f $_.instance, $_.port
		New-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\MSSQLServer\Client\ConnectTo" -Name $_.name -PropertyTYpe string -Value $connection_string 
	}
}

function SharePointSetup
{
	cd "$global:scripts_home\InstallSharePoint2010"
	if( CheckFor-PendingReboot )
	{
		#$config = Join-Path $PWD.Path "Configs\master_setup.xml"
		
		$script = "cd $global:scripts_home\InstallSharePoint2010;"
		$script += Join-Path $PWD.Path "1_SPFarm-Master_Install.ps1"
		$script += " -operation sharepoint-install -config $config"
		
		$cmd = "c:\windows\System32\WindowsPowerShell\v1.0\powershell.exe -noexit -command `"$script`""
		
		Add-RunOnceTask -command $cmd -name "SPInstall"
		
		Write-Host "System will reboot in 10 seconds"
		Start-Sleep 10
		Restart-Computer -Force -Confirm:$true
	
	}
	
	#Install SharePoint
	.\Modules\Install-SharePointBits.ps1 -config $cfg.SharePoint.setup.setup_configs.$global:farm_type -setup $cfg.SharePoint.Setup.setup_path
	
	New-ItemProperty -Path "HKLM:SYSTEM\CurrentControlSet\Control\Lsa" -PropertyType dword -Name "DisableLoopbackCheck" -Value "1"
	
	#cacls D:\Web\default_site /E /G IIS_IUSRS:R /T

	#Record system
	audit-Servers -Servers . | % { WriteTo-SPListViaWebService -url $global:audit_url -list Servers -Item $(Convert-ObjectToHash $_) -TitleField SystemName } 
}

function FarmSetup
{
	$db = $cfg.SharePoint.setup.databases.$global:farm_type
	$pass = $cfg.SharePoint.setup.security.$global:farm_type.passphrase
	$account = $cfg.SharePoint.setup.security.$global:farm_type.farm_account
	
	cd "$global:scripts_home\InstallSharePoint2010"
	if( $global:server_type -eq "central-admin" )
	{	
		.\Modules\Create-SharePointFarm.ps1 -db $db -passphrase $pass -account $account
	} 
	else
	{
		.\Modules\Join-SharePointFarm.ps1 -db $db -passphrase $pass
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

	try
	{
		Get-Variables
	}
	catch
	{
		Write-Error "Could not set base variables. Must exit"
		return 
	}
	
	#Steps to Setup Server 
	if( $operation -eq "all" -or $operation -eq "copy") { CopyFiles; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "base") { BaseSetup; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "iis") { IISSetup; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "database") { DatabaseAliasSetup; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "sharepoint-install") { SharePointSetup; $operation = "all" }
	
	Read-Host "Press any key to continue to either create or join the farm. Please remember that only one system can run config wizard at a time."
	if( $operation -eq "all" -or $operation -eq "farm-install") { FarmSetup }
	Stop-Transcript
	
}
$cfg = [xml] (gc $config)
main



