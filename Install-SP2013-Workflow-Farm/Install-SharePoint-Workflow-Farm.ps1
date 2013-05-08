[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[ValidateSet("all", "copy", "base", "iis", "dotnet", "farm")] [string] $operation = "all",
    [ValidateSet("create", "join")]	[string] $farm = "join",
	[switch] $record
)

ImportSystemModules
Import-Module WorkflowManager -ErrorAction SilentlyContinue
Import-Module ServiceBus -ErrorAction SilentlyContinue

. .\Libraries\BootStrap_Functions.ps1

#Set Variables
$cfg = [xml] ( gc ".\Configs\workflow_setup.xml")

$url = $cfg.Settings.Common.url 
$source = $cfg.Settings.Common.Source
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
    WriteTo-SPListViaWebService -url $url -list Servers -Item $(Convert-ObjectToHash $audit) -TitleField SystemName  
}

function Create-ServiceBusFarm
{
    try {
        Write-Host "[ $(Get-Date) ] - Creating Service Bus Farm . . ."
        
        $sb_params = @{
            SBFarmDBConnectionString = ($con -f $cfg.Settings.ServiceBus.Database, "SbManagementDB") 
            RunAsAccount = $cfg.Settings.ServiceBus.service_account
            AdminGroup = $cfg.Settings.ServiceBus.administrators
            GatewayDBConnectionString = ($con -f $cfg.Settings.ServiceBus.Database, "SbGatewayDB")
            MessageContainerDBConnectionString = ($con -f $cfg.Settings.ServiceBus.Database, "SBMessageContainerDB")
        }

        if( $cfg.Settings.ServiceBus.Certs.Auto -eq $true ) {
            $cert_key = ConvertTo-SecureString -AsPlainText -Force -String $cfg.Settings.ServiceBus.Certs.passphrase
            $sb_params.Add('CertificateAutoGenerationKey', $cert_key )
        }
        else {
            $thumbprint = Get-Cert-Thumbprint $cfg.Settings.ServiceBus.Certs.Subject
            $sb_params.Add('EncryptionCertificateThumbprint', $thumbprint)
            $sb_params.Add('FarmCertificateThumbprint', $thumbprint)
        }
        New-SBFarm @sb_params -Verbose 
        
    }
    catch {
         throw ( "Error creating Service Bus Farm with " + $_.Exception.ToString() )
    }
}

function Create-WorkflowFarm
{
    try {
        Write-Host "[ $(Get-Date) ] - Creating Workflow Farm . . ."
        
        $wf_params = @{
            WFFarmDBConnectionString = ($con -f $cfg.Settings.Workflow.Database, "WFManagementDB") 
            RunAsAccount = $cfg.Settings.Workflow.service_account
            AdminGroup = $cfg.Settings.Workflow.administrators
            InstanceDBConnectionString = ($con -f $cfg.Settings.Workflow.Database, "WFInstanceManagementDB")
            ResourceDBConnectionString = ($con -f $cfg.Settings.Workflow.Database, "WFResourceManagementDB")
        }
        if( $cfg.Settings.Workflow.Certs.Auto -eq $true ) {
            $cert_key = ConvertTo-SecureString -AsPlainText -Force -String $cfg.Settings.Workflow.Certs.passphrase
            $wf_params.Add('CertificateAutoGenerationKey', $cert_key )
        }
        else {
            $thumbprint = Get-Cert-Thumbprint $cfg.Settings.Workflow.Certs.Subject
            $wf_params.Add('EncryptionCertificateThumbprint', $thumbprint)
            $wf_params.Add('SslCertificateThumbprint', $thumbprint)
            $wf_params.Add('OutboundCertificateThumbprint', $thumbprint)
        }
        New-WFFarm @wf_params -Verbose
    }
    catch {
         throw ( "Error creating Workflow Farm with " + $_.Exception.ToString() )
    }
}

