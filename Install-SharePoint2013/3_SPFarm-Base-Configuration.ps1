[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[Parameter(Mandatory=$true)]
	[ValidateSet("development","qa","production","uat", "dr")]
	[string] $environment,
	[string] $config = ".\config\master_setup.xml"
)

Add-PSSnapin Microsoft.SharePoint.PowerShell –EA SilentlyContinue

$global:farm_type = $null
$global:server_type = $null

. .\Libraries\Setup_Functions.ps1

function main()
{
	$log = $cfg.SharePoint.BaseConfig.LogsHome + "\SharePoint-Farm-Confiuration-" + $ENV:COMPUTERNAME + "-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".log"
	&{Trap{continue};Start-Transcript -Append -Path $log}

	$global:farm_type = Get-FarmType
	
	Enable-WSManCredSSP -role client -delegate * -Force
	
	$sharepoint_servers = @(Get-SPServer | where { $_.Role -ne "Invalid" } | Select -Expand Address )
	$global:source = $cfg.SharePoint.Setup.master_file_location
	$cred = Get-Credential -Credential ($ENV:USERDOMAIN + "\" + $ENV:USERNAME)
	
	Write-Host "--------------------------------------------"
	Write-Host "Start SPTimer Service"
	Invoke-Command -ComputerName $sharepoint_servers -ScriptBlock { Start-Service SPTimerV4 } -Authentication Credssp -Credential $cred
	Write-Host "--------------------------------------------"
	
	Write-Host "--------------------------------------------"
	Write-Host "Configure Farm Admins"
	Config-FarmAdministrators
	Write-Host "--------------------------------------------"
	
	Write-Host "--------------------------------------------"
	Write-Host "Configure Outgoing Email"
	Config-OutgoingEmail
	Write-Host "--------------------------------------------"
	
	Write-Host "--------------------------------------------"
	Write-Host "Configure Managed Accounts"
	Config-ManagedAccounts
	Write-Host "--------------------------------------------"
	
	Write-Host "--------------------------------------------"
	Write-Host "Configure Web Services Application Pool"
	Config-WebServiceAppPool
	Write-Host "--------------------------------------------"
	
	Write-Host "--------------------------------------------"
	Write-Host "Configure State Service"
	Config-StateService
	Write-Host "--------------------------------------------"
	
	Write-Host "--------------------------------------------"
	Write-Host "Configure Secure Store"
	Config-SecureStore
	Write-Host "--------------------------------------------"

	Write-Host "--------------------------------------------"
	Write-Host "Configure Access Web Services"
	Config-AccessWebServices
	Write-Host "--------------------------------------------"
	
	Write-Host "--------------------------------------------"
	Write-Host "Configure Visio Web Service"
	Config-VisioWebServices
	Write-Host "--------------------------------------------"
	
	Write-Host "--------------------------------------------"
	Write-Host "Configure Work Management Service"
	Config-WorkManagement
	Write-Host "--------------------------------------------"
	
    Write-Host "--------------------------------------------"
    Write-Host "Configure Business Connectivity Services"
    Config-BusinessConnectivityServices
    Write-Host "--------------------------------------------"

	Write-Host "--------------------------------------------"
	Write-Host "Configure Logging"
	Config-Logging -servers $sharepoint_servers
	Write-Host "--------------------------------------------"

    Write-Host "--------------------------------------------"
	Write-Host "Configure SharePoint Apps"
	Config-SharePointApps 
	Write-Host "--------------------------------------------"
	
    Write-Host "--------------------------------------------"
	Write-Host "Configure SharePoint Distirbuted Cache"
	Config-DistributedCache 
	Write-Host "--------------------------------------------"

	Write-Host "--------------------------------------------"
	Write-Host "Configure Usage"
	Config-Usage -servers $sharepoint_servers
	Write-Host "--------------------------------------------"
	
	Write-Host "--------------------------------------------"
	Write-Host "Configure Initial Cert Exchange"
	Config-InitialPublishing 
	Write-Host "--------------------------------------------"

	Write-Host "--------------------------------------------"
	Write-Host "Configure Forms Timeout"
    Configure-SecureTokenService
    Write-Host "--------------------------------------------"

	Stop-Transcript
}
$cfg = [xml] (gc $config)
main
