function Create-EnterpriseSearch
{	
	param (
		[object] $cfg
	)
	$app_name = $cfg.Name
	$proxy_name = $cfg.Name + " Proxy"
	
	try {
		$search_app_pool = Get-SharePointApplicationPool $cfg.SearchAppPool.Name -Account $cfg.SearchAppPool.Account

		Write-Host "[ $(Get-Date) ] - Starting Search Service Instances . . . "
		Get-SPEnterpriseSearchServiceInstance -Identity $cfg.Server.Name | Start-SPEnterpriseSearchServiceInstance -Identity
		Get-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance -Identity $cfg.ServerName | Start-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance

		Write-Host "[ $(Get-Date) ] -  Creating Search Service Application and Proxy (This will take a while) . . ."
		$search_app = New-SPEnterpriseSearchServiceApplication -Name $app_name -ApplicationPool $search_app_pool -DatabaseName $cfg.Database.Name -DatabaseServer $cfg.Databse.Instance -Verbose
		New-SPEnterpriseSearchServiceApplicationProxy -Name $proxy_nmae -SearchApplication $search_app -Verbose

		Write-Host "[ $(Get-Date) ] -  Configuring Search Default Acess Account . . . "
		$search_app | Set-SPEnterpriseSearchServiceApplication `
			-DefaultContentAccessAccountName $cfg.DefaultContentAccessAccount.Name `
			-DefaultContentAccessAccountPassword $cfg.DefaultContentAccessAccount.Password

		Write-Host "[ $(Get-Date) ] -  Configuring Search Component Topology . . . "
		$clone = $search_app.ActiveTopology.Clone()
		$instance = Get-SPEnterpriseSearchServiceInstance
		New-SPEnterpriseSearchAdminComponent –SearchTopology $clone -SearchServiceInstance $instance
		New-SPEnterpriseSearchContentProcessingComponent –SearchTopology $clone -SearchServiceInstance $instance
		New-SPEnterpriseSearchAnalyticsProcessingComponent –SearchTopology $clone -SearchServiceInstance $instance 
		New-SPEnterpriseSearchCrawlComponent –SearchTopology $clone -SearchServiceInstance $instance 
		New-SPEnterpriseSearchIndexComponent –SearchTopology $clone -SearchServiceInstance $instance
		New-SPEnterpriseSearchQueryProcessingComponent –SearchTopology $clone -SearchServiceInstance $instance
		
		Write-Host "[ $(Get-Date) ] -  Activing Search Component Topology (Another Long Setup). . . "
		$clone.Activate()
		
		Write-Host "[ $(Get-Date) ] -  Publishing Search Service Application. . . "
		Publish-SPServiceApplication $search_app

		Write-Host "[ $(Get-Date) ] -  Complete. . . "
	}
	catch [System.Exception] {
		Write-Error ("The SharePoint Search Configuration failed with the following Exception - " + $_.Exception.ToString() )
	}
	
}
