param (	
	[Parameter(Mandatory=$true)]
	[string] $tfs_build_dir
	
	[Parameter(Mandatory=$true)]
	[string] $dst_controller,
	
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

$creds = $null

Set-Variable -Name now -Value $(Get-Date).ToString("yyyyMMddhhmmss") -Option Constant
Set-Variable -Name backup_directory -Value "\\ent-nas-fs01.us.gt.com\app-ops\Code\Custom-DotNet-Applications" -Option Constant
Set-Variable -Name list_url -Value "http:/teamadmin.gt.com/sites/ApplicationOperations/applicationsupport/" -Option Constant
Set-Variable -Name deploy_tracker -Value "Deployment Tracker" -Option Constant

function log( [string] $txt ) 
{
	$txt = "[" + (Get-Date).ToString() + "] - " + $txt + " . . . "	
	Write-Host $txt
	$txt | Out-File -Append -Encoding Ascii $log
}

function Create-PSSession 
{

	$creds = Get-Credential ($ENV:USERDOMAIN + "\" + $ENV:USERNAME)
	$session = New-PSSession -Computer $dst_computer -Authentication CredSSP -Credentials $creds

	return $session
}

function Create-PublishingSettings 
{	
	$file = Join-Path $ENV:TEMP "$($dst_site).publishsettings"

	New-WDPublishSettings -ComputerName $dst_controller
		-Site $dst_site
		-Credentials $creds
		-FileName $file 
		-AgentType wmsvc
	
	return $file
}

function Backup-Site 
{
	param ( [object] $session ) 
	
	Invoke-command -Computer $dst_controller -Session $session -ScriptBlock { 
		param ( 
			[string] $dir,
			[string] $site
		)
		
		Add-PSSnapin WDeploySnapin3.0 -EA Stop
		Backup-WDSite -Site $site -Ouput $dir -IncludeAppPool
	} -ArgumentList $dst_site, $backup_directory
}

function Get-MostRecentFile( [string] $src )
{
	return ( dir $src | sort LastWriteTime -desc | select -first 1 | Select -ExpandProperty Name )
}

function Deploy-Site 
{
    param ( 
        [string] $settings
    )

    if( -not (Test-Path $tfs_build_dir) ) {
        throw "Could not find $tfs_build_dir"
    }

	$src = Get-MostRecentFile -src $tfs_build_dir
	
    if(!$include_webconfig) {
        $skipfiles = "web.config"
    }

    $source_manifest = @"
        <sitemanifest>
            <contentPath path=`"$src`" />
        </sitemanifest>
"@  
    $dest_manifest_file = @"
        <sitemanifest>
             <iisApp path=`"$dst_site`" />
        </sitemanifest>
"@
    
    $source_manifest_file = Join-Path $ENV:TEMP "source.xml"
    $dest_manifest_file = Join-Path $ENV:TEMP "destination.xml"

    $source_manifest | Out-File -Encoding ascii $source_manifest_file
    $dest_manifest_file | Out-File -Encoding ascii $dest_manifest_file

    Sync-WDManifest $source_manifest_file $dest_manifest_file -DestinationPublishSettings $settings -SkipFileList $skipfiles

    Remove-Item $source_manifest_file
    Remove-Item $dest_manifest_file
}

function Sync-Farm 
{
	param ( [object] $session ) 
	
	Invoke-command -Computer $dst_controller -Session $session -ScriptBlock { 
		param ( 
			[string] $farm
		)
        . (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1") 
		Sync-WebFarm $farm
	} -ArgumentList $farm
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
	
    $env = Get-ServerEnvironment -server $dst_controller

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
		$sess = Create-PSSession
		Backup-Site -Session $sess
		Deploy-Site -Session $sess -Settings (Create-PublishingSettings)
		Sync-Farm -Session $sess
		Record-Deployment
		Remove-PSSession $sess
	} catch [System.SystemException] {
		 Write-Host $_.Exception.ToString() -ForegroundColor Red
	}
}
main