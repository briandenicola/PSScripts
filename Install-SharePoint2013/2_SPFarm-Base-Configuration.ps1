[CmdletBinding(SupportsShouldProcess=$true)]
param (
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
	
	$sharepoint_servers = @( Get-SPServer | where { $_.Role -ne "Invalid" } | Select -Expand Address )
	$cred = Get-Credential -Credential ($ENV:USERDOMAIN + "\" + $ENV:USERNAME)
	
	Write-Host "[ $(Get-Date) ] - Start SPTimer Service"
    Start-Service SPTimerV4 -Verbose
    if( $sharepoint_servers.Length -gt 1 ) {
        $systems = $sharepoint_servers | ? { $_ -inotmatch $ENV:COMPUTERNAME }
        if( $systems -ne $null ) {
	        Invoke-Command -ComputerName $systems -ScriptBlock { Start-Service SPTimerV4 -Verbose } 
        }
    }
	
    Write-Host "[ $(Get-Date) ] - Configuring Required Parts of SharePoint"
    Write-Host "[ $(Get-Date) ] - Configuring Required Services for a Web Front End Server"
    Configure-WFE-Roles

    Write-Host "[ $(Get-Date) ] - Configuring Required Services for the Central Admin Server"
	Configure-CentralAdmin-Roles -type $global:farm_type 

	Write-Host "[ $(Get-Date) ] - Configure Farm Admins"
	Config-FarmAdministrators
	
	Write-Host "[ $(Get-Date) ] - Configure Outgoing Email"
	Config-OutgoingEmail
	
    Write-Host "[ $(Get-Date) ] - Configure Managed Accounts"
	Config-ManagedAccounts

	Write-Host "[ $(Get-Date) ] - Configure Usage"
	Config-Usage -servers $sharepoint_servers

	Write-Host "[ $(Get-Date) ] - Configure Initial Cert Exchange"
	Config-InitialPublishing 

	Write-Host "[ $(Get-Date) ] - Configure Forms Timeout"
    Configure-SecureTokenService

	Write-Host "[ $(Get-Date) ] - Configure Web Services Application Pool"
	Config-WebServiceAppPool

	Write-Host "[ $(Get-Date) ] - Configure Logging"
	Config-Logging -servers $sharepoint_servers

    Write-Host "[ $(Get-Date) ] -------------------------------------------------------------"
    Write-Host "[ $(Get-Date) ] - Configuring Service Applications"

    if( $cfg.SharePoint.Setup.Services.State -eq "Enable" ) {
	    Write-Host "[ $(Get-Date) ] - Configure State Service"
	    Config-StateService
    }

    if( $cfg.SharePoint.Setup.Services.SecureStore -eq "Enable" ) {
	    Write-Host "[ $(Get-Date) ] - Configure Secure Store"
	    Config-SecureStore
    }

    if( $cfg.SharePoint.Setup.Services.Access -eq "Enable" ) {
	    Write-Host "[ $(Get-Date) ] - Configure Access Web Services"
	    Config-AccessWebServices
    }

    if( $cfg.SharePoint.Setup.Services.Visio -eq "Enable" ) {
	    Write-Host "[ $(Get-Date) ] - Configure Visio Web Service"
	    Config-VisioWebServices 
	}

    if( $cfg.SharePoint.Setup.Services.WorkMgmt -eq "Enable" ) {
	    Write-Host "[ $(Get-Date) ] - Configure Work Management Service"
	    Config-WorkManagement 
    }

    if( $cfg.SharePoint.Setup.Services.App -eq "Enable" ) {
	    Write-Host "[ $(Get-Date) ] - Configure SharePoint Apps"
	    Config-SharePointApps
    }

    if( $cfg.SharePoint.Setup.Services.Cache -eq "Enable" ) {
	    Write-Host "[ $(Get-Date) ] - Configure SharePoint Distirbuted Cache"
	    Config-DistributedCache 
    }

	Stop-Transcript
}
$cfg = [xml] (gc $config)
main