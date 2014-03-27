$global:sharepoint_wfe_severs = [String]::Empty
Add-PSSnapin Microsoft.SharePoint.PowerShell –EA SilentlyContinue

function HashTable_Output( [HashTable] $ht )
{
	$ht.Keys | % { $output += $_ + ":" + $ht[$_] + "," }
	return $output.TrimEnd(",")
}

function Configure-CentralAdmin-Roles
{
	$ca_roles = @(
		"Microsoft SharePoint Foundation Incoming E-Mail",
		"Microsoft SharePoint Foundation Web Application",
		"Claims to Windows Token Service" 
    )
	
    $type = "Central Administration"
    $ca_servers = @( Get-SPServiceInstance | where { $_.TypeName -eq $type -and $_.Status -eq "Online" } | Select -Expand Server | Select -Expand Address )

    foreach( $server in $ca_servers ) {
	    Write-Host "Working on $server . . ."
		
        foreach( $start_app in $ca_roles ) {
	        $Guid = Get-SPServiceInstance -Server $server  | where {$_.TypeName -eq $start_app} | Select -Expand Id
            if( $Guid -ne $null ) {
		        Start-SPServiceInstance -Identity $Guid
		    }
		    else { 
			    Write-Error "Could not find $start_app on $server . . . "
    	    }
        }
	}

}

function Get-FarmWebServers
{
    if( $global:sharepoint_wfe_severs -eq  [String]::Empty ) {
        $type = "Microsoft SharePoint Foundation Web Application"
        $global:sharepoint_wfe_severs = Get-SPServiceInstance | where { $_.TypeName -eq $type -and $_.Status -eq "Online" } | Select -Expand Server | Select -Expand Address
    }

    return @( $global:sharepoint_wfe_severs )
}

function Configure-WFE-Roles
{
    $servers = Get-FarmWebServers

	$wfe_roles = @(
		"Microsoft SharePoint Foundation Sandboxed Code Service",
		"Claims to Windows Token Service",
        "Request Management"
    )
		
	foreach( $server in $servers ) {
		Write-Host "Working on $server . . ."	
		
		foreach( $start_app in $wfe_roles )	{
			$Guid = Get-SPServiceInstance -Server $server  | where {$_.TypeName -eq $start_app} | Select -Expand Id
            if( $Guid -ne $null ) {
			    Start-SPServiceInstance -Identity $Guid
			}
			else { 
				Write-Error "Could not find $start_app on $server . . . "
			}
		}
				
		$stop_app = "Microsoft SharePoint Foundation Incoming E-Mail"
		$Guid = Get-SPServiceInstance -Server $server  | where {$_.TypeName -eq $stop_app} | Select -Expand Id
        if( $Guid -ne $null ) {
		    Stop-SPServiceInstance -Identity $Guid -Confirm:$false
		}
		else { 
			Write-Error "Could not find $stop_app on $server . . . "
		}
	}
}

function Get-SharePointApplicationPool
{
	param (
		[string] $name,
		[string] $account
	)
	
	Write-Host "[ $(Get-Date) ] - Attempting to Get Service Application Pool -  $name"
 	$pool = Get-SPServiceApplicationPool $name -EA SilentlyContinue
	if( $pool -eq $nul ) {
		Write-Host "[ $(Get-Date) ] - Could not find Application Pool - $name - therefore creating new pool"
		if ( (Get-SPManagedAccount | where { $_.UserName -eq $account } ) -eq $nul ) {
			$cred = Get-Credential $account
			New-SPManagedAccount $cred -verbose
		}
		$pool = New-SPServiceApplicationPool -name $name -account $account
	}
	return $pool
}

