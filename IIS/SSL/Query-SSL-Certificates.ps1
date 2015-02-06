[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch] $sharepoint,
	[switch] $upload,

    [Parameter(ParameterSetName='ByComputer')]
	[string[]] $computers,
    [switch] $parallel,

    [Parameter(ParameterSetName='ByUri')]
    [string] $url
)

$ErrorActionPreference = 'silentlycontinue'

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

if( $sharepoint ) {
	$team_url = "http://teamadmin.gt.com/sites/ApplicationOperations/"
	$app_list = "WebApplications"
    $server_list = "Servers"
	$ssl_list = "SSL Certificates"
    $view = "{3221E5C1-5B42-4F58-934B-A5C5BDED3415}"
}
else {
	$team_url = "http://teamadmin.gt.com/sites/ApplicationOperations/applicationsupport/"
	$app_list = "Applications - Production"
	$ssl_list = "SSL Certs"
    $server_list = "AppServers"
    $view = $null
}

function Get-SPFormattedServersByServers 
{
    param(
         [String[]] $computers 
    )

	$sp_formatted_data = [String]::Empty
	$sp_server_list = Get-SPListViaWebService -url $team_url -list $server_list -view $view
	
	$computers | % { 
		$computer = $_
		$id = $sp_server_list | where { $_.SystemName -eq $computer } | Select -ExpandProperty ID
		$sp_formatted_data += "#{0};#{1};" -f $id, $computer
	}
	
	Write-Verbose $sp_formatted_data
	
	return $sp_formatted_data.TrimStart("#").TrimEnd(";").ToUpper()
}

function Get-SPFormattedServersByURL 
{
    param (
        [String] $url
    )

    Write-Host "[ $(Get-Date) ] - Getting the servers assgined to $url . . ."
	$sp_server_list = Get-SPListViaWebService -url $team_url -list $app_list
    	
    if( $sharepoint ) { 
        return ( $sp_server_list | Where { $_.Uri -imatch $url.TrimStart("https://") } | Select -First 1 | Select -Expand "Real Servers" )
    } 
    else {
        return ( $sp_server_list | Where { $_.Urls -imatch $url.TrimStart("https://") } | Select -First 1 | Select -Expand WebServers )
    }
}

function Get-CertFromComputer
{
    if( $parallel ) {
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
    else {
	    $certs_from_server = @()
	    foreach( $computer in $computers ) {
		    Write-Host "Working on $computer  . . ."
		    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("\\$computer\My","LocalMachine")
		    $store.Open("ReadOnly")
		    $certs_from_server += $store.Certificates | 
			    Select Issuer, NotAfter, Thumbprint, Subject, @{Name="ComputerName";Expression={$computer}} |
			    Where { -not $_.Subject.Contains($computer) -and -not [String]::IsNullOrEmpty($_.Subject) } |
			    Sort Thumbprint	
	    }
	    $cert_hashes = $certs_from_server | Group-Object Thumbprint -AsHashTable
    }

    $certs = @()
    $cert_hashes.Keys | % {   
	    $certs += (New-Object PSObject -Property @{
		    CommonName = ($cert_hashes[$_] | Select -first 1 -Expand Subject).Split(",")[0].Split("=")[1] 
		    Thumbprint = $cert_hashes[$_] | Select -first 1 -Expand Thumbprint
		    Issuer = $cert_hashes[$_] | Select -first 1 -Expand Issuer
		    ExpirationDate = ($cert_hashes[$_] | Select -first 1 -Expand NotAfter).ToString("yyyy-MM-ddThh:mm:ssZ")
		    Servers = Get-SPFormattedServersByServers ($cert_hashes[$_] | Select -Expand ComputerName)
	    })
    }

    return $certs
}

function Get-CertFromUrl 
{
    param ( 
        [string] $url
    )

    if( $url -notmatch "https://" ) {
		write-Host "$url does not contain https://" -ForegroundColor Red
        return
	}
    
    Write-Host "[ $(Get-Date) ] - Request default page at $url . . ."
    $req = [Net.HttpWebRequest]::Create($url)

    $req.GetResponse() |Out-Null

    Write-Host "[ $(Get-Date) ] - Got response and parsing the reply for the certificate . . ."
    $server_cert = $req.ServicePoint.Certificate

    Write-Host "[ $(Get-Date) ] - Building Cert Object . . ."
	$cert = New-Object PSObject -Property @{
		CommonName = $server_cert.Subject.Split(",")[0].Split("=")[1]
		Thumbprint = $server_cert.GetCertHashString()
		Issuer = $server_cert.Issuer
		ExpirationDate = ( Get-Date( $server_cert.GetExpirationDateString()) ).ToString("yyyy-MM-ddThh:mm:ssZ")
		Servers = Get-SPFormattedServersByURL -url $url
	}

    return $cert 
}

function main
{
    switch ($PsCmdlet.ParameterSetName) {
        ByComputer { 
            $certs = Get-CertFromComputer
        }
        ByUri { 
            $certs = Get-CertFromUrl -url $url
        }
    }
	
    foreach( $cert in $certs ) {
		$cert | Format-List
		if(	$upload ) {
			$ans = Read-Host "Do you wish to Upload this certificate ? (y/n)"
			if( $ans.ToLower() -eq "y" )  { WriteTo-SPListViaWebService -url $team_url -list $ssl_list -Item (Convert-ObjectToHash $cert) -TitleField CommonName }
		}
	}
}
main