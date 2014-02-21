function log {
    param( 
        [string] $txt
    )
    
    $output = "[{0}] - {1} . . ." -f $(Get-Date), $txt
    
    Write-Verbose -Message $output
    
    "="*25 | Out-File $log_file -Append -Encoding ASCII
    $output | Out-File $log_file -Append -Encoding ASCII
    "="*25 | Out-File $log_file -Append -Encoding ASCII
}

function Get-Properties {
    param ( 
        [Object] $ps_object 
    )
    
    return ($ps_object | Get-Member | where { $_.MemberType -eq "NoteProperty" -and $_.Name -notmatch "PS"})
}

function Get-SharePoint-SQLServersWS {
    $list = "SQL Servers"
	return(	Get-SPListViaWebService -Url $url -list $list )
}

function Get-Servers-To-Process {
    param( 
        [string] $farm,
        [string] $env
    )

    log -txt ("Getting Servers from SharePoint List")

    return ( New-Object PSObject -Property @{ 
        Servers = (Get-SharePointServersWS | where { $_.Farm -match $farm -and $_.Environment -eq $env } | select -ExpandProperty Systemname)
        SqlServers = (Get-SharePoint-SQLServersWS | where { $_.Farm -match $farm -and $_.Environment -eq $env } )
        CAServer = (Get-SharePointCentralAdmins | where { $_.Farm -match $farm -and $_.Environment -eq $env } | select -ExpandProperty Systemname)
        ServicesFarmCA = (Get-SharePointCentralAdmins | where { $_.Farm -match "2010-Services" -and $_.Environment -eq $env } | select -ExpandProperty Systemname)
    })
}

function Check-Windows {
    log -txt "Pinging Application and Web Servers"
    $systems.Servers | ping-multiple | Out-File -Append -Encoding ASCII $log_file
    
    $services = @("iisadmin", "SPAdminV4", "SPUserCodeV4", "SPTraceV4", "sptimerv4", "msdtc", "FIMService", "FIMSynchronizationService" , "OSearch14", "SPSearch4")
    log -txt ("Checking the following Windows Services (Make sure at least one Search and FIMSynchronizationService Service is running) - {0}" -f $services)
    
    foreach( $server in $systems.Servers ) {
	    Get-WmiObject -ComputerName $server Win32_Service | 
		    Where { $_.StartMode -eq "manual" -or $_.StartMode -eq "auto"} |
		    Where { $services -contains $_.Name } |
		    Select @{Name="Server";Expression={$server}}, Name, State | 
		    Out-File -Append -Encoding ASCII $log_file
    }   
}

function Check-SQL {
    log -txt "Pinging SQL servers"

    $systems.SqlServers | select -expand SystemName | ping-multiple

    foreach( $sql_server in $systems.SqlServers ) {
	    if( $sql_server.Role -eq "Database Node" ) { continue }
	
	    log -txt ("Checking SQL Services Status on {0}" -f $sql_server.SystemName)
	    $con =  $sql_server.SystemName + "," + $sql_server.Port.Split(".")[0] +  "\" + $sql_server."Instances Name" 
	
	    if( $sql_server.Role -eq "Standalone Database Server" ) { 
		    Get-Service -ComputerName $sql_server.SystemName @("MSSQLServer","MSDTC","SQLSERVERAGENT") -EA SilentlyContinue | 
			    Select @{Name="Server";Expression={$_.MachineName}}, Name, Status | 
			    Out-File -Append -Encoding ASCII $log_file			
	    }
	    elseif( $sql_server.Role -eq "Database Cluster" ) {
		    log -txt "Due to permissions, can not checking the state of the SQL Server or MSDTC in UAT or Production"	
	    }

	    log -txt "Checking for all offline databases on $con"
	    Query-DatabaseTable -server $con -dbs "master"  -sql "select name, state_desc FROM sys.databases WHERE state_desc<>'ONLINE'" |
		    Out-File -Append -Encoding ASCII $log_file
    }

    log -txt "Check Database File Sizes in Farm"
    Invoke-Command -Session $ca_session -ScriptBlock $check_db_size |
        Select Name, Server, Size |
        Sort -Property Server | 
	    Out-File -Append -Encoding ASCII $log_file

}

function Check-Security {
    log -txt "Checking for Server Administrators"
    Invoke-Command -Session $server_session -ScriptBlock $check_server_admins | 
        Select Computer, Users | ForEach-Object { 
            $_.Computer | Out-File -Append -Encoding ASCII $log_file
	        $_.Users | Out-File -Append -Encoding ASCII $log_file
            [String]::Empty | Out-File -Append -Encoding ASCII $log_file
        }

    log -txt "Checking for SharePoint Farm Administrators"
    Invoke-Command -Session $ca_session -ScriptBlock $check_farm_administrators | 
        Select DisplayName |
	    Out-File -Append -Encoding ASCII $log_file
      

    log -txt "Checking for SharePoint Managed Accounts"
    Invoke-Command -Session $ca_session -ScriptBlock $check_managed_accounts | 
        Select UserName |
	    Out-File -Append -Encoding ASCII $log_file

    log -txt "Checking for SharePoint Trust Certificats"
    Invoke-Command -Session $ca_session -ScriptBlock $check_trusted_certs_store | 
	    Out-File -Append -Encoding ASCII $log_file
}

