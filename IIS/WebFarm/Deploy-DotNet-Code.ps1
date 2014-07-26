#Requires -version 2.0

param (	
    [ValidateSet("tfs_build","directory")]
    [Parameter(Mandatory=$true)][string] $source_type,
    
    [ValidateScript({Test-Path $_ -PathType 'Container'})] 
	[Parameter(Mandatory=$true)][string] $source_directory,	
	
    [Parameter(ParameterSetName="WebSite",Mandatory=$true)][string] $dst_site,
    [Parameter(ParameterSetName="WebSite")][switch] $validate,
	[Parameter(ParameterSetName="WebSite")][switch] $include_webconfig,
    [Parameter(ParameterSetName="WebSite")][switch] $full,
    [Parameter(ParameterSetName="WebSite")][string] $virtual_directory, 
    
    [Parameter(ParameterSetName="Service",Mandatory=$true)][string] $service_name,
    [Parameter(ParameterSetName="Service",Mandatory=$true)][string] $install_location
)

Add-PSSnapin WDeploySnapin3.0 -EA SilentlyContinue

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")

Set-Variable -Name now -Value $(Get-Date).ToString("yyyyMMddhhmmss") -Option Constant
Set-Variable -Name backup_directory -Value "\\ad\app-ops\Backups\DotNetBackup" -Option Constant
Set-Variable -Name list_url -Value "http://example.com/" -Option Constant
Set-Variable -Name deploy_tracker -Value "AppOpsDeployTracker" -Option Constant
Set-Variable -Name Sync-Files -Value (Join-Path $ENV:SCRIPTS_HOME "Sync\Sync-Files.ps1") -Option Constant
Set-Variable -Name Compare-Script -Value (Join-Path $ENV:SCRIPTS_HOME "Comparisons\compare_directories-multiple-systems.ps1") -Option Constant
Set-Variable -Name farm_name -Value "-web-f" -Option Constant
Set-Variable -Name log -Value (Join-Path $PWD.Path ("logs\{0}_deploy-{1}.log" -f ($PsCmdlet.ParameterSetName).ToString(), $now ))

function Log-Entry( [string] $txt ) 
{
    $txt = "[" + (Get-Date).ToString() + "] - " + $txt + " . . . "	 
    Write-Host $txt  
    Out-File -Encoding Ascii -Append -FilePath $log
}

function Get-IISWebFarmServers
{
    if( $env:COMPUTERNAME -inotmatch $farm_name ) {
        throw "This script must be run from a .NET Web Farm. $ENV:COMPUTERNAME does not match expected structure. Can not determine servers in farm . . ."
    }

    Log-Entry -txt "Determing servers to deploy to."
    $root_server = $env:COMPUTERNAME.Substring(0,($env:COMPUTERNAME.LastIndexOf('0')))
    
    $servers = @()
    $server_number = 1

    $server = $env:COMPUTERNAME
    while( nslookup $server ) {
        $servers += $server
        $server = $root_server + ("{0}" -f ($server_number++).ToString().PadLeft(2,'0'))
    } 

    Log-Entry -txt "Will deploy to servers - $servers"
    return ($servers | Select -Unique)
}

function Backup-Site 
{
	Log-Entry -txt "Backup up $dst_site to $backup_directory"
	Backup-WDSite -Site $dst_site -Output $backup_directory
}

function Get-MostRecentDeployment( [string] $src )
{
	return ( Get-ChildItem $src | Sort LastWriteTime -desc | Select -first 1 | Select -ExpandProperty FullName )
}

function Get-IISPath( [string] $site ) 
{
    return ( Get-WebFilePath ( 'IIS:\Sites\{0}' -f $site ) | Select -Expand FullName )
}

function Get-VirtualDirectoryPath( [string] $site, [string] $vdir ) 
{
    return ( Get-WebFilePath ( 'IIS:\Sites\{0}\{1}' -f $site, $vdir ) | Select -Expand FullName )
}

function Deploy-Site 
{
    param(
        [string] $src
    )

    if( [string]::IsNullOrEmpty($virtual_directory) ) {
	    $dst = Get-IISPath -site $dst_site
    }
    else {
        $dst = Get-VirtualDirectoryPath -site $dst_site -vdir $virtual_directory
    }
    
    if($full) {
        Log-Entry -txt "Moving $dst to $dst.$now to force a full sync"
        Move-Item -Path $dst -Destination ($dst + "." + $now) -Force
        New-Item -Path $dst -ItemType Directory | Out-Null
    } elseif(!$include_webconfig) {
        $skipfiles = "web.config"
    }
    	
    Log-Entry -txt "Deploying Web Code for IIS Site - $dst_site to - $dst from $src"
    &${Sync-Files} -src $src -dst $dst -logging -log $log -ignore_files $skipfiles

}