function Get-FarmType
{
	$xpath = "/SharePoint/Farms/farm/server[@name='" + $ENV:COMPUTERNAME.ToLower() + "']"
	$global:farm_type = (Select-Xml -xpath $xpath  $cfg | Select @{Name="Farm";Expression={$_.Node.ParentNode.name}}).Farm
	
	if( $global:farm_type -ne $null ) {
		Write-Host "[ $(Get-Date) ] - Found $ENV:COMPUTERNAME in $global:farm_type Farm Configuration"
	}
	else {
		throw  "Could not find $ENV:COMPUTERNAME in configuration. Must exit"
	}

    return $global:farm_type
}

function Config-FarmAdministrators 
{
	$web = Get-SPWeb ("http://" + $env:COMPUTERNAME + ":10000")

	$farm_admins = $web.SiteGroups["Farm Administrators"]
	$current_admins =  $farm_admins.Users | Select -Expand UserLogin

	$cfg.SharePoint.FarmAdministrators.add | % { 
		Write-Host "[ $(Get-Date) ] - Adding $($_.group) to the Farm Administrators group . . ."

        if( $current_admins -notcontains $_.group ) {
		    $user = New-SPUser -UserAlias $_.group -Web $web
		    $farm_admins.AddUser($user, [String]::Empty,[String]::Empty,[String]::Empty)
		
		    Add-SPShellAdmin $_.group
        }
	}
	
	$cfg.SharePoint.FarmAdministrators.remove | % { 
		$group = $_.group

		Write-Host "[ $(Get-Date) ] - Removing $($_.group) to the Farm Administrators group . . ."
		$user = Get-SPUser -Web $web -Group "Farm Administrators" | Where { $_.Name.ToLower() -eq $group }

		$farm_admins.RemoveUser($user)
	}
	$web.Dispose()
	
	Get-SPShellAdmin
	
}

function Config-HealthRules
{
    $rules = @( "AppServerDrivesAreNearlyFull" )
    
    foreach( $rule in $rules ) {
        Get-SPHealthAnalysisRule $rule | Disable-SPHealthAnalysisRule
    }
}

function Config-TimerJobs
{
    $jobs = @( "job-diagnostics-blocking-query-provider",
        "job-diagnostics-site-size-provider",
        "job-diagnostics-performance-counter-wfe-provider",
        "job-diagnostics-sql-memory-provider",
        "job-diagnostics-io-intensive-query-provider",
        "job-diagnostics-performance-metric-provider",
        "job-diagnostics-sql-performance-metric-provider",
        "job-diagnostics-sql-blocking-report-provider"
    )
    
    foreach( $job in $jobs ) {
        Get-SPTImerJob $job | Enable-SPTimerJob
    }
}

function Config-ManagedAccounts
{

	$cfg.SharePoint.managedaccounts.account | where { $_.farm -match $global:farm_type } | % { 
        Write-Host "[ $(Get-Date) ] - Add $($_.username) as a Managed Service Account . . ."
		$cred = Get-Credential $_.username
		New-SPManagedAccount $cred -verbose
	}
}

