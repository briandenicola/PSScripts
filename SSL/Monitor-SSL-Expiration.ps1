param (
	[string] $cfg = ""
)

. ..\libraries\SharePoint_Functions.ps1
. ..\libraries\Standard_Functions.ps1

function format-Servers( [string] $servers )
{
	$tmp = ($servers -replace ";#\d{1,3}", " ").Split(";#")
	return ( [string]::join("", $tmp[1 .. $tmp.Length]) )
}

$global:Version = "1.0.0"
$expiredCerts = $nul

if( $cfg -eq "" ) { $global:Config = $PWD.ToString() + "\ssl_config.xml" } else { $global:Config = $cfg }

$to = @()
$cfgFile = [xml]( gc $global:Config )
$t = $(get-Date).AddDays($cfgFile.ssl.expiration)

$expiredCerts = Get-SPListViaWebService -url $cfgFile.ssl.url -list $cfgFile.ssl.list | where { (Get-Date($_.ExpirationDate)) -lt $t }
	
if( $expiredCerts -ne $nul ) 
{
	$body = "The following Certs have or will expire by " + $t.ToString() + " :`n"
	$expiredCerts | % { 
		$body += $_.CommonName + " - " + $_.ExpirationDate + " on " + (Format-Servers($_.Servers)) + "`n"
	}
	
	$cfgFile.timer.operators.operator | % { $to += $_.pager }
	send-email -subject "Upcoming Cert Expiration" -body $body -to $to
}
