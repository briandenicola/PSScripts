[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[Parameter(Mandatory=$true)]
	[String[]] $computers,
	[switch] $upload,
	
	[ValidateSet("all", "name")]
	[string] $filter_type = "all",
	[string] $filter_value,

    [ValidateSet("test", "uat","prod", "dev")]
	[string] $env = "prod"
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

$url = "http://teamadmin.gt.com/sites/ApplicationOperations/applicationsupport/"
$list_servers = "AppServers"

if( $env -eq "dev" ) {
    $list_websites = "Applications - Dev"
} elseif ( $env -eq "uat" ) {
    $list_websites = "Applications - UAT"
} elseif ( $env -eq "test") {
    $list_websites = "Applications - Test"
} else {
    $list_websites = "Applications - Production"
}

function Get-SPFormattedServers ( [String[]] $computers )
{
	$sp_formatted_data = [String]::Empty
	$sp_server_list = get-SPListViaWebService -url $url -list $list_servers
	
	foreach( $computer in $computers ) { 
		$id = $sp_server_list | where { $_.SystemName -eq $computer } | Select -ExpandProperty ID
		$sp_formatted_data += "#{0};#{1};" -f $id, $computer
	}
	
	Write-Verbose $sp_formatted_data
	return $sp_formatted_data.TrimStart("#").TrimEnd(";").ToUpper()
}

if( $filter_type -eq "name" -and [String]::IsNullOrEmpty($filter_value) ) {
	Write-Error "The switch filter_value cannot be null if filter_type is name" 
	exit
}

$iis_audit_sb = {
	param (
		[string] $site = [string]::empty
	)

	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")

	$audit = @()
    if( [string]::IsNullOrEmpty($site) ) {
	    $webApps = Get-WebSite
    } 
    else {
        $webApps = @( Get-WebSite | Where { $_.Name -eq $site } )
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
        $vdirs = @(Get-WebVirtualDirectory -Site  $webApp.Name | Select -ExpandProperty Path)
        $cert =  Get-ChildItem "IIS:\SslBindings" | Where { $_.Sites -eq $webApp.Name } | Select -Expand Thumbprint

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
        })
	}

    return $audit
}

$audit_results = Invoke-Command -ComputerName $computers -ScriptBlock $iis_audit_sb  -ArgumentList $filter_value | 
    Select RealServers, Title, IISId, LogFileDirectory, LogFileFlags, Urls, Internal_x0020_IP, DotNetVersion, VirtualDirectories, CertThumbprint, IISPath, AppPoolName, AppPoolUser

if( $upload ) {
	$sites = $audit_results | Group-Object Title -asHashTable
	
	foreach( $site in $sites.Keys ) {	
		$uploaded_site_info = New-Object System.Object
	
		$sites_are_equal = $true		
		foreach( $prop in ($sites[$site] | Get-Member | Where {$_.MemberType -eq "NoteProperty" -and $_.Name -ne "RealServers" } | Select -Expand Name) ) {
			$v = $sites[$site] | Select $prop -Unique
		
			if( ($v | Measure-Object).Count -ne 1 ) {
				Write-Host $prop " for " $site " differs between the different servers. . . "  -ForegroundColor Yellow
				$sites_are_equal = $false
			}

			$uploaded_site_info | Add-Member -type NoteProperty -Name $prop -Value ( $v | Select -First 1 -ExpandProperty $prop)

		}

		if( -not $sites_are_equal ) {	
			Write-Host "The sites configuration differs between the servers provided. Here is results of the scan . . ."
			$sites[$site]
			
			do {
				$ans = Read-Host "Do you wish to still upload (y/n) " 
			} while ( ($ans -ne "y") -and ($ans -ne "n") )
			
			if( $ans = "y" ) { $sites_are_equal = $true }
		}
			
		if( $sites_are_equal ) {
			$uploaded_site_info | Add-Member -type NoteProperty -Name Real_x0020_Servers -Value ( Get-SPFormattedServers ( ($sites[$site] | Select -ExpandProperty "RealServers") ) )	
			WriteTo-SPListViaWebService -url $url -list $list_websites -Item (Convert-ObjectToHash $uploaded_site_info ) -TitleField Title 
		}
	}
}
else {
	return $audit_results
}