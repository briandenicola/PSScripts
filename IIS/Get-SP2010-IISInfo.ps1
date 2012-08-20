[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[Parameter(Mandatory=$true)]
	[String[]] $Servers,
	[switch] $details,
	[switch] $upload,
	
	[ValidateSet("all", "name", "url")]
	[string] $filter_type = "all",
	[string] $filter_value
)

. ..\..\Libraries\Standard_Functions.ps1
. ..\..\Libraries\SharePoint_Functions.ps1

$url = "http://collaboration.gt.com/site/SharePointOperationalUpgrade/"
$list_servers = "Servers"
$list_websites = "WebApplications"

function Get-SPFormattedServers ( [String[]] $computers )
{
	$sp_formatted_data = [String]::Empty
	$sp_server_list = get-SPListViaWebService -url $url -list $list_servers
	
	$computers | % { 
		$computer = $_
		$id = $sp_server_list | where { $_.SystemName -eq $computer } | Select -ExpandProperty ID
		$sp_formatted_data += "#{0};#{1};" -f $id, $computer
	}
	
	Write-Verbose $sp_formatted_data
	
	return $sp_formatted_data.TrimStart("#").TrimEnd(";").ToUpper()
}

function Check-SiteBindings
{
	param( 
		[string] $url,
		[object] $site
	)
	
	foreach( $binding in $site.ServerBindings )
	{
		if( $binding.Hostname -eq $url ) { return $true }
	}
	return $false
	
}

if( $filter_type -eq "name" -and [String]::IsNullOrEmpty($filter_value) )
{
	Write-Host "The switch filter_value cannot be null if filter_type is name" -ForegroundColor Red 
	return
}

if( $details -and $upload )
{
	Write-Host  "The detail switch and upload switch can not be used at the same time" -ForegroundColor Red 
	return
}

if( $details )
{
	return  Audit-IISServers ( $Servers )
}

Set-Variable -Name WebServerQuery -Value "Select * from IIsWebServerSetting"
if( $filter_type -eq "name" )
{
	$WebServerQuery += " where ServerComment = '" + $filter_value + "'"
}

