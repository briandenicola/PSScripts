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
	if( $w -eq $null ) {
		$acc = Get-SPManagedAccount $cfg.MySite.AppPool.account -EA SilentlyContinue
		if( $acc -eq $nul ) {
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