[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[string]
	$config = ".\config\master_setup.xml"
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

function Setup-BaseSystem
{
	#Setup Sysem
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

function main
{	
    if( $HOST.Version.Major -ne 3 ) {
        throw "POwerShell Version 3 is required to run these scripts"
    }
	
	try {
		Get-Variables
	}
	catch {
		Write-Error "Could not set base variables. Must exit"
		return 
	}

	$log = $global:log_home + "\System-Setup-" + $ENV:COMPUTERNAME + "-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".log"
	&{Trap{continue};Start-Transcript -Append -Path $log}
	
	#Steps to Setup Server 
	Setup-BaseSystem
	Setup-DatabaseAlias
	Stop-Transcript
}
$cfg = [xml] (gc $config)
main



