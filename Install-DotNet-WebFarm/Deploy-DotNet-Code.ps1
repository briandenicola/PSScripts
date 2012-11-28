param (	
	[Parameter(Mandatory=$true)]
	[string] $tfs_build_dir,	
	[Parameter(Mandatory=$true)]
	[string] $dst_site,
	[Parameter(Mandatory=$true)]
	[string] $farm,
	
    [switch] $include_webconfig,
	[string] $log = ".\logs\dotnet_webfarm_code_deploy.log"
)

Add-PSSnapin WDeploySnapin3.0 -EA Stop

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")

Set-Variable -Name now -Value $(Get-Date).ToString("yyyyMMddhhmmss") -Option Constant
Set-Variable -Name backup_directory -Value "\\ad\app-ops\Backups\DotNetBackup" -Option Constant
Set-Variable -Name list_url -Value "http:/teamadmin.gt.com/sites/ApplicationOperations/applicationsupport/" -Option Constant
Set-Variable -Name deploy_tracker -Value "Deployment Tracker" -Option Constant

function log( [string] $txt ) 
{
	$txt = "[" + (Get-Date).ToString() + "] - " + $txt + " . . . "	
	Write-Host $txt
	$txt | Out-File -Append -Encoding Ascii $log
}

function Backup-Site 
{
	log -txt "Backup up $dst_site to $backup_directory"
	Backup-WDSite -Site $dst_site -Output $backup_directory
}

function Get-MostRecentFile( [string] $src )
{
	return ( dir $src | sort LastWriteTime -desc | select -first 1 | Select -ExpandProperty Name )
}

function Deploy-Site 
{
    if( -not (Test-Path $tfs_build_dir) ) {
        throw "Could not find $tfs_build_dir"
    }

	$src = Get-MostRecentFile -src $tfs_build_dir
	$dst = Get-WebFilePath ('IIS:\Sites\' + $dst_site) | Select -Expand FullName

    if(!$include_webconfig) {
        $skipfiles = "web.config"
    }

    $source_manifest = @"
        <sitemanifest>
            <contentPath path=`"$src`" />
        </sitemanifest>
"@  
    $dest_manifest = @"
        <sitemanifest>
            <contentPath path=`"$dst`" />
        </sitemanifest>
"@
    
    $source_manifest_file = Join-Path $ENV:TEMP "source.xml"
    $dest_manifest_file = Join-Path $ENV:TEMP "destination.xml"

    $source_manifest | Out-File -Encoding ascii $source_manifest_file
    $dest_manifest | Out-File -Encoding ascii $dest_manifest_file

    Sync-WDManifest $source_manifest_file $dest_manifest_file -SkipFileList $skipfiles

    Remove-Item $source_manifest_file
    Remove-Item $dest_manifest_file
}

function Sync-Farm 
{
    log -txt "Syncing Farm - $farm"
	Sync-WebFarm $farm

}

function Get-ServerEnvironment
{
    param ( [string] $server )

    if( $server -imatch "cdc" ) { 
        return "PROD" 
    }
    return "UAT"
}

function Record-Deployment 
{
	$deploy = New-Object PSObject -Property @{
		Title = "Automated .NET Deployment for - " + $dst_site
		DeploymentType = "Full"
		Deployment_x0020_Steps = "Automated with " + $MyInvocation.ScriptName + ". Log file located on " + $ENV:COMPUTERNAME + " - " + (dir $log).FullName
		Notes = "Code location is at " + $backup_location
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

function Get-SPUserViaWS( [string] $url, [string] $name )
{
	$service = New-WebServiceProxy ($url + "_vti_bin/UserGroup.asmx?WSDL") -Namespace User -UseDefaultCredential
	$user = $service.GetUserInfo($name)
	
	if( $user ) {
		return ( $user.user.id + ";#" + $user.user.Name )
	} 
	return $null	
}

function main()
{
	try {   
		Backup-Site
		Deploy-Site
		Sync-Farm
		Record-Deployment
	} catch [System.SystemException] {
		 Write-Host $_.Exception.ToString() -ForegroundColor Red
	}
}
main