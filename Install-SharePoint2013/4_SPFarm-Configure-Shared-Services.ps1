[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[string] $config
)

Add-PSSnapin Microsoft.SharePoint.PowerShell –erroraction SilentlyContinue
. .\libraries\Standard_Functions.ps1

function HashTable_Output( [HashTable] $ht )
{
	$ht.Keys | % { $output += $_ + ":" + $ht[$_] + "," }
	return $output.TrimEnd(",")
}

function Get-SharePointApplicationPool
{
	param (
		[string] $name,
		[string] $account
	
	)
	
	Write-Host "[$(Get-Date)] - Attempting to Get Service Application Pool " $name
 	$pool = Get-SPServiceApplicationPool $name
	if( $pool -eq $nul )
	{
		Write-Host "[$(Get-Date)] - Could not find Application Pool - " $name " - therefore creating new pool"
		if ( (Get-SPManagedAccount | where { $_.UserName -eq $account } ) -eq $nul )
		{
			$cred = Get-Credential $account
			New-SPManagedAccount $cred -verbose
		}
		$pool = New-SPServiceApplicationPool -name $name -account $account
	}
	return $pool
}
	
function Create-ManagedMetadata
{
	param (
		[object] $cfg
	)
	$proxy_name = $cfg.Name + " Proxy"
	
	# Start Services
	$cfg.Servers.Server.Name | % { 
		Write-Host "[$(Get-Date)] - Attempting to start Managed Metadata on " $_
		Get-SPServiceInstance -Server $_ | where { $_.TypeName -eq "Managed Metadata Web Service" } | Start-SPServiceInstance 
	}

	# Create Application Pool
	$pool = Get-SharePointApplicationPool -name $cfg.AppPool.name -account $cfg.AppPool.account

	$params = @{
		Name = $cfg.Name
		ApplicationPool = $pool
		DatabaseServer = $cfg.Databases.Database.instance
		DatabaseName = $cfg.Databases.Database.name
		AdministratorAccount = $cfg.Administrators
	}
	
	Write-Host "[$(Get-Date)] - Attempting to create Managed Metadata Service Application with the following parameters - "  (HashTable_Output $params)
	$app = New-SPMetadataServiceApplication @params -verbose
	New-SPMetadataServiceApplicationProxy -Name $proxy_name -ServiceApplication $app -DefaultProxyGroup
	Publish-SPServiceApplication $app
}

function Create-UserProfile
{
	param (
		[object] $cfg
	)
	$proxy_name = $cfg.Name + " Proxy"
	
	Write-Host "[$(Get-Date)] - Attempting to start User Profile on " $cfg.Server.Name 
	

	#Start the UPS Instance and Setup Access
	$farmAccount = (get-SPFarm).DefaultServiceAccount
	$cred = Get-Credential $farmAccount.Name
	
	Get-SPServiceInstance -Server $cfg.Server.Name | where { $_.TypeName -eq "User Profile Service" } | Start-SPServiceInstance 
	Invoke-Command -ComputerName $cfg.Server.Name -ScriptBlock { 
		param ( [string] $user )
		net localgroup administrators $user /add
		Restart-Service SPTimerV4 -Verbose
		iisreset
	} -ArgumentList $farmAccount.Name
	
	#Create Application Pool
	$pool = Get-SharePointApplicationPool -name $cfg.AppPool.name -account $cfg.AppPool.account

	# Get or Create MySite Web Application
	$w = Get-SPWebApplication $cfg.MySite.name -EA SilentlyContinue
	if( $w -eq $null )
	{
		$acc = Get-SPManagedAccount $cfg.MySite.AppPool.account -EA SilentlyContinue
		if( $acc -eq $nul )
		{
			$cred = Get-Credential $cfg.MySite.AppPool.account
			New-SPManagedAccount $cred -verbose 
			$acc = Get-SPManagedAccount $cfg.MySite.AppPool.account
		}

		$my_site_params = @{
			Name = $cfg.MySite.Name
			Port = 80
			HostHeader = $cfg.MySite.HostHeader
			URL = "http://" + $cfg.MySite.HostHeader
			DatabaseName = $cfg.MySite.DatabaseName
			DatabaseServer = $cfg.MySite.DatabaseServer
			ApplicationPool = "AppPool - " +  $cfg.MySite.HostHeader
			ApplicationPoolAccount = $acc
		}
		Write-Host "[$(Get-Date)] - Attempting to create the MySite Web Application with the following parameters - "  (HashTable_Output $my_site_params)
		$web_app = New-SPWebApplication @my_site_params -verbose

		#Create MySite Host Site Collection
		New-SPSite -url ("http://" + $cfg.MySite.HostHeader + "/" ) -OwnerAlias $farmAccount.Name -SecondaryOwnerAlias $cfg.AppPool.account -Template SPSMSITEHOST

		#Create Managed Path
		New-SPManagedPath -RelativeURL $cfg.MySite.path -WebApplication $web_app
	}
	
	$profile_db = $cfg.Databases.Database | where { $_.Type -eq "Profile" }
	$sync_db = $cfg.Databases.Database | where { $_.Type -eq "Sync" }
	$social_db = $cfg.Databases.Database | where { $_.Type -eq "Social" }

	#Create Service Application
	$params = @{
		Name = $cfg.Name
		ApplicationPool = $pool.id
		MySiteHostLocation = "http://" + $cfg.MySite.HostHeader
		MySiteManagedPath = $cfg.MySite.path
		SiteNaming = "Resolve"
		ProfileDBName = $profile_db.name
		ProfileDBServer = $profile_db.instance
		ProfileSyncDBName = $sync_db.name
		ProfileSyncDBServer = $sync_db.instance
		SocialDBName = $social_db.name
		SocialDBServer = $social_db.instance
	}
	
	Write-Host "[$(Get-Date)] - Attempting to create User Profile Service Application with the following parameters - "  (HashTable_Output $params)

	$sb = { 
		param (
			[Object] $params
		)

		Add-PSSnapin Microsoft.SharePoint.PowerShell –erroraction SilentlyContinue
		New-SPProfileServiceApplication @params -Verbose
	} 
	$job = Start-Job -ScriptBlock $sb -Credential $cred -ArgumentList $params
	$job | Wait-Job | Receive-Job
	
	#Create Service Proxy
	$app = Get-SPServiceApplication | where { $_.Name -eq $cfg.Name }
	New-SPProfileServiceApplicationProxy -Name $proxy_name -ServiceApplication $app -DefaultProxyGroup
	Publish-SPServiceApplication $app
	
	#Start Timer Job
	Get-SPTimerJob | where { $_.Name -like "*ActivityFeedJob" } | Enable-SPTimerJob
}

