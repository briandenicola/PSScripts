Set-Varaible -Name check_search_topology_sb -Value ( [ScriptBlock] {
	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
	
	$search_service_app =  Get-SPServiceApplication | where { $_.TypeName -eq "Search Service Application" } 
	
	$query_topology = $search_service_app | Get-SPEnterpriseSearchQueryTopology | 
		Where { $_.State -eq "Active" } | 
		Select -Expand QueryComponents | 
		Select ServerName, State, IndexLocation
		
	$crawl_topology = $search_service_app | Get-SPEnterpriseSearchCrawlTopology | 
		Where { $_.State -eq "Active" } | 
		Select -Expand CrawlComponents | 
		Select ServerName, State, IndexLocation

	$source = $search_service_app | Get-SPEnterpriseSearchCrawlContentSource
		Select CrawlState, DeleteCount, ErrorCount, LevelHighErrorCount, SuccessCount, FullCrawlSchedule, IncrementalCrawlSchedule, StartAddress, CrawlStarted
		
	$full_crawl_schedule = $source | Select -Expand FullCrawlSchedule | Select Description, NextRunTime
	$incr_crawl_schedule = $source | Select -Expand IncrementalCrawlSchedule | Select Description, NextRunTime

	$property_db = $search_service_app | Get-SPEnterpriseSearchPropertyDatabase | Select Name, DatabaseConnectionString, IsDedicated
	$crawl_db = $search_service_app | Get-SPEnterpriseSearchCrawlDatabase | Select Name, DatabaseConnectionString, IsDedicated

	return ( New-Object PSObject -Property @{
		QueryTopology = $query_topology
		CrawlTopology = $crawl_topology
		ContentSource = $source
		FullSchedule = $full_crawl_schedule
		IncrementalSchedule = $incr_crawl_schedule
		PropertyDb = $property_db
		CrawlDb = $crawl_db
	})
})