[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[ValidateSet("all", "copy", "base", "iis", "el", "database", "sharepoint", "farm")]
	[string]
	$operation = "all",
	
	[string]
	$config = ".\config\master_setup.xml",

    [switch]
    $record
)

. .\Libraries\BootStrap_Functions.ps1
	
#Global Varibles
$global:server_type = $null
$global:farm_type = $null
$global:source = $null
$global:scripts_home = $null
$global:utils_home = $null
$global:deploy_home = $null
$global:sp_version = $null
$global:audit_url = $null
$global:log_home = $null

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
    $global:log_home = $cfg.SharePoint.BaseConfig.LogsHome
	
	$xpath = "/SharePoint/Farms/farm/server[@name='" + $ENV:COMPUTERNAME.ToLower() + "']"
	$node = Select-Xml -xpath $xpath  $cfg 
	
	$global:farm_type = $node.Node.ParentNode.name
	$global:server_type = $node.Node.Role
	
	if( $global:server_type -ne $null ) 	{
		Write-Host "Found $ENV:COMPUTERNAME in $global:farm_type Farm Configuration as a $global:server_type server"
	}
	else {
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

function Copy-Files
{
	#Copy Team Utils
	xcopy /e/v/f/s "$global:source\SharePoint2010-Utils-Scripts\Scripts" "$global:scripts_home\"
	xcopy /e/v/f/s "$global:source\SharePoint2010-Utils-Scripts\Utils" "$global:utils_home\"
		
	#Copy SharePoint Files 
    if( -not ( Test-Path $global:deploy_home ) ) {
        mkdir $global:deploy_home
    }
	copy "$global:source\$sp_version.zip" $global:deploy_home
	Unzip-File -zip "$deploy_home\$global:sp_version.zip" -folder $global:deploy_home
}

function Setup-BaseSystem
{
	#Setup Sysem
	Disable-InternetExplorerESC
	Disable-UserAccessControl
	
    #Setup Powershell Remotint
	Enable-PSRemoting -force
	Enable-WSmanCredSSP -role server -force
	
    #Setup Scripting locations
	cscript.exe //H:cscript
	setx -m SCRIPTS_HOME $global:scripts_home
    $ENV:SCRIPTS_HOME = $global:scripts_home
	
    #Disable Reboot Prompt
	New-Item -Path "HKLM:SOFTWARE\Policies\Microsoft\Windows NT\" -Name "Reliability" 
	New-ItemProperty -Path "HKLM:SOFTWARE\Policies\Microsoft\Windows NT\Reliability" -Name "ShutdownReasonOn" -Value "0" -PropertyType dword
	
    #Add SCOM Account to Local Admin
    if( $cfg.SharePoint.BaseConfig.SCOMUser -ne [String]::Empty ) {
        Add-LocalAdmin -computer $env:COMPUTERNAME -Group $cfg.SharePoint.BaseConfig.SCOMUser
    }

    #Setup Schedule Tasks
    $user = [String]::Empty
    foreach( $task in $cfg.SharePoint.Tasks.Task ) {
        if( $creds -eq $null -or $user -ne $task.user ) {
    	    $creds = Get-Credential ( $ENV:USERDOMAIN + "\" + $task.user)
            $user = $task.user
        }
		schtasks /Create /TN $task.Name /RU $task.user /RP $creds.GetNetworkCredential().Password /SC $task.Schedule /ST $task.start_time /TR $task.process /RL HIGHEST /V1		
	}
}

function Setup-IIS
{
    try { 
	    #Install IIS and disable loopback check
	    cd  "$global:scripts_home\iis\install\"
	    .\install_and_config_iis8.ps1
    }
    catch {
        throw "Error installing IIS"
    }
	
    New-ItemProperty -Path "HKLM:SYSTEM\CurrentControlSet\Control\Lsa" -PropertyType dword -Name "DisableLoopbackCheck" -Value "1"
}

function Install-EnterpriseLibrary
{
    #Install Microsoft's Enterprise Library to GAC
    cd  "$global:scripts_home\MISC-SPScripts"
    .\Install-Assemblies-To-GAC.ps1 ("$global:source\SharePoint2010-Utils-Scripts\EnterpriseLibrary4.1")
}

function Setup-DatabaseAlias
{
    try {
        #Create SQL Aliases 
        if( -not ( Test-Path "HKLM:SOFTWARE\Microsoft\MSSQLServer" ) ) { 
            New-Item -Path "HKLM:SOFTWARE\Microsoft\" -Name MSSQLServer
            New-Item -Path "HKLM:SOFTWARE\Microsoft\MSSQLServer" -Name Client
            New-Item -Path "HKLM:SOFTWARE\Microsoft\MSSQLServer\Client" -Name SuperSocketNetLib
            New-Item -Path "HKLM:SOFTWARE\Microsoft\MSSQLServer\Client" -Name DB-Lib
	        New-Item -Path "HKLM:SOFTWARE\Microsoft\MSSQLServer\Client" -Name ConnectTo
        }
	    $cfg.SharePoint.Databases.Database | % { 
		    Write-Host "Creating SQL Alias - " $_.name " - that points to " $_.instance " on port " $_.port
		    $connection_string = "DBMSSOCN,{0},{1}" -f $_.instance, $_.port
		    New-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\MSSQLServer\Client\ConnectTo" -Name $_.name -PropertyTYpe string -Value $connection_string 
	    }
    }
    catch {
          throw "Error creating SQL Alias"
    }      
}

function Install-SharePointBinaries
{
    try { 
	    cd "$global:scripts_home\Install-SharePoint2013"	
	    .\Modules\Install-SharePointBits.ps1 -config $cfg.SharePoint.setup.setup_configs.$global:farm_type -setup $cfg.SharePoint.Setup.setup_path
    }
    catch {
        throw "Error installing SharePoint"
    }
}

function Setup-Farm
{
    try { 
	    $db = $cfg.SharePoint.setup.databases.$global:farm_type
	    $pass = $cfg.SharePoint.setup.security.$global:farm_type.passphrase
	    $account = $cfg.SharePoint.setup.security.$global:farm_type.farm_account
	
	    cd "$global:scripts_home\Install-SharePoint2013"
	    if( $global:server_type -eq "central-admin" -or $global:server_type -eq "all" ) {	
		    .\Modules\Create-SharePointFarm.ps1 -db $db -passphrase $pass -account $account
	    } 
	    else {
		    .\Modules\Join-SharePointFarm.ps1 -db $db -passphrase $pass
	    }
    }
    catch { 
        throw "Error creating or joining the SharePoint Farm"
    }
}

function main
{	
    if( $HOST.Version.Major -ne 3 ) {
        throw "POwerShell Version 3 is required to run these scripts"
    }

	#Start Log
	Set-ExecutionPolicy unrestricted -force
		
	try {
		Get-Variables
	}
	catch {
		Write-Error "Could not set base variables. Must exit"
		return 
	}

    if( !(Test-Path $global:log_home) ) { 
		mkdir $global:log_home
		mkdir (Join-Path $global:log_home "Trace")
		New-SmbShare -Name Logs -Path $global:log_home -ReadAccess everyone
	}

	$log = $global:log_home + "\System-Setup-" + $ENV:COMPUTERNAME + "-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".log"
	&{Trap{continue};Start-Transcript -Append -Path $log}
	
	#Steps to Setup Server 
	if( $operation -eq "all" -or $operation -eq "copy") { Copy-Files; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "base") { Setup-BaseSystem; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "iis") { Setup-IIS; $operation = "all" }
    if( $operation -eq "all" -or $operation -eq "el") {  Install-EnterpriseLibrary; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "database") { Setup-DatabaseAlias; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "sharepoint") { Install-SharePointBinaries ; $operation = "all" }
	
	Read-Host "Press any key to continue to either create or join the farm. Please remember that only one system can run config wizard at a time."
	if( $operation -eq "all" -or $operation -eq "farm") { Setup-Farm }

    if( $record ) { 
        $audit = audit-Servers -Servers . 
         WriteTo-SPListViaWebService -url $global:audit_url -list Servers -Item $(Convert-ObjectToHash $audit) -TitleField SystemName 
    } 
	Stop-Transcript
	
}
$cfg = [xml] (gc $config)
main