function Check-IIS {
    log -txt "Checking Web Site State"
    Get-IISWebState -computers $systems.Servers | Sort Name | Out-File -Append -Encoding ASCII $log_file

    log -txt "Checking for Stopped AppPools Status"
    Invoke-Command -Session $server_session -ScriptBlock $check_apppool_sb |
	    Select System, Name, State | 
	    Out-File -Append -Encoding ASCII $log_file

    log -txt "Check URLs in Farm"
    $urls_to_check = Invoke-Command -Session $ca_session -ScriptBlock $check_url_sb
 
    foreach( $obj in $urls_to_check ) {
	    foreach( $server in $obj.servers ) {
		    log -txt ("Checking {0} on {1}" -f $obj.Url,$server)
		    Get-Url -url $obj.Url -server $server | Out-File -Append -Encoding ASCII $log_file
	    }
    }
}

function Check-Services {
    log -txt "Check Service Applications in Farm"
    Invoke-Command -Session $ca_session -ScriptBlock $check_service_application_status |
        Select DisplayName, IisVirtualDirectoryPath, AppPoolName, AppPoolUser |
	    Sort -Property DisplayName |
        Format-List |
	    Out-File -Append -Encoding ASCII $log_file
	
    Invoke-Command -Session $ca_session -ScriptBlock $check_service_instance_status |
	    Select Service, Server |
	    Sort -Property Service |
	    Out-File -Append -Encoding ASCII $log_file
}

function Check-Solutions {
    log -txt "Check Solutions in Farm"
    Invoke-Command -Session $ca_session -ScriptBlock $check_solutions_sb |
	    Select Server, Solution, Hash | 
	    Out-File -Append -Encoding ASCII $log_file
}

function Check-Search {
	log -txt "Check Search Topology in Search Farm"
	$search = Invoke-Command -ComputerName $systems.ServicesFarmCA -Authentication Credssp -Credential (Get-Creds) -ScriptBlock $check_search_topology_sb 

	foreach( $property in (Get-Properties -ps_object $search) ) {
		log -txt ( "Search Property - " + $property.Name )
		$search.$($property.Name) | 
			Format-List |
			Out-File -Append -Encoding ASCII $log_file	
	}
}

function Check-UserProfiles {

    log -txt "Getting Farm Account for Services Farm"
    $user = Invoke-Command -ComputerName $systems.ServicesFarmCA -Authentication Credssp -Credential (Get-Creds) -ScriptBlock $get_farm_account_sb
    $password = ConvertTo-SecureString -AsPlainText -Force $user.Password
    $farm_creds = New-Object System.Management.Automation.PSCredential ( $user.Name , $password )
    
    Write-Verbose ("[{0}] - User Profiles Farm Credentials - {1}" -f $(Get-Date), $user.Name )

    log -txt "Checking User Profile Services"
    Invoke-Command -ComputerName $systems.ServicesFarmCA -Authentication Credssp -Credential $farm_creds -ScriptBlock $check_user_profile_sb |
        Out-File -Append -Encoding ASCII $log_file
}

function Check-ULSLogs {
    log -txt "Check Failed Timer Jobs"
    Invoke-Command -Session $ca_session -ScriptBlock $check_failed_timer_jobs |
	    Select JobDefinitionTitle, ServerName, StartTime, EndTime, ErrorMessage | 
	    Out-File -Append -Encoding ASCII $log_file

	log -txt "Checking Event Logs"
    foreach( $server in $systems.Servers ) {
	    Get-WinEvent -LogName @("Application", "System") -ComputerName $server -MaxEvents 20 |
		    Select TimeCreated, ProviderName, Message |
		    Format-List |
		    Out-File -Append -Encoding ASCII $log_file
    }

	log -txt "Checking ULS Logs"
	Invoke-Command -Session $server_session -ScriptBlock $check_uls_sb |
		Out-File -Append -Encoding ASCII $log_file
}

function Check-HealthRule {
    log -txt "Check Health Report"
    Get-SPListViaWebService -url ("http://{0}:10000/" -f $systems.CAServer ) -list "Review problems and solutions" | 
        Out-File -Append -Encoding ASCII $log_file

	log -txt "List Disable Health Rules"
    Invoke-Command -Session $ca_session -ScriptBlock $check_disable_healthrules |
        Out-File -Append -Encoding ASCII $log_file
}