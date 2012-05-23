param (	
	[Parameter(Mandatory=$true)]
	[string] $src_url,	
	
	[Parameter(Mandatory=$true)]
	[string] $dst_url,
	
	[switch] $silent,
	[string] $log = ".\dotnet_webfarm_code_deploy.log"
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")

Set-Variable -Name now -Value $(Get-Date).ToString("yyyyMMddhhmmss") -Option Constant
Set-Variable -Name backup_directory -Value "\\ent-nas-fs01.us.gt.com\app-ops\Code\Custom-.NET-Applications" -Option Constant
Set-Variable -Name list_url -Value "http://collaboration.gt.com/site/SharePointOperationalUpgrade/applicationsupport/" -Option Constant
Set-Variable -Name farm_view -Value "{17733A69-F4B2-452E-8D6E-AD09AEBDDA5F}" -Option Constant
Set-Variable -Name controller_view -Value "{2A0B8DA0-1378-405A-A532-FA88FC690ECD}" -Option Constant
Set-Variable -Name deploy_tracker -Value "Deployment Tracker" -Option Constant

function log( [string] $txt ) 
{
	$txt = "[" + (Get-Date).ToString() + "] - " + $txt + " . . . "	
	Write-Host $txt
	$txt | Out-File -Append -Encoding Ascii $log
}

function Get-WebFarmAndEnvironment( [string] $url )
{
	log -txt "Going to determine Web farm and environment for $url" 
	
	$webApp = Get-SPListViaWebService -Url $list_url -list WebSites -view $farm_view | 
		Where { $_.URLs -match ("(http|https)://" + $url) } | 
		Select -First 1 SiteName, Farm, Environment
	
	if( $webApp -eq $null ) {
		throw ( "Could not find " + $url + " in " + $list_url )
	}
	
	log -txt ("Found $url in " + $webApp.Farm + "'s " + $webApp.Environment + " environment") 

	return $webApp
}

function Get-FarmController( [Object] $webFarm )
{		
	log -txt ("Going to determine Web Farm Controller for the " + $webFarm.Farm  + " " + $webFarm.Environment + " farm" )
	
	$controller = Get-SPListViaWebService -Url $list_url -list AppServers -view $controller_view | 
		Where { $_.Environment -eq $webFarm.Environment -and $_.Farm -eq $webFarm.Farm } |
		Select -ExpandProperty SystemName
	
	if( $controller -eq $null ) {
		throw ("Could not find a web farm controller for "  + $webFarm.Farm )
	}

	log -txt "Found web farm controller - $controller"
		
	return $controller
}

function Get-IISPath( [string] $server, [string] $site )
{
	$path = Invoke-Command -ComputerName $server -ScriptBlock {
		param ( [string] $site)
		. D:\Scripts\Libraries\IIS_Functions.ps1
		return ( Get-WebFilePath "IIS:\Sites\$site" | Select -ExpandProperty FullName )
	} -ArgumentList $site

	if( $path -eq $null ) {
		throw ("Could not find a physical path for " + $site + " on " + $server )
	}

	log -txt "Found physical path of $path for site - $site"
	
	return ( "\\" + $server + "\" + $path.Replace(":","$") )
}

function Get-IISMap( [string] $url )
{
	$app = Get-WebFarmAndEnvironment -url $url	
	$controller = Get-FarmController -webFarm $app
	
	$map = New-Object PSObject -Property @{
		Controller = $controller
		Directory = (Get-IISPath -server $controller -site $app.SiteName)
		Farm = $app.Farm
		Environment = $app.Environment
	}

	return $map
}

function Get-SPUserViaWS( [string] $url, [string] $name )
{
	$service = New-WebServiceProxy ($url + "_vti_bin/UserGroup.asmx?WSDL") -Namespace User -UseDefaultCredential
	$user = $service.GetUserInfo($name)
	
	if( $user ) 
	{
		return ( $user.user.id + ";#" + $user.user.Name )
	} 
	else
	{
		return $null
	}	
}

function main()
{
	log -txt "** Going to deploy code to $dst_url from $src_url **"
	
	#Strip http or http from passed parameter
	$src_url = $src_url -replace "(http|https)://"
	$dst_url = $dst_url -replace "(http|https)://"
	
	try {
	
		$src_map = Get-IISMap -url $src_url
		$dst_map = Get-IISMap -url $dst_url	

		log -txt ("Source Map - " + $src_map)
		log -txt ("Destination  Map - " + $dst_map)
		
		if( -not $silent ) { Pause }

		$backup_location = $backup_directory + "\" + $dst_url + "-" + $now
		log -txt "Backup Existing Application to $backup_location"
		mkdir $backup_location
		Copy-Item $dst_map.Directory $backup_location  -Verbose -recurse 
		
		if( -not $silent ) { Pause }
		
		log -txt "Going to copy the files (minus web.config) from " + $src_map.Directory + " to " + $dst_map.Directory
		Set-Content "web.config" -Encoding Ascii -Path exclude_files
		xcopy /e/v/f/s $src_map.Directory $dst_map.Directory /EXCLUDE:exclude_files
		Remove-Item exclude_files -Force
		
		log -txt "`tDeploy complete to $dst_url . . . Now will sync the Web Farm"
		Invoke-Command -ComputerName $dst_map.Controller -ScriptBlock {
			param( [string] $farm )
			. D:\Scripts\Libraries\IIS_Functions.ps1
			Sync-WebFarm $farm
		} -ArgumentList $dst_map.Farm
		
		if( -not $silent ) { Pause }
		
		$deploy = New-Object PSObject -Property @{
			Title = "Automated .NET Deployment for - " + $dst_url
			Application = "59;#Custom .NET Application"
			DeploymentType = "Full"
			Deployment_x0020_Steps = "Automated with " + $MyInvocation.ScriptName + ". Log file located on " + $ENV:COMPUTERNAME + " - " + (dir $log).FullName
			Notes = "Code location is at " + $backup_location
		}
		
		if( $dst_map.Environment -imatch "UAT" )
		{
			$deploy | Add-Member -MemberType NoteProperty -Name UAT_x0020_Deployment -Value $(Get-Date).ToString("yyyy-MM-ddThh:mm:ssZ")
			$deploy | Add-Member -MemberType NoteProperty -Name UAT_x0020_Deployer -Value (Get-SPUserViaWS -url $list_url -name ($ENV:USERDOMAIN + "\" + $ENV:USERNAME) )
		} 
		else if( $dst_map.Environment -imatch "PROD" )
		{
			$deploy | Add-Member -MemberType NoteProperty -Name Prod_x0020_Deployment -Value $(Get-Date).ToString("yyyy-MM-ddThh:mm:ssZ")
			$deploy | Add-Member -MemberType NoteProperty -Name Prod_x0020_Deployer -Value(Get-SPUserViaWS -url $list_url -name ($ENV:USERDOMAIN + "\" + $ENV:USERNAME))
		}
		WriteTo-SPListViaWebService -url $list_url -list $deploy_tracker -Item (Convert-ObjectToHash $deploy)
		
		log -txt "** Complete **"
		
	} catch [System.SystemException] {
		 Write-Host $_.Exception.ToString() -ForegroundColor Red
	}
}
main