$audit_results = @()
foreach( $server in $Servers )
{
	Write-Progress -activity "Querying Server" -status "Currently querying $Server . . . "
	if( ping( $Server ) ) 
	{
		$wmi_webserver = [WmiSearcher] $WebServerQuery
		$wmi_webServer.Scope.Path = "\\{0}\root\microsoftiisv2" -f $Server
		$wmi_webServer.Scope.Options.Authentication = 6
		
		foreach ( $site in $wmi_webServer.Get() )
		{			
			if( $filter_type -ne "url" -or ($filter_type -eq "url" -and (Check-SiteBindings -url $filter_value -site $site) -eq $true ) )
			{
				$audit = New-Object System.Object
								
				$audit | add-member -type NoteProperty -name RealServers -Value $Server		
				$audit | add-member -type NoteProperty -name WebApplication -Value $site.ServerComment
				$audit | add-member -type NoteProperty -name IISName -Value $site.ServerComment
				$audit | add-member -type NoteProperty -name IISId -Value $site.Name.Replace("W3SVC/","")
				
				$hostheaders = @{}
				$internal_ip = @{}
				
				foreach( $binding in $site.ServerBindings )
				{
					$ip = $nul 
					
					if( $binding.Port -eq 443 ) { $hostheader = "https://"	} else { $hostheader = "http://" }
					$hostheader += $binding.HostName + ":" + $binding.Port
					
					if( -not $hostheaders.ContainsKey($hostheader) ) { $hostheaders.Add($hostheader, 1) }
					
					if( -not [String]::IsNullOrEmpty($binding.Hostname) )
					{
						$ip = nslookup $binding.HostName 
						if( -not $internal_ip.ContainsKey($ip) -and $ip.ToString() -ne "False" ) { $internal_ip.Add($ip, 1) }
					}
				}
										
				$audit | Add-Member -type NoteProperty -Name Uri -Value ([String]::Join( "`n", $hostheaders.keys ))
				$audit | add-member -type NoteProperty -name Internal_x0020_IP -Value ([String]::Join( ";", $internal_ip.keys))
						
				$VirtualDirectoryQuery = "Select AppPoolId, Name, Path from IISWebVirtualDirSetting where Name like '%" + $site.Name + "/%'"
				$wmi_virtual_directories = [WmiSearcher] $VirtualDirectoryQuery
				$wmi_virtual_directories.Scope.Path = "\\{0}\root\microsoftiisv2" -f $Server
				$wmi_virtual_directories.Scope.Options.Authentication = 6
				
				$virtual_directories = $wmi_virtual_directories.Get() | Select -Expand Name
				
				$iis_path = $wmi_virtual_directories.Get() | Where { $_.Name -eq ($site.Name + "/ROOT" ) } | Select -Expand Path
				$app_pool_id = $wmi_virtual_directories.Get() | Where { $_.Name -eq ($site.Name + "/ROOT" ) } | Select -Expand  AppPoolId
				
				$audit | add-member -type NoteProperty -name IISPath -Value $iis_path
				$audit | add-member -type NoteProperty -name AppPoolName -Value $app_pool_id
				
				$AppPoolQuery = "Select WAMUserName from IIsApplicationPoolSetting where Name = 'W3SVC/AppPools/" + $app_pool_id + "'"
						
				$wmi_app_pool = [WmiSearcher] $AppPoolQuery
				$wmi_app_pool.Scope.Path = "\\{0}\root\microsoftiisv2" -f $Server
				$wmi_app_pool.Scope.Options.Authentication = 6
				
				$app_pool_user = $wmi_app_pool.Get() | Select -Expand WAMUserName
				
				$audit | add-member -type NoteProperty -name AppPoolUser -Value $app_pool_user

				$audit_results += $audit
				
				if( $filter_type -eq "url" ) { break }
			}
		}
	} else {
		Write-Host $_ "appears down. Will not continue with audit"
	}
}

if( $upload ) 
{
	$sites = $audit_results | Group-Object WebApplication -asHashTable
	
	foreach( $site in $sites.Keys )
	{	
		$uploaded_site_info = New-Object System.Object
	
		$sites_are_equal = $true		
		foreach( $prop in ($sites[$site] | Get-Member | Where {$_.MemberType -eq "NoteProperty" -and $_.Name -ne "RealServers" } | Select -Expand Name) )
		{
			$v = $sites[$site] | Select $prop -Unique
		
			if( ($v | Measure-Object).Count -ne 1 )
			{
				Write-Host $prop " for " $site " differs between the different servers. . . "  -ForegroundColor Yellow
				$sites_are_equal = $false
			}

			$uploaded_site_info | Add-Member -type NoteProperty -Name $prop -Value ( $v | Select -First 1 -ExpandProperty $prop)

		}

		if( -not $sites_are_equal )
		{	
			Write-Host "The sites configuration differs between the servers provided. Here is results of the scan . . ."
			$sites[$site]
			
			do {
				$ans = Read-Host "Do you wish to still upload (y/n) " 
			} while ( ($ans -ne "y") -and ($ans -ne "n") )
			
			if( $ans = "y" ) { $sites_are_equal = $true }
		}
			
		if( $sites_are_equal )
		{
			$uploaded_site_info | Add-Member -type NoteProperty -Name Real_x0020_Servers -Value ( Get-SPFormattedServers ( ($sites[$site] | Select -ExpandProperty "RealServers") ) )	
			WriteTo-SPListViaWebService -url $url -list $list_websites -Item (Convert-ObjectToHash $uploaded_site_info ) -TitleField WebApplication 
		}
	}
}
else 
{
	return $audit_results
}