function Config-Logging 
{
    param(
        [String[]] $servers
    )

	foreach( $server in $servers ) {
		$path = $cfg.SharePoint.Logging.Path.Replace( "d:\", ("\\" + $server + "\d$\") )
		if( -not ( Test-Path $path ) )	{
			mkdir $path -verbose
		}
	}
	
	$LogConfig = @{
		LogMaxDiskSpaceUsageEnabled = $true
		ErrorReportingEnabled = $false
		EventLogFloodProtectionEnabled = $true
		LogCutInterval = $cfg.SharePoint.Logging.CutInterval
		LogDiskSpaceUsageGB = $cfg.SharePoint.Logging.MaxDiskSpace
		LogLocation = $cfg.SharePoint.Logging.Path
		DaysToKeepLogs = $cfg.SharePoint.Logging.DaysToKeep
	}
	Set-SPDiagnosticConfig @LogConfig -verbose
	
}

function Config-Usage 
{
    param(
        [String[]] $servers
    )
 
	foreach( $server in $servers ) {
		$path = $cfg.SharePoint.Usage.Path.Replace( "d:\", "\\" + $server + "\d$\" )
		if( -not ( Test-Path $path ) )	{
			mkdir $path -verbose
		}
	}
	
	$UsageConfig = @{
		UsageLogLocation = $cfg.SharePoint.Usage.Path
		UsageLogMaxSpaceGB = $cfg.SharePoint.Usage.MaxDiskSpace
		LoggingEnabled = $true
	}

	Set-SPUsageService @UsageConfig -Verbose

	$db_server = (Get-SPDatabase | where { $_.TypeName -eq "Configuration Database"} | Select @{Name="SystemName";Expression={$_.Server.Address}}).SystemName
	New-SPUsageApplication -Name "WSS_UsageApplication" -DatabaseServer $db_server -DatabaseName $cfg.SharePoint.Usage.Database
	$usage = Get-SPServiceApplicationProxy | Where { $_.TypeName -eq "Usage and Health Data Collection Proxy"}
	$usage.Provision()

	Write-Host "************************************************************************"  -foreground green
	Write-Host "Due to a limitation in the PowerShell API, in order complete the Health Usage Configuration" -foreground green
	Write-Host "Please go to - http://$($env:COMPUTERNAME):10000/_admin/LogUsage.aspx and "  -foreground green
	Write-Host "Select the check box next to `'Enable health data collection`'" -foreground green
	Write-Host "************************************************************************"  -foreground green
}

function Config-OutgoingEmail
{
	$central_admin = Get-SPwebApplication -includecentraladministration | where {$_.IsAdministrationWebApplication}
 	$central_admin.UpdateMailSettings($cfg.SharePoint.Email.Outgoing.Server, $cfg.SharePoint.Email.Outgoing.Address, $cfg.SharePoint.Email.Outgoing.Address, 65001)
}

function Config-WebServiceAppPool
{
	Get-SharePointApplicationPool -name $cfg.SharePoint.Services.Name -account $cfg.SharePoint.Services.AppPoolAccount
}

function Config-StateService
{
	try { 
		$app_name = "State Service Application" 

		if( (Get-SPServiceApplication | where { $_.DisplayName -eq $app_name }) ) {
			Write-Host "[ $(Get-Date) ] - $app_name already exists in this farm" -ForegroundColor Red
			return
		}        

		Write-Host "[ $(Get-Date) ] - Creating $app_name Service Application . . . "
		$app = New-SPStateServiceApplication -Name $app_name 
		New-SPStateServiceDatabase -Name "SharePoint State Service" -ServiceApplication $app
		New-SPStateServiceApplicationProxy -Name ($app_name + " Proxy") -ServiceApplication $app -DefaultProxyGroup
		Enable-SPSessionStateService -DefaultProvision
	} 
	catch [System.Exception] {
		Write-Error ("The SharePoint State Service Configuration failed with the following Exception - " + $_.Exception.ToString() )
	}
}

function Config-SecureStore
{
    $sharepoint_servers = Get-FarmWebServers
	try { 
		$app_name = "Secure Store Service Application"
        $inst_name = "Secure Store Service"

		if( (Get-SPServiceApplication | where { $_.DisplayName -eq $app_name }) ) {
			Write-Host "[ $(Get-Date) ] - $app_name already exists in this farm" -ForegroundColor Red
			return
		}
		$db_name = "Secure_Store_Service_DB"

        foreach( $server in $sharepoint_servers ) {
    		Write-Host "[ $(Get-Date) ] - Working on $server . . ."			
			$Guid = Get-SPServiceInstance -Server $server | where {$_.TypeName -eq $inst_name} | Select -Expand Id
            if( $Guid -ne $null ) {
			    Start-SPServiceInstance -Identity $Guid
			}
			else { 
				Write-Error "Could not find $inst_name on $server . . . "
			}
		}


		Write-Host "[ $(Get-Date) ] - Creating $app_name Service Application . . . "
		$sharePoint_service_apppool = Get-SharePointApplicationPool -name $cfg.SharePoint.Services.Name 
		$app = New-SPSecureStoreServiceApplication -Name $app_name -ApplicationPool $sharePoint_service_apppool -DatabaseName $db_name -AuditingEnabled:$true -AuditLogMaxSize 30 -Sharing:$false -PartitionMode:$true 
		$proxy = New-SPSecureStoreServiceApplicationProxy -Name ($app_name + " Proxy") -ServiceApplication $app -DefaultProxyGroup 
		Update-SPSecureStoreMasterKey -ServiceApplicationProxy $proxy -Passphrase $cfg.SharePoint.Secure.Passphrase
	}
	catch [System.Exception] {
		Write-Error ("The SharePoint Secure Store Configuration failed with the following Exception - " + $_.Exception.ToString() )
	}
}

function Config-AccessWebServices
{
    $sharepoint_servers = Get-FarmWebServers

	try { 
		$app_name = "Access Service Application"
        $inst_name = "Access Services"

		if( (Get-SPServiceApplication | where { $_.DisplayName -eq $app_name }) ) {
			Write-Host "[ $(Get-Date) ] - $app_name already exists in this farm" -ForegroundColor Red
			return
		}

        foreach( $server in $sharepoint_servers ) {
    		Write-Host "[ $(Get-Date) ] - Working on $server . . ."			
			$Guid = Get-SPServiceInstance -Server $server  | where {$_.TypeName -eq $inst_name} | Select -Expand Id
            if( $Guid -ne $null ) {
			    Start-SPServiceInstance -Identity $Guid
			}
			else { 
				Write-Error "Could not find $inst_name on $server. . . . "
			}
		}

		Write-Host "[ $(Get-Date) ] - Creating $app_name Service Application . . . "
		$sharePoint_service_apppool = Get-SharePointApplicationPool -name $cfg.SharePoint.Services.Name 
		$app = New-SPAccessServiceApplication -ApplicationPool $sharePoint_service_apppool -Name $app_name 
		$app | Set-SPAccessServiceApplication -ApplicationLogSizeMax 1500 -CacheTimeout 150
	}
	catch [System.Exception] {
		Write-Error ("The SharePoint Access Configuration failed with the following Exception - " + $_.Exception.ToString() )
	}
}

function Config-VisioWebServices
{
    $sharepoint_servers = Get-FarmWebServers

	try {
		$app_name = "Visio Service Application"
        $inst_name = "Visio Graphics Service"

		if( (Get-SPServiceApplication | where { $_.DisplayName -eq $app_name }) ) {
			Write-Host "[ $(Get-Date) ] - $app_name already exists in this farm" -ForegroundColor Red
			return
		}

        foreach( $server in $sharepoint_servers ) {
    		Write-Host "[ $(Get-Date) ] - Working on $server . . ."			
			$Guid = Get-SPServiceInstance -Server $server  | where {$_.TypeName -eq $inst_name} | Select -Expand Id
            if( $Guid -ne $null ) {
			    Start-SPServiceInstance -Identity $Guid
			}
			else { 
				Write-Error "Could not find $inst_name on $server. . . . "
			}
		}

		Write-Host "[ $(Get-Date) ] - Creating $app_name Service Application . . . "
		$sharePoint_service_apppool = Get-SharePointApplicationPool -name $cfg.SharePoint.Services.Name 
		$app = New-SPVisioServiceApplication -ApplicationPool $sharePoint_service_apppool -Name $app_name
		$app | Set-SPVisioPerformance -MaxRecalcDuration 60 -MaxDiagramCacheAge 60 -MaxDiagramSize 5 -MinDiagramCacheAge 5 -MaxCacheSize 100
		$proxy = New-SPVisioServiceApplicationProxy -Name ($app_name + " Proxy") -ServiceApplication $app.Name  
	}
	catch [System.Exception] {
		Write-Error ("The SharePoint Visio Configuration failed with the following Exception - " + $_.Exception.ToString() )
	}
}

function Config-InitialPublishing
{
	param ( 
		[string] $farm_type = "stand-alone"
	)
	
    if( (Get-PSDrive -PSProvider FileSystem | where { $_.Root -eq "D:\" }) ) { $drive = "D:" } else { $drive = "C:" }
	$certs_home = (Join-Path $drive "Certs") + "\"
	
	if ( -not ( Test-Path $certs_home ) ) {
		mkdir $certs_home
		New-SMBShare  -Name Certs -Path $certs_home -ReadAccess Everyone
	}
	
	Write-Host "[ $(Get-Date) ] - Creating Root and STS Certifictes . . . "
	$rootCert = (Get-SPCertificateAuthority).RootCertificate
	$rootCert.Export("Cert") | Set-Content "$certs_home\$farm_type-Root.cer" -Encoding byte
	
	$stsCert = (Get-SPSecurityTokenServiceConfig).LocalLoginProvider.SigningCertificate
	$stsCert.Export("Cert") | Set-Content "$certs_home\$farm_type-STS.cer" -Encoding byte
	$id = (Get-SPFarm).id 
	$id.Guid | out-file -encoding ascii "$certs_home\$farm_type-Id.txt"		
}

function Import-RootCert
{
	param(
		[string] $central_admin,
		[string] $root_cert = "Services-Root.cer",
		[string] $authority_name = "Services-Farm"
	)

	if( (Get-PSDrive -PSProvider FileSystem | where { $_.Root -eq "D:\" }) ) { $drive = "D:" } else { $drive = "C:" }
	$cert_home = (Join-Path $drive "Certs") + "\"
	
	try {
		Copy-Item \\$central_admin\Certs\$root_cert $cert_home
		$trustCert = Get-PfxCertificate "$cert_home\$root_cert"
		New-SPTrustedRootAuthority $authority_name -Certificate $trustCert
	}
	catch { 
		throw "[ERROR] - Error encounted import $($root_cert). Was Config-InitialPublishing run on $($central_admin) . . ."
	}
}

function Configure-SecureTokenService
{
	$sts = Get-SPSecurityTokenServiceConfig
	$sts.FormsTokenLifeTime = (New-TimeSpan -Minute 20)
    $sts.AllowMetadataOverHttp = $true
    $sts.AllowOAuthOverHttp = $true
	$sts.Update()
}

function Config-SharePointApps
{
    $sharepoint_servers = Get-FarmWebServers

	try {
		$app_name = "App Settings Service Application"
		$db_name = "App_Settings_Service_DB"

		if( (Get-SPServiceApplication | where { $_.DisplayName -eq $app_name }) ) {
			Write-Host "[ $(Get-Date) ] - $app_name already exists in this farm" -ForegroundColor Red
			return
		}
		
        $services = @("App Management Service","Microsoft SharePoint Foundation Subscription Settings Service")
        foreach( $server in $sharepoint_servers ) {
            Write-Host "[ $(Get-Date) ] - Working on $server . . ."			
            foreach( $service in $services ) { 
                $Guid = Get-SPServiceInstance -Server $server | where {$_.TypeName -eq $service} | Select -Expand Id
                if( $Guid -ne $null ) {
			        Start-SPServiceInstance -Identity $Guid
			    }
			    else { 
				    Write-Error "Could not find $service on $server. . . . "
			    }
            }
        }

        $farm_account = (get-SPFarm).DefaultServiceAccount

		$sharePoint_service_apppool = Get-SharePointApplicationPool -name $cfg.SharePoint.App.AppPool -account $farm_account.Name
		$app_settings_svc = New-SPSubscriptionSettingsServiceApplication –ApplicationPool $sharePoint_service_apppool –Name $app_name –DatabaseName $db_name
		New-SPSubscriptionSettingsServiceApplicationProxy –ServiceApplication $app_settings_svc
		
		$app_name = "App Management Service Application"
		$db_name = "App_Management_Service_DB"
		if( (Get-SPServiceApplication | where { $_.DisplayName -eq $app_name }) ) {
			Write-Host "$($app_name) already exists in this farm" -ForegroundColor Red
			return
		}
		$app_mgmt_svc = New-SPAppManagementServiceApplication -ApplicationPool $sharePoint_service_apppool -Name $app_name -DatabaseName $db_name
		New-SPAppManagementServiceApplicationProxy -ServiceApplication $app_mgmt_svc 

		Set-SPAppDomain $cfg.SharePoint.App.domain
		Set-SPAppSiteSubscriptionName -Name $cfg.SharePoint.App.prefix -Confirm:$false
	}
	catch [System.Exception] {
		Write-Error ("The SharePoint Application Configuration failed with the following Exception - " + $_.Exception.ToString() )
	}
}

function Config-WorkManagement
{
    $sharepoint_servers = Get-FarmWebServers

	try {
		$app_name = "Work Management Service Application"
        $inst_name = "Work Management Service"

		if( (Get-SPServiceApplication | where { $_.DisplayName -eq $app_name }) ) {
			Write-Host "[ $(Get-Date) ] - $app_name already exists in this farm" -ForegroundColor Red
			return
		}

        foreach( $server in $sharepoint_servers ) {
    		Write-Host "[ $(Get-Date) ] - Working on $server . . ."			
			$Guid = Get-SPServiceInstance -Server $server  | where {$_.TypeName -eq $inst_name} | Select -Expand Id
            if( $Guid -ne $null ) {
			    Start-SPServiceInstance -Identity $Guid
			}
			else { 
				Write-Error "Could not find $inst_name on $server. . . . "
			}
		}


		$sharePoint_service_apppool = Get-SharePointApplicationPool -name $cfg.SharePoint.Services.Name 
		New-SPWorkManagementServiceApplication –Name $app_name –ApplicationPool $sharePoint_service_apppool
	}	
	catch [System.Exception] {
		Write-Error ("The SharePoint Work Managment Configuration failed with the following Exception - " + $_.Exception.ToString() )
	}
}

function Config-DistributedCache
{
    $sharepoint_servers = Get-FarmWebServers

	$sb = {
		param (
			[double] $percent_of_ram
		)
		$cache_port = "22233"
		
		$physical_memory = (Get-WmiObject Win32_ComputerSystem ).TotalPhysicalMemory
		
		Stop-SPDistributedCacheServiceInstance 
		
		$Guid = Get-SPServiceInstance -Server $ENV:COMPUTERNAME  | where { $_.TypeName -eq "Distributed Cache" } | Select -Expand Id
		Start-SPServiceInstance -Identity $Guid
		
		Use-CacheCluster
		Update-SPDistributedCacheSize ( $percent_of_ram * ($physical_memory/1mb) )
		Add-SPDistributedCacheServiceInstance
		
		Get-SPDistributedCacheClientSetting -ContainerType DistributedLogonTokenCache
	}

    Write-Host "[ $(Get-Date) ] - Setting Cache to $($cfg.SharePoint.DistributedCache.ReserveMemory) of Physical Memory on all Web Front End Servers"		
    if( $sharepoint_servers -icontains $env:COMPUTERNAME ) { 
        &$sb -percent_of_ram $cfg.SharePoint.DistributedCache.ReserveMemory
        $sharepoint_servers = @( $sharepoint_servers | where { $_ -inotmatch $env:COMPUTERNAME } )
    }
    if( $sharepoint_servers.Length -gt 1 ) {
        Invoke-Command -ComputerName $sharepoint_servers -ScriptBlock $sb -ArgumentList  $cfg.SharePoint.DistributedCache.ReserveMemory
    }
}