function Create-EnterpriseSearch
{	
	param (
		[object] $cfg
	)
	$proxy_name = $cfg.Name + " Proxy"

	if( -not (Test-Path $cfg.IndexLocation ) )
	{
		mkdir $cfg.IndexLocation
	}

	Write-Host "[$(Get-Date)] - Attempting to start Enterprise Search Service on " $cfg.Server.Name 
	$svc = Get-SPEnterpriseSearchServiceInstance -Identity $cfg.Server.Name 
	$svc | Start-SPServiceInstance 
	$svc | Set-SPEnterpriseSearchServiceInstance -DefaultIndexLocation $cfg.IndexLocation
	
	$search_setup_params = @{
		ServiceAccount = $cfg.SearchAccessAccount.name
		ServicePassword = (ConvertTo-SecureString $cfg.SearchAccessAccount.password -asplaintext -force)
		ContactEmail = $cfg.Email
		ConnectionTimeout = 60
		AcknowledgementTimeout = 60
		ProxyType = "Default"
		IgnoreSSLWarnings = $false
		InternetIdentity = $null
		PerformanceLevel = $cfg.PerformanceLevel
	}
	$search_svc = Get-SPEnterpriseSearchService
	$search_svc | Set-SPEnterpriseSearchService @search_setup_params

	# Setup Enterprise Application
	$svc_pool = Get-SharePointApplicationPool -name $cfg.SearchAppPool.name -account $cfg.SearchAppPool.account
	$adm_pool = Get-SharePointApplicationPool -name $cfg.AdminAppPool.name -account $cfg.AdminAppPool.account

	$enterprise_search_app_params = @{
		Name = $cfg.Name
    	DatabaseServer = $cfg.Database.Instance 
		DatabaseName = $cfg.Database.Name 
		ApplicationPool = $svc_pool
		AdminApplicationPool = $adm_pool
	}
	Write-Host "[$(Get-Date)] - Attempting to create Enterprise Service Application with the following parameters - "  (HashTable_Output $enterprise_search_app_params)
	$app = New-SPEnterpriseSearchServiceApplication @enterprise_search_app_params -verbose
		
	# Create Administration Component
	Set-SPEnterpriseSearchAdministrationComponent -SearchApplication $app -SearchServiceInstance $svc
	do {
		Write-Host "." -NoNewline
  		Start-Sleep 5
		$admin_component = $app | Get-SPEnterpriseSearchAdministrationComponent
	} while ($admin_component.Initialized -ne $true)
	
	$app | Set-SPEnterpriseSearchServiceApplication `
		-DefaultContentAccessAccountName $cfg.DefaultContentAccessAccount.name `
		-DefaultContentAccessAccountPassword (ConvertTo-SecureString $cfg.DefaultContentAccessAccount.password -asplaintext -force)
		
	Start-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance -Identity $cfg.Server.Name

	Write-Host "[$(Get-Date)] - Attempting to create Enterprise Service Application Crawl Topology"
	$crawl = $app | New-SPEnterpriseSearchCrawlTopology
	$crawl_db = $app | Get-SPEnterpriseSearchCrawlDatabase
	New-SPEnterpriseSearchCrawlComponent -CrawlTopology $crawl -CrawlDatabase $crawl_db -SearchServiceInstance $svc
	
	$crawl | Set-SPEnterpriseSearchCrawlTopology -Active
	do {
		Write-Host "." -NoNewline
  		Start-Sleep 5
		$crawl = $app | Get-SPEnterpriseSearchCrawlTopology $crawl
	} while ($crawl.State -ne "Active" )
	$app | Get-SPEnterpriseSearchCrawlTopology | where { $_.State -eq "Inactive" } | Remove-SPEnterpriseSearchCrawlTopology -Confirm:$false
	
	Write-Host "[$(Get-Date)] - Attempting to create Enterprise Service Application Query Topology"
	$query = $app | New-SPEnterpriseSearchQueryTopology -Partitions 1
	$partition = ($query | Get-SPEnterpriseSearchIndexPartition)
	New-SPEnterpriseSearchQueryComponent -IndexPartition $partition -QueryTopology $query -SearchServiceInstance $svc

	Start-Sleep -Seconds 300

	$prop_store = $app.PropertyStores | Select Id
	$prop_db = $app.PropertyStores.Item($prop_store.id)
	$partition  | Set-SPEnterpriseSearchIndexPartition -PropertyDatabase $prop_db

	$query | Set-SPEnterpriseSearchQueryTopology -Active
	do {
		Write-Host "." -NoNewline
  		Start-Sleep 5
		$query = $app | Get-SPEnterpriseSearchQueryTopology $query
	} while ( $query.State -ne "Active" )
	$app | Get-SPEnterpriseSearchQueryTopology | where { $_.State -eq "Inactive" } | Remove-SPEnterpriseSearchQueryTopology -Confirm:$false

	# Setup Proxy
	New-SPEnterpriseSearchServiceApplicationProxy -Name $proxy_name -SearchApplication $app -Partitioned:$true
	Publish-SPServiceApplication $app
	
}

