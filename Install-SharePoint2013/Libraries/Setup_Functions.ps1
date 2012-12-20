function Configure-CentralAdmin-Roles
{
    param ( 
        [string] $type
    )

	$ca_roles = @(
		"Microsoft SharePoint Foundation Incoming E-Mail",
		"Microsoft SharePoint Foundation Web Application",
		"Claims to Windows Token Service" 
    )
		
	$farm = $cfg.SharePoint.Farms.farm | where { $_.name -eq $type }
	foreach( $server in $farm.Server | where { $_.role -eq "central-admin" -or $_.role -eq "all" } ) {
		Write-Host "Working on $($server.name) . . ."
		
		foreach( $start_app in $ca_roles ) {
			$Guid = Get-SPServiceInstance -Server $server.name  | where {$_.TypeName -eq $start_app} | Select -Expand Id
            if( $Guid -ne $null ) {
			    Start-SPServiceInstance -Identity $Guid
			}
			else { 
				Write-Error "Could not find $start_app on $($server.name) . . . "
			}
    	}
	}

}

function Configure-WFE-Roles
{
    param (
        [string] $type
    )

	$wfe_roles = @(
		"Microsoft SharePoint Foundation Sandboxed Code Service",
		"Claims to Windows Token Service",
		"Secure Store Service",
		"Access Database Service", 
		"Visio Graphics Service"
        "Work Management Service",
        "App Management Service",
        "Microsoft SharePoint Foundation Subscription Settings Service",
        "Request Management")
		
	$farm = $cfg.SharePoint.Farms.farm | where { $_.name -eq $type }
	foreach( $server in $farm.Server | where { $_.role -eq "wfe" -or $_.role -eq "all" } ) {
		Write-Host "Working on $($server.name) . . ."	
		
		foreach( $start_app in $wfe_roles )	{
			$Guid = Get-SPServiceInstance -Server $server.name  | where {$_.TypeName -eq $start_app} | Select -Expand Id
            if( $Guid -ne $null ) {
			    Start-SPServiceInstance -Identity $Guid
			}
			else { 
				Write-Error "Could not find $start_app on $($server.name) . . . "
			}
		}
				
		foreach ( $stop_app in @("Microsoft SharePoint Foundation Incoming E-Mail") ) {
			$Guid = Get-SPServiceInstance -Server $server.name  | where {$_.TypeName -eq $stop_app} | Select -Expand Id
            if( $Guid -ne $null ) {
			    Stop-SPServiceInstance -Identity $Guid -Confirm:$false
			}
			else { 
				Write-Error "Could not find $stop_app on $($server.name) . . . "
			}
		}
	}
}

function Configure-ServicesFarm-Roles([String] $env)
{
	$services_roles = @(
        "Managed Metadata Web Service", 
        "User Profile Service" 
    )

	$farm = $cfg.SharePoint.Farms.farm | where { $_.name -eq $env }
	foreach( $server in $farm.Server | where { $_.role -eq "application" } ) {
		Write-Host "Working on $($server.name) . . ."	

		foreach( $start_app in $services_roles ) {
			$Guid = Get-SPServiceInstance -Server $server.name  | where {$_.TypeName -eq $stop_app} | Select -Expand Id
            if( $Guid -ne $null ) {
			    Start-SPServiceInstance -Identity $Guid
			}
			else { 
				Write-Error "Could not find $start_app on $($server.name) . . . "
			}
		}
	}
}

function Get-SharePointApplicationPool
{
	param (
		[string] $name,
		[string] $account
	
	)
	
	Write-Host "[$(Get-Date)] - Attempting to Get Service Application Pool -  $($name)"
 	$pool = Get-SPServiceApplicationPool $name
	if( $pool -eq $nul ) {
		Write-Host "[$(Get-Date)] - Could not find Application Pool - $($name) - therefore creating new pool"
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
		Write-Host "Found $ENV:COMPUTERNAME in $global:farm_type Farm Configuration"
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
		Write-Host "Adding $($_.group) to the Farm Administrators group . . ."

        if( $current_admins -notcontains $_.group ) {
		    $user = New-SPUser -UserAlias $_.group -Web $web
		    $farm_admins.AddUser($user, [String]::Empty,[String]::Empty,[String]::Empty)
		
		    Add-SPShellAdmin $_.group
        }
	}
	
	$cfg.SharePoint.FarmAdministrators.remove | % { 
		$group = $_.group

		Write-Host "Removing $($_.group) to the Farm Administrators group . . ."
		$user = Get-SPUser -Web $web -Group "Farm Administrators" | Where { $_.Name.ToLower() -eq $group }

		$farm_admins.RemoveUser($user)
	}
	$web.Dispose()
	
	Get-SPShellAdmin
	
}

