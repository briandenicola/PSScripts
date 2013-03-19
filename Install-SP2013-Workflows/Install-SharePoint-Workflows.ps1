[CmdletBinding(SupportsShouldProcess=$true)]
param(
	
	[ValidateSet("all", "copy", "base", "iis", "dotnet", "farm")] [string] $operation = "all",
    [ValidateSet("create", "join")]	[string] $farm = "join",
	[switch] $record
)

ImportSystemModules
Import-Module WorkflowManager
Import-Module ServiceBus

. .\Libraries\BootStrap_Functions.ps1

#Set Variables
$cfg = [xml] ( gc ".\Configs\workflow_setup.xml")

$url = $cfg.Settings.Common.url 
$scripts_home = $cfg.Settings.Common.scripts
$utils_home = $cfg.Settings.Common.utils
$webpi = $cfg.Settings.Common.webpi
$logs_home = $cfg.Settings.Common.logs
$con = "Data Source={0};Initial Catalog={1};Integrated Security=True"


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
	
	$ver = Get-WMIObject win32_operatingSystem | Select -Expand name
	if( $ver -imatch "2008 R2" ) { 
		.\install_and_config_iis7.ps1 
	} elseif( $ver -imatch "2012" ) { 
		.\install_and_config_iis8.ps1
	} else { 
		throw "Invalid Operating System Detected . . ."
	}
}

function Setup-DotNet
{
	#Install .Net Apps
	Write-Host "[ $(Get-Date) ] - Installing Workflow Manager, Service Bus, and .Net 4.5 Framework . . ."
    &$webpi /Install /Products:WDeployNoSMO /accepteula /SuppressReboot 
    &$webpi /Install /Products:ServiceBus /accepteula /SuppressReboot 
    &$webpi /Install /Products:ServiceBusCU1 /accepteula /SuppressReboot
    &$webpi /Install /Products:WorkflowManager /accepteula /SuppressReboot 
    &$webpi /Install /Products:WorkflowCU1 /accepteula /SuppressReboot 
    &$webpi /Install /Products:WorkflowClient /accepteula /SuppressReboot 
	&$webpi /List /ListOption:Installed
}

function Update-Audit 
{
    $audit = audit-Servers -Servers $ENV:COMPUTERNAME
    WriteTo-SPListViaWebService -url $url -list AppServers -Item $(Convert-ObjectToHash $audit) -TitleField SystemName  
}

function Create-ServiceBusFarm
{
    $cert_key = ConvertTo-SecureString -AsPlainText -Force -String $cfg.Settings.ServiceBus.passphrase

    try {
        Write-Host "[ $(Get-Date) ] - Creating Service Bus Farm . . ."
        
        $sb_params = @{
            SBFarmDBConnectionString = ($con -f $cfg.Settings.ServiceBus.Database, "SbManagementDB") 
            RunAsAccount = $cfg.Settings.ServiceBus.service_account
            AdminGroup = $cfg.Settings.ServiceBus.administrators
            GatewayDBConnectionString = ($con -f $cfg.Settings.ServiceBus.Database, "SbGatewayDB")
            CertificateAutoGenerationKey = $cert_key 
            MessageContainerDBConnectionString = ($con -f $cfg.Settings.ServiceBus.Database, "SBMessageContainerDB")
        }
        New-SBFarm @sb_params -Verbose 
        
        Write-Host "[ $(Get-Date) ] - Creating Service Bus Namespace . . ."
        $ns_params = @{
            Name = $cfg.Settings.ServiceBus.name_space
            ManageUsers = $cfg.Settings.ServiceBus.users
        }
        New-SBNamespace @ns_params -Verbose

        Write-Host "[ $(Get-Date) ] - Sleeping for 90 . . ."
        Start-Sleep 90
    }
    catch {
         throw "Error creating Service Bus Farm"
    }
}

function Create-WorkflowFarm
{
    $cert_key = ConvertTo-SecureString -AsPlainText -Force -String $cfg.Workflow.passphrase

    try {
        Write-Host "[ $(Get-Date) ] - Creating Workflow Farm . . ."
        
        $wf_params = @{
            FarmMgmtDBConnectionString = ($con -f $cfg.Settings.Workflow.Database, "WFManagementDB") 
            RunAsAccount = $cfg.Workflow.service_account
            AdminGroup = $cfg.Workflow.administrators
            InstanceMgmtDBConnectionString = ($con -f $cfg.Settings.Workflow.Database, "WFInstanceManagementDB")
            ResourceMgmtDBConnectionString = ($con -f $cfg.Settings.Workflow.Database, "WFResourceManagementDB")
            CertAutoGenerationKey = $cert_key
        }
        New-WFFarm @wf_params -Verbose
    }
    catch {
         throw "Error creating Workflow Farm"
    }
}

function Join-ServiceBusFarm
{
    try {
        $cred = Get-Credential ( $cfg.Settings.ServiceBus.service_account )
        $cert_key = ConvertTo-SecureString -AsPlainText -Force -String $cfg.Settings.ServiceBus.passphrase

        Write-Host "[ $(Get-Date) ] - Joining Service Bus Farm . . ."
        $sb_params = @{
            FarmMgmtDBConnectionString  = ($con -f $cfg.Settings.ServiceBus.Database, "SbManagementDB")
            RunAsPassword = $cerd.Password
            CertAutoGenerationKey = $cert_key
        }
        Add-SBHost @sb_params -Verbose 
           
    }
    catch {
         throw "Error joining the Service Bus Farm"
    }
}

function Join-WorkflowFarm
{
    try {
        $cred = Get-Credential ( $cfg.Settings.Workflow.service_account )
        $cert_key = ConvertTo-SecureString -AsPlainText -Force -String $cfg.Settings.Workflow.passphrase

        $sb_config = Get-SBClientConfiguration -Namespace $cfg.Settings.ServiceBus.Namepase -Verbose

        Write-Host "[ $(Get-Date) ] - Joining Workflow Farm . . ."
        $wf_params = @{ 
            FarmMgmtDBConnectionString = ($con -f $cfg.Settings.Workflow.Database, "WFManagementDB")
            RunAsPassword = $cred.Password 
            SBClientConfiguration = $sb_config
            EnableHttpPort = $true
            CertAutoGenerationKey = $cert_key
        }
        Add-WFHost @wf_params -Verbose
    }
    catch {
         throw "Error joining the Workflow Farm"
    }
}

function Schedule-And-Reboot
{
    $name = "WorkflowInstall"

    $script = "cd $scripts_home\Install-SharePoint2013;"
	$script += Join-Path $PWD.Path "Install-SharePoint-Workflows.ps1"
	$script += " -operation farm"
		
	$cmd = "c:\windows\System32\WindowsPowerShell\v1.0\powershell.exe -noexit -command `"$script`""
	
    New-ItemProperty "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name $name -PropertyType string
	Set-ItemProperty "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name $name -Value $cmd
		
	Write-Host "System will reboot in 10 seconds"
	Start-Sleep 10
	Restart-Computer -Force -Confirm:$true
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
	
    if( $operation -eq "all" -or $operation -eq "dotnet" ) { 
        Setup-DotNet
        Schedule-And-Reboot
    }
	
    if( $farm -eq "create" ) { 
        Create-ServiceFarm 
        Create-WorkflowFarm
    }
    Join-ServiceBusFarm
	Join-WorkflowFarm 
	
    if( $record ) { Update-Audit } 
	Stop-Transcript
	
}
main