function Join-ServiceBusFarm
{
    try {
        $cred = Get-Credential ( $cfg.Settings.ServiceBus.service_account )

        Write-Host "[ $(Get-Date) ] - Joining Service Bus Farm . . ."
        $sb_params = @{
            SBFarmDBConnectionString = ($con -f $cfg.Settings.ServiceBus.Database, "SbManagementDB")
            RunAsPassword = $cred.Password
            EnableFirewallRules = $true
        }
        if( $cfg.Settings.ServiceBus.Certs.Auto -eq $true ) {
            $cert_key = ConvertTo-SecureString -AsPlainText -Force -String $cfg.Settings.ServiceBus.Certs.passphrase
            $sb_params.Add('CertificateAutoGenerationKey', $cert_key )
        }
        Add-SBHost @sb_params -Verbose 
           
        Get-SBNameSpace  -Name $cfg.Settings.ServiceBus.name_space -EA SilentlyContinue
        if( !$? ) {
            Write-Host "[ $(Get-Date) ] - Creating Service Bus Namespace . . ."
            $ns_params = @{
                Name = $cfg.Settings.ServiceBus.name_space
                ManageUsers = $cfg.Settings.ServiceBus.users
            }
            New-SBNamespace @ns_params -Verbose

            Write-Host "[ $(Get-Date) ] - Sleeping for 90 . . ."
            Start-Sleep 90
        }
    }
    catch {
            throw ( "Error joining the Service Bus Farm with " + $_.Exception.ToString() )
    }
}

function Join-WorkflowFarm
{
    try {
        $cred = Get-Credential ( $cfg.Settings.Workflow.service_account )
        $sb_config = Get-SBClientConfiguration -Namespace $cfg.Settings.ServiceBus.Name_space -Verbose

        Write-Host "[ $(Get-Date) ] - Joining Workflow Farm . . ."
        $wf_params = @{ 
            WFFarmDBConnectionString = ($con -f $cfg.Settings.Workflow.Database, "WFManagementDB")
            RunAsPassword = $cred.Password 
            SBClientConfiguration = $sb_config
            EnableHttpPort = $false
            EnableFirewallRules = $true
        }
        if( $cfg.Settings.Workflow.Certs.Auto -eq $true ) {
            $cert_key = ConvertTo-SecureString -AsPlainText -Force -String $cfg.Settings.Workflow.Certs.passphrase
            $wf_params.Add('CertificateAutoGenerationKey', $cert_key )
        }
        Add-WFHost @wf_params -Verbose
    }
    catch {
         throw ( "Error joining the Workflow Farm with " + $_.Exception.ToString() )
    }
}

function main
{	
	Set-ExecutionPolicy unrestricted -force
	if( !(Test-Path $logs_home) ) { 
		mkdir $logs_home
		mkdir (Join-Path $logs_home "Trace")
        New-SmbShare -Name Logs -Path $logs_home -ReadAccess everyone
	}
	
	$log = ".\Logs\System-Setup-" + $ENV:COMPUTERNAME + "-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".log"
	&{Trap{continue};Start-Transcript -Append -Path $log}
        
	if( $operation -eq "all" -or $operation -eq "copy" ) { Copy-Files; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "base" ) { Setup-Base; $operation = "all" }
	if( $operation -eq "all" -or $operation -eq "iis" ) { Setup-IIS; $operation = "all" }
	
    if( $operation -eq "all" -or $operation -eq "dotnet" ) { 
        Setup-DotNet
        Write-Host "[ $(Get-Date) ] - Installation is Complete but now Powershell must be relaunched to load the proper modules . . ."
        Write-Host "[ $(Get-Date) ] - Please launch Powershell as Administrator and start the with $($MyInvocation.InvocationName) -operation farm -farm $farm . . . ." 
        return $?
    }
	
    if( $operation -eq "farm" ) {
        if( $farm -eq "create" ) { 
            Create-ServiceBusFarm 
            Create-WorkflowFarm
        }
        Join-ServiceBusFarm
	    Join-WorkflowFarm 
	}

    if( $record ) { Update-Audit } 
	Stop-Transcript
	
}
main