#############################
#Script - 
#Author - Brian Denicola
#############################

param (
	[string] $cfg = "",
	[string] $log = "",
	[switch] $help = $false
)

. ..\Libraries\Standard_functions.ps1
. ..\Libraries\SharePoint_functions.ps1

$global:Version = "1.0.0"
$global:LogFile = $log

if( $cfg -eq "" ) { $global:Config = $PWD.ToString() + "\render_config.xml" } else { $global:Config = $cfg }

function Usage() 
{
	$helpTxt=""
	
	Write-Host $helpTxt
}

function log( [string] $txt ) 
{
	"[" + (Get-Date).ToString() + "]," + $txt | Out-File $global:LogFile -Append -Encoding ASCII 
}

function main() 
{
	if($help) { Usage; exit }

	$cfgFile = [xml]( gc $global:Config )

	if( $global:LogFile -eq "" ) { $global:LogFile = $cfgFile.scrap.log }

	$cfgFile.scrap.urls.url | % {
		$wc = New-Object System.Net.WebClient
		$wc.Credentials = [System.Net.CredentialCache]::DefaultCredentials
	
		Write-Host "Working on" $_.site
		
		$time_before_url_get = Get-Date
		
		$fileByteArray = $wc.DownloadData($_.site)
				
		$time_after_url_get = Get-Date
		
		$diff_in_seconds = ($time_after_url_get - $time_before_url_get).TotalSeconds
		
		log($_.site + "," + $time_before_url_get.ToLongTimeString() + "," + $time_after_url_get.ToLongTimeString() + "," + $diff_in_seconds + "," + ($fileByteArray.Length/1024) )
	
		Write-Host "Sleeping . . . "
		$wc.Dispose()
		start-sleep -s 10
	}
}
main
