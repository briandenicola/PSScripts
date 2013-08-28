[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[Parameter(Mandatory=$true)]
	[ValidateSet("development", "test", "uat", "production")]
	[string] $env,
	[string] $farm = "2010-",
    [ValidateSet("all", "windows", "sql", "profiles", "search", "services", "iis", "logs", "security", "solutions", "logs")]
	[string[]] $operations = "all"
)

#Region Script Setup
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

$global:logFile = Join-Path $PWD.PATH ( Join-Path "logs" ($env + "-" + $farm + "-environmental-validation-" + $(Get-Date).ToString("yyyyMMddmmhhss") + ".log" ) )
$url = "http://the.url.to/server/list"

function log ( [string] $txt )
{
	Write-Host "[" $(Get-Date).ToString() "] - " $txt " ... "
	"[" + (Get-Date).ToString() + "] - " + $txt | Out-File $global:logFile -Append -Encoding ASCII
}

function Get-SharePoint-SQLServersWS ()
{
	return(	Get-SPListViaWebService -Url $url -list "SQL Servers" )
}

$check_apppool_sb = { 
	Import-Module WebAdministration  -EA SilentlyContinue
	Get-ChildItem IIS:\AppPools | Where { $_.State -eq "Stopped" -and $_.name -ne "SharePoint Web Services Root" } | Select @{Name="System";Expression={$Env:ComputerName}}, Name, State 
}

$check_url_sb = {
	Add-PSSnapin Microsoft.SharePoint.Powershell
	$servers = Get-SPServer  | where { $_.Address -match "SPW" } | Select -Expand Address
	$urls = Get-SPWebApplication | Select -Expand Url
	
	$urls_to_check = @()
	foreach( $url in $urls ) {
		$urls_to_check += (New-Object PSObject -Property @{
			url = $url
			servers = $servers
		})
	}
	
	return $urls_to_check
}

$check_uls_sb = {
	Add-PSSnapin Microsoft.SharePoint.Powershell
	Get-SPLogEvent -MinimumLevel High -StartTime $(Get-Date).AddHours(-0.25) | Select @{Name="Server";Expression={$ENV:ComputerName}},TimeStamp, Level, Message | fl
}