function Config-ManagedAccounts
{

	$cfg.SharePoint.managedaccounts.account | where { $_.farm -match $global:farm_type } | % { 
        Write-Host "Add $($_.username) as a Managed Service Account . . ."
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
			Write-Host "$($app_name) already exists in this farm" -ForegroundColor Red
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
	try { 
		$app_name = "Secure Store Service"

		if( (Get-SPServiceApplication | where { $_.DisplayName -eq $app_name }) ) {
			Write-Host "$($app_name) already exists in this farm" -ForegroundColor Red
			return
		}
		$db_name = "Secure_Store_Service_DB"

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
	try { 
		$app_name = "Access Service Application"

		if( (Get-SPServiceApplication | where { $_.DisplayName -eq $app_name }) ) {
			Write-Host "$($app_name) already exists in this farm" -ForegroundColor Red
			return
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
	try {
		$app_name = "Visio Service Application"

		if( (Get-SPServiceApplication | where { $_.DisplayName -eq $app_name }) ) {
			Write-Host "$($app_name) already exists in this farm" -ForegroundColor Red
			return
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
    if( (Get-PSDrive -PSProvider FileSystem | where { $_.Root -eq "D:\" }) ) { $drive = "D:" } else { $drive = "C:" }
	$cert_home = (Join-Path $drive "Certs") + "\"

	if( $global:farm_type -eq "standalone" ) {
		return
	}
	
	if ( -not ( Test-Path $certs_home ) ) {
		mkdir $certs_home
        net share Certs=$certs_home /Grant:Everyone,Read
	}
	
	if( $global:farm_type -eq "services" ) {
        Write-Host "[ $(Get-Date) ] - Creating Services Farm Root Certificte . . . "
		$rootCert = (Get-SPCertificateAuthority).RootCertificate
		$rootCert.Export("Cert") | Set-Content "$certs_home\ServicesFarmRoot.cer" -Encoding byte

	}
	else {
        Write-Host "[ $(Get-Date) ] - Creating Root and STS Certifictes . . . "
		$rootCert = (Get-SPCertificateAuthority).RootCertificate
		$rootCert.Export("Cert") | Set-Content "$certs_home\$global:farm_type-Root.cer" -Encoding byte
		
		$stsCert = (Get-SPSecurityTokenServiceConfig).LocalLoginProvider.SigningCertificate
		$stsCert.Export("Cert") | Set-Content "$certs_home\$global:farm_type-STS.cer" -Encoding byte
		$id = (Get-SPFarm).id 
		$id.Guid | out-file -encoding ascii "$certs_home\$global:farm_type-Id.txt"		
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
	try {
		$app_name = "App Settings Service Application"
		$db_name = "App_Settings_Service_DB"
		if( (Get-SPServiceApplication | where { $_.DisplayName -eq $app_name }) ) {
			Write-Host "$($app_name) already exists in this farm" -ForegroundColor Red
			return
		}
		
        $services = @("App Management Service","Microsoft SharePoint Foundation Subscription Settings Service")
        foreach( $service in $services ) { 
            $instance = Get-SPServiceInstance | ? { $_.TypeName -eq $service }
            if( $instance.Status -eq "Disabled" ) { Start-SPServiceInstance $service.Id }
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
	try {
		$app_name = "Work Management Service Application"
		if( (Get-SPServiceApplication | where { $_.DisplayName -eq $app_name }) ) {
			Write-Host "$($app_name) already exists in this farm" -ForegroundColor Red
			return
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
	$type = "Microsoft SharePoint Foundation Web Application"
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
	
	$sharepoint_servers = Get-SPServiceInstance | where { $_.TypeName -eq $type -and $_.Status -eq "Online" } | Select -Expand Server | Select -Expand Address

    if( $sharepoint_servers -icontains $env:COMPUTERNAME ) { 
        &sb -percent_of_ram $cfg.SharePoint.DistributedCache.ReserveMemory
        $sharepoint_servers = @( $sharepoint_servers | where { $_ -inotmatch $env:COMPUTERNAME } )
    }
    if( $sharepoint_servers.Length -gt 1 ) {
        Invoke-Command -ComputerName $sharepoint_servers -ScriptBlock $sb -ArgumentList  $cfg.SharePoint.DistributedCache.ReserveMemory
    }
}
