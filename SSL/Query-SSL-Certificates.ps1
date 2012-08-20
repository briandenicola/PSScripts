[CmdletBinding(SupportsShouldProcess=$true)]
param(

	[string[]] $computers,
	[string] $application,
	[switch] $upload,
	[switch] $parallel
)

. ..\libraries\Standard_Functions.ps1
. ..\libraries\SharePoint_Functions.ps1

if( $application -eq "sharepoint" )
{
	$url = "http://collaboration.gt.com/site/SharePointOperationalUpgrade/"
	$server_list = "Servers"
	$ssl_list = "SSL Certificates"
	$view = "{1AA58C6F-86FC-42F5-9936-357CF8580BC1}"
}
else
{
	$url = "http://collaboration.gt.com/site/SharePointOperationalUpgrade/applicationsupport/"
	$server_list = "AppServers"
	$ssl_list = "SSLCerts"
	$view = $null
}

function Get-SPFormattedServers ( [String[]] $computers )
{
	$sp_formatted_data = [String]::Empty
	$sp_server_list = get-SPListViaWebService -url $url -list $server_list -view $view
	
	$computers | % { 
		$computer = $_
		$id = $sp_server_list | where { $_.SystemName -eq $computer } | Select -ExpandProperty ID
		$sp_formatted_data += "#{0};#{1};" -f $id, $computer
	}
	
	Write-Verbose $sp_formatted_data
	
	return $sp_formatted_data.TrimStart("#").TrimEnd(";").ToUpper()
}

if( $parallel )
{
	$sb = {
		$certs = Get-ChildItem -path cert:\LocalMachine\My | 
			Select Issuer, NotAfter, Thumbprint, Subject, @{Name="ComputerName";Expression={$ENV:Computername}} |
			where { -not $_.Subject.Contains($ENV:Computername) -and -not [String]::IsNullOrEmpty($_.Subject) } |
			Sort Thumbprint	
		return $certs
	}

	$job = Invoke-Command -Computer	$computers -ScriptBlock $sb -AsJob
	Get-Job -id $job.id | Wait-Job | Out-Null
	$cert_hashes = Receive-Job -Id $job.id | Group-Object Thumbprint -AsHashTable
}
else
{
	$certs = @()
	foreach( $computer in $computers )
	{
		Write-Host "Working on $computer  . . ."
		$store = New-Object System.Security.Cryptography.X509Certificates.X509Store("\\$computer\My","LocalMachine")
		$store.Open("ReadOnly")
		$certs += $store.Certificates | 
			Select Issuer, NotAfter, Thumbprint, Subject, @{Name="ComputerName";Expression={$computer}} |
			Where { -not $_.Subject.Contains($computer) -and -not [String]::IsNullOrEmpty($_.Subject) } |
			Sort Thumbprint	
	}
	$cert_hashes = $certs | Group-Object Thumbprint -AsHashTable
}

$cert_hashes.Keys | % {   
			
	$cert = New-Object PSObject -Property @{
		CommonName = ($cert_hashes[$_] | Select -first 1 -Expand Subject).Split(",")[0].Split("=")[1] 
		Thumbprint = $cert_hashes[$_] | Select -first 1 -Expand Thumbprint
		Issuer = $cert_hashes[$_] | Select -first 1 -Expand Issuer
		ExpirationDate = ($cert_hashes[$_] | Select -first 1 -Expand NotAfter).ToString("yyyy-MM-ddThh:mm:ssZ")
		Servers = ($cert_hashes[$_] | Select -Expand ComputerName)
	}
	
	if( $cert -ne $nul ) 
	{	
		$cert | Format-List
		
		if(	$upload ) 
		{
			$ans = Read-Host "Do you wish to Upload this certificate ? (y/n)"
			if( $ans.ToLower() -eq "y" )
			{
				$cert.Servers = Get-SPFormattedServers $cert.Servers
				WriteTo-SPListViaWebService -url $url -list $ssl_list -Item (Convert-ObjectToHash $cert) -TitleField CommonName 
			}
		}
	}
}