$check_solutions_sb = {
	Add-PSSnapin Microsoft.SharePoint.Powershell
	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")

	$solutions = @()
	foreach( $solution in (Get-SPFarm | Select -Expand Solutions) )	{
		$solution.SolutionFile.SaveAs( $ENV:TEMP + "\" + $solution.Name )
		$solutions += (New-Object PSObject -Property @{
			Server = $env:COMPUTERNAME
			Solution = $solution.Name
			Hash = (Get-Hash1 ( $ENV:TEMP + "\" + $solution.Name ))
		})
		Remove-Item ( $ENV:TEMP + "\" + $solution.Name ) -Force
	}
	
	$solutions
}

$check_search_topology_sb = {
	Add-PSSnapin Microsoft.SharePoint.Powershell
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
}

$check_failed_timer_jobs = {
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
    $farm = Get-SPFarm
    $farm.TimerService.JobHistoryEntries | Where { $_.Status -eq "Failed" -and $_.EndTime -gt $(Get-Date).AddDays(-1) }
}

$check_service_application_status = {
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
	Get-SPServiceApplication | 
     Select DisplayName, IisVirtualDirectoryPath, @{Name="AppPoolName";Expression={$_.ApplicationPool.Name}}, @{Name="AppPoolUser";Expression={$_.ApplicationPool.ProcessAccountName}}
}

$check_service_instance_status = {
	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
	Get-SPStartedServices
}

$check_db_size = {
	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
	Get-SPDatabaseSize
}

$check_server_admins = {
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")

    return ( New-Object PSObject -Property @{
        Computer = $env:COMPUTERNAME
        Users = Get-LocalAdmins -computer .
    })
}

$check_managed_accounts = {
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")

    Get-SPShellAdmin
    Get-SPManagedAccount | Select UserName
}

$check_trusted_certs_store = {
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
    Get-SPTrustedRootAuthority | Select Certificate, Name | Format-List
    Get-SPTrustedServiceTokenIssuer | Select Name, SigningCertificate | Format-list
}

$get_farm_account_sb = { 
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
    
    $farm_user = Get-FarmAccount .   

    net localgroup administrators ($ENV:userdomain + "\" + $farm_user.User) /add

    return (New-Object PSObject -Property @{
        User = $farm_user.User
        Password = Get-SPManageAccountPassword $farm_user.User
    })
}

$check_user_profile_sb = {
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")

     $farm_user = Get-FarmAccount . 

    $site = Get-SPSite ( Get-SPWebApplication | Select -Last 1 -Expand Url )
    $srvContext = Get-SPServiceContext $site

    $ups_manager = New-Object Microsoft.Office.Server.UserProfiles.UserProfileManager($srvContext) 
    
    $ups_config_manager = New-Object Microsoft.Office.Server.UserProfiles.UserProfileConfigManager($srvContext) 
    $sync = $ups_config_manager.GetSynchronizationStatus() | Select Stage, BeginTime, EndTime, State, Updates    

    net localgroup administrators ($ENV:userdomain + "\" + $farm_user.User) /delete

    return (New-Object PSObject -Property @{
        Count = $ups_manager.Count
        IsSyncing = $ups_config_manager.IsSynchronizationRunning()
        State = $sync 
    })
}
#EndRegion

#Region Get Servers
log -txt "Getting SharePoint and SQL servers for $env environment"
$servers = Get-SharePointServersWS | where { $_.Farm -match $farm -and $_.Environment -eq $env } | select -ExpandProperty Systemname
$sql_servers = Get-SharePoint-SQLServersWS | where { $_.Farm -match $farm -and $_.Environment -eq $env } 
$ca_servers = Get-SharePointCentralAdmins | where { $_.Farm -match $farm -and $_.Environment -eq $env } | select -ExpandProperty Systemname
$services_farm_ca = Get-SharePointCentralAdmins | where { $_.Farm -match "2010-Services" -and $_.Environment -eq $env } | select -ExpandProperty Systemname
#Endregion

#Region Establish Sessions to Remote Systems
$server_session = New-PSSession -Computer $servers -Authentication CredSSP -Credential (Get-Creds)
$ca_session = New-PSSession -ComputerName $ca_servers -Authentication Credssp -Credential (Get-Creds)
#EndRegion 


#Region Ping Servers and Check Services
if( $operations -eq "all" -or $operations -icontains "windows") {
    log -txt "Pinging servers"
    $servers | ping-multiple
    $sql_servers | select -expand SystemName | ping-multiple

    $services = @("iisadmin", "SPAdminV4", "SPUserCodeV4", "SPTraceV4", "sptimerv4", "msdtc", "FIMService", "FIMSynchronizationService" , "OSearch14", "SPSearch4")
    log -txt ("Checking the following Windows Services (Make sure at least one Search and FIMSynchronizationService Service is running) - " + $services)
    foreach( $server in $servers ) {
	    Get-WmiObject -ComputerName $server Win32_Service | 
		    Where { $_.StartMode -eq "manual" -or $_.StartMode -eq "auto"} |
		    Where { $services -contains $_.Name } |
		    Select @{Name="Server";Expression={$server}}, Name, State | 
		    Out-File -Append -Encoding ASCII $global:logFile
    }
}
#EndRegion

#Region Check SQL Server
if( $operations -eq "all" -or $operations -icontains "sql") {
    foreach( $sql_server in $sql_servers ) {
	    if( $sql_server.Role -eq "Database Node" ) { continue }
	
	    log -txt ("Checking SQL Services Status on " + $sql_server.SystemName)
	    $con =  $sql_server.SystemName + "," + $sql_server.Port.Split(".")[0] +  "\" + $sql_server."Instances Name" 
	
	    if( $sql_server.Role -eq "Standalone Database Server" ) { 
		    Get-Service -ComputerName $sql_server.SystemName @("MSSQLServer","MSDTC","SQLSERVERAGENT") -EA SilentlyContinue | 
			    Select @{Name="Server";Expression={$_.MachineName}}, Name, Status | 
			    Out-File -Append -Encoding ASCII $global:logFile			
	    }
	    elseif( $sql_server.Role -eq "Database Cluster" ) {
		    log -txt "Due to permissions, can not checking the state of the SQL Server or MSDTC in UAT or Production"	
	    }

	    log -txt "Checking for all offline databases on $con"
	    Query-DatabaseTable -server $con -dbs "master"  -sql "select name, state_desc FROM sys.databases WHERE state_desc<>'ONLINE'" |
		    Out-File -Append -Encoding ASCII $global:logFile
    }

    log -txt "Check Database File Sizes in Farm"
    Invoke-Command -Session $ca_session -ScriptBlock $check_db_size |
        Select Name, Server, Size |
        Sort -Property Server | 
	    Out-File -Append -Encoding ASCII $global:logFile

}
#EndRegion

#Region Check Security
if( $operations -eq "all" -or $operations -icontains "security") {
    log -txt "Checking for Server Administrators"
    Invoke-Command -Session $server_session -ScriptBlock $check_server_admins | 
        Select Computer, Users | ForEach-Object { 
            $_.Computer | Out-File -Append -Encoding ASCII $global:logFile
	        $_.Users | Out-File -Append -Encoding ASCII $global:logFile
            [String]::Empty | Out-File -Append -Encoding ASCII $global:logFile
        }

    log -txt "Checking for SharePoint Managed Accounts"
    Invoke-Command -Session $ca_session -ScriptBlock $check_managed_accounts | 
        Select UserName |
	    Out-File -Append -Encoding ASCII $global:logFile

    log -txt "Checking for SharePoint Trust Certificats"
    Invoke-Command -Session $ca_session -ScriptBlock $check_trusted_certs_store | 
	    Out-File -Append -Encoding ASCII $global:logFile
}
#EndRegion

#Region Check IIS
if( $operations -eq "all" -or $operations -icontains "iis") {
    log -txt "Checking Web Site State"
    Get-IISWebState -computers $servers | Sort Name | Out-File -Append -Encoding ASCII $global:logFile

    log -txt "Checking for Stopped AppPools Status"
    Invoke-Command -Session $server_session -ScriptBlock $check_apppool_sb |
	    Select System, Name, State | 
	    Out-File -Append -Encoding ASCII $global:logFile

    log -txt "Check URLs in Farm"
    $urls_to_check = Invoke-Command -Session $ca_session -ScriptBlock $check_url_sb
 
    foreach( $obj in $urls_to_check ) {
	    foreach( $server in $obj.servers ) {
		    log -txt ("Checking " + $obj.Url + " on " + $server )
		    Get-Url -url $obj.Url -server $server | Out-File -Append -Encoding ASCII $global:logFile
	    }
    }
}
#EndRegion

#Region Check Service Applications
if( $operations -eq "all" -or $operations -icontains "services") {
    log -txt "Check Service Applications in Farm"
    Invoke-Command -Session $ca_session -ScriptBlock $check_service_application_status |
        Select DisplayName, IisVirtualDirectoryPath, AppPoolName, AppPoolUser |
	    Sort -Property DisplayName |
        Format-List |
	    Out-File -Append -Encoding ASCII $global:logFile
	
    Invoke-Command -Session $ca_session -ScriptBlock $check_service_instance_status |
	    Select Service, Server |
	    Sort -Property Service |
	    Out-File -Append -Encoding ASCII $global:logFile
}
#EndRegion

#Region Check Solutions
if( $operations -eq "all" -or $operations -icontains "solutions") {
    log -txt "Check Solutions in Farm"
    Invoke-Command -Session $ca_session -ScriptBlock $check_solutions_sb |
	    Select Server, Solution, Hash | 
	    Out-File -Append -Encoding ASCII $global:logFile
}
#EndRegion

#Region Check SharePoint Search Topology
if( $operations -eq "all" -or $operations -icontains "search") {
	log -txt "Check Search Topology in Search Farm"
	$search = Invoke-Command -ComputerName $services_farm_ca -Authentication Credssp -Credential (Get-Creds) -ScriptBlock $check_search_topology_sb 

	foreach( $property in ($search | Get-Member | where { $_.MemberType -eq "NoteProperty" -and $_.Name -notmatch "PS"}) ) {
		log -txt ( "Search Property - " + $property.Name )
		$search.$($property.Name) | 
			Format-List |
			Out-File -Append -Encoding ASCII $global:logFile	
	}
}
#EndRegion

#Region Check SharePoint User Profiles
if( $operations -eq "all" -or $operations -icontains "profiles") {
    log -txt "Checking User Profile Services"
    $user = Invoke-Command -ComputerName $services_farm_ca -Authentication Credssp -Credential (Get-Creds) -ScriptBlock $get_farm_account_sb
    $password = ConvertTo-SecureString -AsPlainText -Force $user.Password
    $farm_creds = New-Object System.Management.Automation.PSCredential ( ($ENV:userdomain + "\" + $user.User) , $password )
    Invoke-Command -ComputerName $services_farm_ca -Authentication Credssp -Credential $farm_creds -ScriptBlock $check_user_profile_sb |
        Out-File -Append -Encoding ASCII $global:logFile

}
#EndRegion

#Region Check Failed Timer Jobs
if( $operations -eq "all" -or $operations -icontains "logs") {
    log -txt "Check Failed Timer Jobs"
    Invoke-Command -Session $ca_session -ScriptBlock $check_failed_timer_jobs |
	    Select JobDefinitionTitle, ServerName, StartTime, EndTime, ErrorMessage | 
	    Out-File -Append -Encoding ASCII $global:logFile

	log -txt "Checking Event Logs"
	$servers | % { Get-WinEvent -LogName @("Application", "System") -ComputerName $_ -MaxEvents 20 } | 
		Select TimeCreated, ProviderName, Message |
		Format-List |
		Out-File -Append -Encoding ASCII $global:logFile

	log -txt "Checking ULS Logs"
	Invoke-Command -Session $server_session -ScriptBlock $check_uls_sb |
		Out-File -Append -Encoding ASCII $global:logFile

}
#EndRegion

Get-PSSession | Remove-PSSession 
Invoke-Item $global:logFile