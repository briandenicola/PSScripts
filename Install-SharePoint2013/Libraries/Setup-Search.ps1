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
