#Requires -version 2.0
#Requires –PSSnapin WDeploySnapin3.0

param (	
	[Parameter(Mandatory=$true)][string] $tfs_build_dir,	
	
    [Parameter(ParameterSetName="WebSite",Mandatory=$true)][string] $dst_site,
	[Parameter(ParameterSetName="WebSite",Mandatory=$true)][string[]] $farm_servers,
	[Parameter(ParameterSetName="WebSite")][switch] $include_webconfig,

    [Parameter(ParameterSetName="Service",Mandatory=$true)][string] $service_name,
    [Parameter(ParameterSetName="Service",Mandatory=$true)][string] $install_location,
    
	[string] $log = ".\logs\dotnet_webfarm_code_deploy.log"
)

Add-PSSnapin WDeploySnapin3.0 -EA SilentlyContinue

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")

Set-Variable -Name now -Value $(Get-Date).ToString("yyyyMMddhhmmss") -Option Constant
Set-Variable -Name backup_directory -Value "\\ad\app-ops\Backups\DotNetBackup" -Option Constant
Set-Variable -Name list_url -Value "http://example.com/" -Option Constant
Set-Variable -Name deploy_tracker -Value "Deployment Tracker" -Option Constant
Set-Variable -Name Sync-Files -Value (Join-Path $ENV:SCRIPTS_HOME "Comparisons\Sync-Files.ps1") -Option Constant

function log( [string] $txt ) 
{
	$txt = "[" + (Get-Date).ToString() + "] - " + $txt + " . . . "	
	Write-Host $txt
	$txt | Out-File -Append -Encoding Ascii $log
}

function Backup-Site 
{
	log -txt "Backup up $dst_site to $backup_directory"
	Backup-WDSite -Site $dst_site -Output $backup_directory -IncludeAppPool
}

function Get-MostRecentDeployment( [string] $src )
{
	return ( Get-ChildItem $src | Sort LastWriteTime -desc | Select -first 1 | Select -ExpandProperty FullName )
}

function Deploy-Site 
{
    if( -not (Test-Path $tfs_build_dir) ) {
        throw "Could not find $tfs_build_dir"
    }

	$src = Get-MostRecentDeployment -src $tfs_build_dir
	$dst = Get-WebFilePath ('IIS:\Sites\{0}' -f $dst_site) | Select -Expand FullName

    if(!$include_webconfig) {
        $skipfiles = "web.config"
    }
    	
    log -txt "Deploying Web Code for IIS Site - $dst_site to - $dst from $src"
    &${Sync-Files} -src $src -dst $dst -logging -log $log -ignore_files $skipfiles

}

function Sync-Farm 
{
    log -txt "Syncing Servers"

    $src_publishing_file = Join-Path $ENV:TEMP ("{0}.publishsettings" -f $ENV:COMPUTERNAME)
    New-WDPublishSettings -ComputerName $ENV:COMPUTERNAME -AgentType MSDepSvc -FileName $src_publishing_file

	foreach( $computer in ($farm_servers | where { $_ -inotmatch $ENV:COMPUTERNAME} )) {
        log -txt "Syncing $computer"
        $dst_publishing_file = Join-Path $ENV:TEMP ("{0}.publishsettings" -f $computer)
        New-WDPublishSettings -ComputerName $computer -AgentType MSDepSvc -FileName $dst_publishing_file
        Sync-WDServer -SourcePublishSettings $src_publishing_file -DestinationPublishSettings $dst_publishing_file
        Remove-Item $dst_publishing_file -Force
    }

    Remove-Item $src_publishing_file
}

function Get-ServerEnvironment
{
    param ( [string] $server )

    if( $server -imatch "^cdc" ) { 
        return "PROD" 
    }
    return "UAT"
}

function Record-Deployment 
{
    param(
        [string] $type
    )
    
    $deploy = New-Object PSObject -Property @{
		    Title = [string]::Empty
		    DeploymentType = "Full"
		    Deployment_x0020_Steps = ("Automated with Deploy-DotNet-Code.v2.ps1. Log file located on {0} - {1}" -f $ENV:COMPUTERNAME, (Get-ChildItem $log).FullName)
		    Notes = ("Code Backup location is at {0}" -f $backup_location)
    }

    if( $type -eq "web" ) {
        $deploy.Title = ("Automated .NET Web Site Deployment for - {0}" -f $dst_site)
    }
    else {
    	$deploy.Title = ("Automated .NET Windows Service Deployment for - {0}" -f $service_name)
    }
	
    $env = Get-ServerEnvironment -server $ENV:COMPUTERNAME

	if( $env -imatch "UAT" )
	{
		$deploy | Add-Member -MemberType NoteProperty -Name UAT_x0020_Deployment -Value $(Get-Date).ToString("yyyy-MM-ddThh:mm:ssZ")
		$deploy | Add-Member -MemberType NoteProperty -Name UAT_x0020_Deployer -Value (Get-SPUserViaWS -url $list_url -name ($ENV:USERDOMAIN + "\" + $ENV:USERNAME) )
	} 
	elseif( $env -imatch "PROD" )
	{
		$deploy | Add-Member -MemberType NoteProperty -Name Prod_x0020_Deployment -Value $(Get-Date).ToString("yyyy-MM-ddThh:mm:ssZ")
		$deploy | Add-Member -MemberType NoteProperty -Name Prod_x0020_Deployer -Value(Get-SPUserViaWS -url $list_url -name ($ENV:USERDOMAIN + "\" + $ENV:USERNAME))
	}

    log -txt "Recording deployment to $deploy_tracker @ $list_url - $deploy"
	WriteTo-SPListViaWebService -url $list_url -list $deploy_tracker -Item (Convert-ObjectToHash $deploy)		
}

function Get-SPUserViaWS
{
    param(
        [string] $url,
        [string] $name
    )

	$service = New-WebServiceProxy ($url + "_vti_bin/UserGroup.asmx?WSDL") -Namespace User -UseDefaultCredential
	$user = $service.GetUserInfo($name)
	
	if( $user ) {
		return ( $user.user.id + ";#" + $user.user.Name )
	} 
	return $null	
}

function Backup-Service 
{
    $backup_location = (Join-Path $backup_directory ("{0}\{1}" -f $service_name, $now))
    New-Item -ItemType Directory -Path $backup_location  | Out-Null
 
    log -txt "Backing Up Service $service_name to - $backup_location"
    &${Sync-Files} -src $install_location -dst $backup_location -logging
}

function Deploy-Service 
{
    if( -not (Test-Path $tfs_build_dir) ) {
        throw "Could not find $tfs_build_dir"
    }

	$src = Get-MostRecentDeployment -src $tfs_build_dir

    log -txt "Deploying Service $service_name to - $install_location"
    &${Sync-Files} -src $src -dst $install_location -logging
}


function main()
{
    switch ($PsCmdlet.ParameterSetName)
    { 
        "WebSite" { 

	        try {   
		        Backup-Site
		        Deploy-Site
		        Sync-Farm
		        Record-Deployment -type web
	        } catch [System.SystemException] {
		         Write-Error ("Web Deploy failed with the following exception - {0}" -f $_.Exception.ToString() )
	        }

        }
        "Service" {
            try {   
                Stop-Service -Name $service_name 
		        Backup-Service
		        Deploy-Service
                Start-Service -Name $service_name
		        Record-Deployment -type service 
	        } catch [System.SystemException] {
		         Write-Error ("Service Deployment failed with the following exception - {0}" -f $_.Exception.ToString() )
	        }
        }
    }
}
main