function main()
{
	$log = "D:\Logs\Farm-Shared-Service-Application-Setup-" + $ENV:COMPUTERNAME + "-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".log"
	Start-Transcript -Append -Path $log

	$metadata_cfg = $cfg.SharePoint.SharedServices.Service | where { $_.App -eq "Metadata" }
	if( $metadata_cfg -ne $null )
	{
		Write-Host "--------------------------------------------"
		Write-Host "Create Managed Metadata Service Application"
		Create-ManagedMetadata -cfg $metadata_cfg
		Write-Host "--------------------------------------------"
	}
	
	$search_cfg = $cfg.SharePoint.SharedServices.Service | where { $_.App -eq "EnterpriseSearch" }
	if( $search_cfg -ne $null )
	{	
		Write-Host "--------------------------------------------"
		Write-Host "Create Enterprise Search Service Application"
		Write-Host "`t Note: This script only creates the shell of Enterprise Search on one Search Server"
		Write-Host "`t The Following requires manual work: "
		Write-Host "`t 1.) Content Sources"
		Write-Host "`t 2.) Crawl Schedules"
		Write-Host "`t 3.) Any Advanced Search Topology such as multiple crawlers, query servers, and/or partitions"
		Create-EnterpriseSearch -cfg $search_cfg
		Write-Host "--------------------------------------------"
	}
	
	$user_profile_cfg = $cfg.SharePoint.SharedServices.Service | where { $_.App -eq "UserProfile" }
	if( $user_profile_cfg -ne $null )
	{
		Write-Host "--------------------------------------------"
		Write-Host "Create User Profile Service Application"
		Write-Host "`t Note: This script only creates the shell of the User Profile."
		Write-Host "`t The following requires manual work: "
		Write-Host "`t 1.) Start the User Profile Synchronization Service"
		Write-Host "`t 2.) Setup a connection to Active Directory "
		Write-Host "`t 3.) Setup a Synchronization Schedule"
		Write-Host "`t 4.) Setup Profile Filters"
		Create-UserProfile -cfg $user_profile_cfg
		Write-Host "--------------------------------------------"
	}	
	Stop-Transcript
}
$cfg = [xml] (gc $config)
main
