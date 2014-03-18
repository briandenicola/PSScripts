[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[Parameter(Mandatory=$true)]
	[String[]] $computers,
	[switch] $upload,
	
	[ValidateSet("all", "name", "url")]
	[string] $filter_type = "all",
	[string] $filter_value,

    [ValidateSet("Test", "Uat","Production", "Dev")]
	[string] $env = "Production"
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

$url = "http://teamadmin.gt.com/sites/ApplicationOperations/applicationsupport/"
$list_servers = "AppServers"
$list_websites = "Applications - $env"

function Get-ObjectProperties
{
    param( [object] $psobject )
    return ( $psobject | Get-Member | Where {$_.MemberType -eq "NoteProperty"} | Select -Expand Name) 
}

function Get-SPFormattedServers 
{
    param ( [string[]] $computers )

	$sp_formatted_data = @()
	$sp_server_list = Get-SPListViaWebService -url $url -list $list_servers
	
	foreach( $computer in $computers ) { 
		$sp_formatted_data += "{0};#{1}" -f ($sp_server_list | Where { $_.SystemName -eq $computer }).ID, $computer.ToUpper()
	}
	
	return ( [string]::join( ";#", $sp_formatted_data ) )
}

if( $filter_type -imatch "url|name" -and [String]::IsNullOrEmpty($filter_value) ) {
	Write-Error "The switch filter_value cannot be null if filter_type is name" 
	exit
}

$iis_audit_sb = {
	param (
        [string] $filter_type,
		[string] $filter_value
	)

    $ErrorActionPreference = "SilentlyContinue"

	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")

    $audit = @()
    if( $filter_type -eq "name" ) {
        $webApps = @( Get-WebSite | Where { $_.Name -eq $filter_value } )
	}
    elseif( $filter_type -eq "url" ) {
        $site = Get-WebBinding -HostHeader $filter_value -ErrorAction SilentlyContinue
        $webApps = @( Get-WebSite | Where { $_.Name -eq $site.ItemXPath.Split("=")[1].Split("'")[1] } )
    }
    else {
        $webApps = @( Get-WebSite )
    }


    if( $webApps.Length -eq 0 ) {
        throw "Could not find any IIS configuration for $filter_value"
        return
    }

	foreach( $webApp in $webApps ){
        
        $app_pool = Get-Item ("IIS:\AppPools\" + $webApp.applicationPool)
        
        if( $app_pool.ProcessModel.identityType -eq "ApplicationPoolIdentity" ) {
            $app_pool_user =  "ApplicationPoolIdentity"
        } 
        else {
            $app_pool_user = $app_pool.ProcessModel.userName
        }

        $bindings = @(Get-WebBinding -Name $webApp.Name | Where { $_.Protocol -imatch "http|https" } | Select -ExpandProperty BindingInformation)
        $vdirs = @(Get-WebVirtualDirectory -Site  $webApp.Name | Select -Expand Path)
        $cert =  @(Get-ChildItem "IIS:\SslBindings" | Where { $_.Sites -eq $webApp.Name } | Select -Expand Thumbprint)
        $web_applications = @(Get-WebApplication -Site $webApp.Name | Select @{N="App";E={"({0},{1},{2})" -f $_.Path,$_.PhysicalPath,$_.ApplicationPool}} | Select -ExpandProperty App )

        $ips = @()
        foreach( $binding in $bindings ) {
            $hostname = $binding.Split(":")[2]
            if( [string]::IsNullorEmpty($hostname) ) {
                $ips += nslookup $env:COMPUTERNAME
            }
            else {
                $ips += nslookup $hostname
            }
        }

        $audit += (New-Object PSObject -Property @{
            RealServers = $env:COMPUTERNAME
            Title = $webApp.Name
            IISId = $webApp.Id
            LogFileDirectory = (Join-Path $webApp.LogFile.Directory ("W3SVC" + $webApp.Id))
            LogFileFlags =  ($webApp.LogFile.logFormat + ":" + $webApp.LogFile.logExtFileFlags) 
            URLs = [string]::join(";", $bindings)
            Internal_x0020_IP = [string]::join(";", $ips)
            DotNetVersion = $app_pool.ManagedRunTimeVersion
            VirtualDirectories = [string]::join(";", $vdirs)
            IISPath = $webApp.PhysicalPath
            AppPoolName = $webApp.applicationPool
            AppPoolUser = $app_pool_user
            CertThumbprint = $cert 
            WebApplication = [string]::join(";", $web_applications)
        })
	}

    return $audit
}

$audit_results = Invoke-Command -ComputerName $computers -ScriptBlock $iis_audit_sb  -ArgumentList $filter_type, $filter_value | 
    Select RealServers, Title, IISId, LogFileDirectory, LogFileFlags, Urls, Internal_x0020_IP, DotNetVersion, VirtualDirectories, CertThumbprint, IISPath, AppPoolName, AppPoolUser, WebApplication

if( $upload ) {
	$sites = $audit_results | Group-Object Title -asHashTable
	
	foreach( $site in $sites.Keys ) {	
		$uploaded_site_info = New-Object PSObject -Property  @{
            Real_x0020_Servers = [string]::empty
            Title = [string]::empty
            IISId = [string]::empty
            LogFileDirectory = [string]::empty
            LogFileFlags =  [string]::empty 
            URLs = [string]::empty
            Internal_x0020_IP = [string]::empty
            DotNetVersion = [string]::empty
            VirtualDirectories = [string]::empty
            IISPath = [string]::empty
            AppPoolName = [string]::empty
            AppPoolUser = [string]::empty
            CertThumbprint = [string]::empty
            WebApplication = [string]::Empty
        }
	
		$sites_are_equal = $true		
		foreach( $property in ( Get-ObjectProperties -psobject $sites[$site] | Where { $_ -notcontains "RealServers" } ) ) {
			$values = $sites[$site] | Select $property -Unique
		
			if( ($values | Measure-Object).Count -ne 1 ) {
				Write-Warning ($property + " for " + $site + " differs between the different servers. . . ")
				$sites_are_equal = $false
			}

			$uploaded_site_info.$property = ($values | Select -First 1 -ExpandProperty $property)
		}

		if( -not $sites_are_equal ) {
			$ans = Read-Host "he sites configuration differs between the servers provided.Do you wish to still upload (y/n) " 
			if( $ans -imatch "y|Y" ) { $sites_are_equal = $true }
		}
			
		if( $sites_are_equal ) {
			$uploaded_site_info.Real_x0020_Servers = ( Get-SPFormattedServers ( ($sites[$site] | Select -ExpandProperty "RealServers") ) )	
			WriteTo-SPListViaWebService -url $url -list $list_websites -Item (Convert-ObjectToHash $uploaded_site_info) -TitleField Title 
		}
	}
}
else {
	return $audit_results
}