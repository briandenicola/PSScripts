[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[string] $url,
    [switch] $sharepoint,
	[switch] $upload
)

$ErrorActionPreference = 'silentlycontinue'

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

if( $sharepoint ) {
	$team_url = "http://example.com/sites/AppOps/"
	$app_list = "WebApplications"
	$ssl_list = "SSL Certificates"
}
else {
	$team_url = "http://example.com/sites/AppOps/"
	$app_list = "Applications - Production"
	$ssl_list = "SSL Certs"
}

function Get-SPFormattedServers 
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

function main
{
    if( $url -notmatch "https://" ) {
		write-Host "$url does not contain https://" -ForegroundColor Red
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
		Servers = Get-SPFormattedServers -url $url
	}
	
    Write-Host "[ $(Get-Date) ] - Found cert - $cert . . ."
	if(	$upload ) {
		$ans = Read-Host "Do you wish to Upload this certificate ? (y/n)"
		if( $ans.ToLower() -eq "y" ) {
			WriteTo-SPListViaWebService -url $team_url -list $ssl_list -Item (Convert-ObjectToHash $cert) -TitleField CommonName 
		}
	}
}
main