function Sync-Farm 
{
    param (
        [string[]] $farm_servers
    )

    Log-Entry -txt "Syncing the Web Farm"

    $src_publishing_file = Join-Path $ENV:TEMP ("{0}.publishsettings" -f $ENV:COMPUTERNAME)
    New-WDPublishSettings -ComputerName $ENV:COMPUTERNAME -AgentType MSDepSvc -FileName $src_publishing_file -Site $dst_site

    foreach( $computer in ($farm_servers | where { $_ -inotmatch $ENV:COMPUTERNAME -and $_ -ne $null} )) {
        Log-Entry -txt "Syncing $computer"
        $dst_publishing_file = Join-Path $ENV:TEMP ("{0}.publishsettings" -f $computer)
        New-WDPublishSettings -ComputerName $computer -AgentType MSDepSvc -FileName $dst_publishing_file -Site $dst_site
        Sync-WDServer -SourcePublishSettings $src_publishing_file -DestinationPublishSettings $dst_publishing_file
        Remove-Item $dst_publishing_file -Force
    }

    Remove-Item $src_publishing_file
}

function Validate-Deploy
{
    param (
        [string[]] $farm_servers
    )

    &${Compare-Script} -computers $farm_servers -path (Get-IISPath -site $dst_site)
}

function Set-DeploymentEnvironmentInformation
{
    param ( [PSObject] $deployment )

	if( $ENV:COMPUTERNMAE -imatch ($farm_name + "\d\dp")  ) { $environment = "PROD" } else { $environment = "UAT" }

    $environment_proptery = "{0}_x0020_Deployment" -f $environment
    $deployer_proptery  =  "{0}_x0020_Deployer" -f $environment

	$deployment | Add-Member -MemberType NoteProperty -Name $environment_proptery -Value $(Get-Date).ToString("yyyy-MM-ddThh:mm:ssZ")
	$deployment | Add-Member -MemberType NoteProperty -Name $deployer_proptery -Value (Get-SPUserViaWS -url $list_url -name ($ENV:USERDOMAIN + "\" + $ENV:USERNAME))
}

function Record-Deployment 
{
    param(
        [string] $name
    )

    $deploy = New-Object PSObject -Property @{
		Title = ("Automated .NET {0} Deployment for - {1}" -f $PsCmdlet.ParameterSetName, $name)
		DeploymentType = "Full"
		DeploymentSteps = ("Automated with Deploy-DotNet-Code.ps1 with code from {0}. Log file located on {1} - {2}" -f $source_directory, $ENV:COMPUTERNAME, (Get-ChildItem $log).FullName)
		Notes = ("Code Backup location is at {0}" -f $backup_directory)
    }
	
    Set-DeploymentEnvironmentInformation -deployment $deploy
    Log-Entry -txt "Recording deployment to $deploy_tracker @ $list_url - $deploy"
	WriteTo-SPListViaWebService -url $list_url -list $deploy_tracker -Item (Convert-ObjectToHash $deploy)		
}

function Get-SPUserViaWS
{
    param(
        [string] $url,
        [string] $name
    )

	$service = New-WebServiceProxy ($url + "/_vti_bin/UserGroup.asmx?WSDL") -Namespace User -UseDefaultCredential
	$user = $service.GetUserInfo("i:0#.w|$name") 
	
	if( $user ) {
		return ( $user.user.id + ";#" + $user.user.Name )
	} 
	return $null	
}

function Backup-Service 
{
    $backup_location = (Join-Path $backup_directory ("{0}\{1}" -f $service_name, $now))
    New-Item -ItemType Directory -Path $backup_location  | Out-Null
 
    Log-Entry -txt "Backing Up Service $service_name to - $backup_location"
    &${Sync-Files} -src $install_location -dst $backup_location -logging -log $log
}

function Deploy-Service 
{
    param(
        [string] $src
    )

    Log-Entry -txt "Deploying Service $service_name to - $install_location"
    &${Sync-Files} -src $src -dst $install_location -logging -log $log
}

function main()
{
    if( $source_type -eq "tfs_build" ) {
        $src = Get-MostRecentDeployment -src $source_directory
    }
    else {
        $src = $source_directory
    }

    switch ($PsCmdlet.ParameterSetName)
    { 
        "WebSite" {
            Log-Entry -txt ("Starting a Deployment for {0}" -f $dst_site)
	        try {   
                $servers = Get-IISWebFarmServers 
		        Backup-Site
		        Deploy-Site -src $src
		        Sync-Farm -farm_servers $servers
                if($validate) { Validate-Deploy -farm_servers $servers }
		        Record-Deployment -name $dst_site
	        } catch [System.SystemException] {
		         Write-Error ("Web Deploy failed with the following exception - {0}" -f $_.Exception.ToString() )
	        }
        }
        "Service" {
            Log-Entry -txt ("Starting a Deployment for {0}" -f $service_name)
            try {  
                Log-Entry -txt ("Stopping {0}" -f $service_name)
                Stop-Service -Name $service_name 

		        Backup-Service 
		        Deploy-Service -src $src
    
                Log-Entry -txt ("Starting {0}" -f $service_name)
                Start-Service -Name $service_name
		        Record-Deployment -Name $service_name
	        } catch [System.SystemException] {
		         Write-Error ("Service Deployment failed with the following exception - {0}" -f $_.Exception.ToString() )
	        }
        }
    }
}
main