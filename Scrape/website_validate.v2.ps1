#############################
#Script - scrap.ps1
#Author - Brian Denicola
#Purpose - To scrap a website for key words and page the operator if there is an error
#Current Version - 2.0.0
#
#History
#Version 1.0.0 - 8/21/2008 - Initial code 
#Version 1.0.1 - 7/14/2010 - Updated for GT
#Version 2.0.0 - 2/4/2012 - Updated for SP2010
#Version 2.1.0 - 3/1/2012 - Updated for SP2010 with Cycle Suppression
#Version 2.5.0 - 9/28/2012 - Updated to just check a server directly and to only cycle an application pool.
#############################

[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[string] $cfg = ""
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

Set-Variable -Name iis_script -Value (Join-Path $ENV:SCRIPTS_HOME "IIS\cycle_app_appool.ps1") -Option Constant

$global:Version = "2.5.0"

if( $cfg -eq "" ) { $global:Config = $PWD.ToString() + "\scrap_config.xml" } else { $global:Config = $cfg }

function Check-Site()
{
	param(
		[string] $server,
		[string] $site,
		[int] $timeout,
		[ValidateSet("HEAD", "POST", "GET")]
		[string] $method
	)
	
	try {
		Write-Verbose ( "Getting " + $site + " on " + $server )
	
		if( $cfgFile.scrap.direct -eq $true ) {
			$request = Get-Url -url $site -Method $method -Timeout $timeout
		}
		else {
			$request = Get-Url -url $site -Server $server -Method $method -Timeout $timeout
		}
				
		if( $request -imatch $good_status_code ) {
			$response_time = ( $request -imatch "Total Time").Split("=")[1]
			log -txt ("{0} [{1}] - State: OK {2}" -f $site, $server, $response_time) -log $global:LogFile
		}
		else {
			$error_code = $request -imatch "Status Code"
			throw ("Did not receive a " + $good_status_code  + " from Web Server. Received " + $error_code)
		}
	}
	catch {
		Cycle-IIS -url $url -Msg $_.Exception.ToString()
	}
}

function Check-AlertSend
{
	$send_alert = $false
	$now = $(Get-Date)
		
	if( $now.Hour -ge $start_time -and $now.Hour -lt $end_time ) {
		$send_alert  = $true
	}
	
	Write-Verbose "Timeframe for Alerts - $send_alert" 
	
	return $send_alert  
}

function Check-Lastcycle
{
	param(
		[datetime] $last
	)
	$send_alert = $false
	$now = $(Get-Date)
		
	if( $last -eq $null -or (($now - $last).TotalMinutes -gt $cycle_suppression )) {
		$send_alert = $true
	}

	Write-Verbose ("Last time IIS was cycled was - " + $last + " and Cycle Supression is configured at " + $cycle_suppression + " minutes")
	Write-Verbose ("Outside of Cycle Supression - " + $send_alert)
	
	return $send_alert  
}

function Cycle-IIS()
{
	param(
		[object] $url,
		[string] $msg
	)
	
	$subject = "[" + $(Get-Date) + "] - " + $cfgFile.scrap.app + " is down . . ."
	$description = "Page was received. Application Pools for " +  $cfgFile.scrap.app + " were autocycled."
	$operators = @()
	$cfgFile.scrap.operators.operator | % { $operators += $_.pager }

	$subject = $cfgFile.scrap.app + " alert! "
	$body = "{0} [{1}] - State: DOWN! `n {2}" -f $url.site, $url.server, $msg

	log -txt $body -log $global:LogFile

	if( Check-AlertSend -eq $true ) {
		if( $cfgFile.scrap.auto_cycle -eq $true ) {
			if( Check-LastCycle $url.last_cycle -eq $true )	{
				$subject += " Going to Auto Cycling on " + $url.server
			
				$txt = "Cycling IIS on " + $url.server + " for " + $url.site
				log -txt $txt -log $global:LogFile
				Write-Verbose $txt
			
				$url.last_cycle = $(Get-Date).ToString()
				
				if( $cfgFile.scrap.cycle_type -eq "AppPool" ) {
					&$iis_script -computers $url.server -app $cfgFile.scrap.app -record -description $description
				} 
				else { 
					&$iis_script -computers $url.server -app $cfgFile.scrap.app -record -description $description -full
				}
			}
			else {
				$subject += "Issue with IS on " + $url.server + " for " + $url.site + " but within Cycle Suppression"
				Write-Verbose $subject
				log -txt $subject -log $global:LogFile
			}
		}
		
		if( $cfgFile.scrap.alerts -eq $true ) {
			$txt = "Sending email alert on " + $url.server
			
			Write-Verbose $txt
			Write-Verbose ("Subject - " + $subject)
			Write-Verbose ("Body - " + $body)
			
			log -txt $txt -log $global:LogFile
		
			send-email -s $subject -b $body -to $operators 
		}
	} 
	else {
		$txt = "There was an issue found with " + $url.site + " on " + $url.server + " but out side the alerting window. Will Log only"
		Write-Verbose $txt
		log -txt $txt -log $global:LogFile
	}

}

function main() 
{
	$global:LogFile = $cfgFile.scrap.log
	
	$good_status_code = "Status Code = OK"
	foreach( $url in $cfgFile.scrap.urls.url ) {
		Write-Verbose ("URL: " + $url.site)
		Write-Verbose ("Server: " + $url.server)
	
		$timeout = 10
		if( ![String]::IsNullOrEmpty($url.timeout) ) {
			$timeout = $url.timeout
		} 
		Write-Verbose ("Time Out: " + $timeout)

		$method = "HEAD"
		if( ![String]::IsNullOrEmpty($url.method) ) {
			$method = $url.method
		} 
		Write-Verbose ("Method: " + $method)
		
		Check-Site -site $url.site -server $url.server -timeout $timeout -method $method
		$cfgFile.Save( (dir $global:Config).FullName )
	}
}

$cfgFile = [xml]( gc $global:Config )
$cycle_suppression = $cfgFile.scrap.CycleSuppression
$start_time = $cfgFile.scrap.StartTime
$end_time = $cfgFile.scrap.EndTime
main
