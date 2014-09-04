#Variables
Set-Variable -Name deploy_solutions -Value (Join-Path $ENV:SCRIPTS_HOME "DeploySolutions\Deploy-Sharepoint-Solutions.ps1") -Option Constant
Set-Variable -Name validate_environment -Value (Join-Path $ENV:SCRIPTS_HOME "Validate-URLs\Validate-URLs.ps1") -Option Constant
Set-Variable -Name deploy_configs -Value (Join-Path $ENV:SCRIPTS_HOME "DeployConfig\DeployConfigs.ps1") -Option Constant

Set-Variable -Name sptimer_script_block -Value { Restart-Service -Name sptimerv4 -Verbose }
Set-Variable -Name iisreset_script_block -Value { iisreset }

Set-Variable -Name sync_file_script_block -Value {
    param ( [string] $src, [string] $dst, [string] $log_home  )
    Write-Host "[ $(Get-Date) ] - Copying files on $ENV:COMPUTER from $src to $dst . . ."
    $log_file = Join-Path $log_home ("application-deployment-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".log")
	$sync_script = (Join-Path $ENV:SCRIPTS_HOME "Sync\Sync-Files.ps1")
	&$sync_script -src $src -dst $dst -verbose -logging -log $log_file
}

Set-Variable -Name gac_script_block -Value {
	param( [string] $src ) 
	Write-Host "[ $(Get-Date) ] - Deploying to the GAC on $ENV:COMPUTER from $src . . ."
	$gac_script = (Join-Path $ENV:SCRIPTS_HOME "Misc-SPScripts\Install-Assemblies-To-GAC.ps1")
	&$gac_script -dir $src -verbose
}


#Deploy Functions
function Deploy-Solutions
{
    param( 
        [Xml.XmlElement] $config
    )

    Log-Step -step ("$deploy_solutions -web_application {0} -deploy_directory {1} -noupgrade" -f $config.Url, $config.Source)
    Log-Step -step ("$deploy_configs -operation backup -url {0}" -f $config.Url)

    Get-SPWebApplication $config.url -EA Silentlycontinue | Out-Null
    if( !$? ) {
        throw ("Could not find " + $config.url + " this SharePoint farm. Are you sure you're on the right one?")
        exit
    }

    cd ( Join-Path $ENV:SCRIPTS_HOME "DeploySolutions" )
	&$deploy_solutions -web_application $config.url -deploy_directory $config.Source -noupgrade
	cd (Join-Path $ENV:SCRIPTS_HOME "DeployConfig" )
	&$deploy_configs -operation backup -url $config.url				
    cd ( Join-Path $ENV:SCRIPTS_HOME "DeploySolutions" )
}

function Deploy-Config
{
    param( 
        [Xml.XmlElement] $config
    )

    Log-Step -step ("$deploy_configs -operation deploy -url {0}"  -f $config.Url)
    #Log-Step -step ("$deploy_configs -operation validate -url {0}"  -f $config.Url)
    
	cd (Join-Path $ENV:SCRIPTS_HOME "DeployConfig" )
	&$deploy_configs -operation deploy -url $config.Url
	#&$deploy_configs -operation validate -url $config.Url 
    cd ( Join-Path $ENV:SCRIPTS_HOME "DeploySolutions" )
}

function Enable-Features 
{
    param( 
        [Xml.XmlElement] $config
    )

    Set-Variable -Name enable_features -Value (Join-Path $ENV:SCRIPTS_HOME "DeploySolutions\Enable-$app-Features.ps1") -Option Constant

    if( !( Test-Path $enable_features ) ) { 
        Write-Error "Could not find $enable_features script"
        return
    }

	Log-Step -step ("$enable_features -webApp {0}" -f $config.Url)

	cd (Join-Path $ENV:SCRIPTS_HOME  "DeploySolutions" )
	powershell.exe -NoProfile -Command $enable_features -webApp $config.Url	
    cd ( Join-Path $ENV:SCRIPTS_HOME "DeploySolutions" )
}

function Install-MSIFile
{
    param( 
        [Xml.XmlElement] $config
    )
    	
	foreach( $msi in (Get-ChildItem $config.Source -Filter *.msi) ) {
		Log-Step -step ("Installing MSI - " + $msi.FullName )
		Start-Process -FilePath msiexec.exe -ArgumentList /i, $msi.FullName -Wait  
	} 
}

function Uninstall-MSIFile
{
    param( 
        [Xml.XmlElement] $config
    )

    $uninstall_file = (Join-Path $config.Source "uninstall.txt") 
    if( !( Test-Path $uninstall_file )) {
        throw "Could not file the file that contains the MSIs to uninstall at $uninstall_file"
        return
    } 
	
    foreach( $id in (Get-Content $uninstall_file) ) { 
		Log-Step -step ("Removing MSI with ID - " +  $id  )
		Start-Process -FilePath msiexec.exe -ArgumentList /x,$id,/qn -Wait  
	} 
}

function Sync-Files
{
    param( 
        [Xml.XmlElement] $config
    )

    $servers = $config.DestinationServers.Split(",")
	Log-Step -step ("Executed on {0} - (Join-Path $ENV:SCRIPTS_HOME Sync\Sync-Files.ps1) -src {1} -dst {2}  -verbose -logging" -f $config.DestinationServers, $config.Source, $config.DestinationPath)
    Invoke-Command -Computer $servers -Authentication CredSSP -Credential (Get-Creds) -ScriptBlock $sync_file_script_block -ArgumentList  $config.Source, $config.DestinationPath, $log_home
}

function DeployTo-GAC
{
    param( 
        [Xml.XmlElement] $config
    )

    $servers =  Get-SPServers -type "Microsoft SharePoint Foundation Web Application"
	Log-Step -step ("Executed on $servers - (Join-Path $ENV:SCRIPTS_HOME Misc-SPScripts\Install-Assemblies-To-GAC.ps1) -src {0}" -f $config.Source)
	Invoke-Command -Computer $servers -Authentication CredSSP -Credential (Get-Creds)-ScriptBlock $gac_script_block -ArgumentList $config.Source
}

function Cycle-IIS 
{
    param( 
        [Xml.XmlElement] $config
    )

    $servers = Get-SPServers
    Log-Step -step "Invoke-Command -Computer $servers -ScriptBlock $iisreset_script_block" 
    Invoke-Command -Computer $servers -ScriptBlock $iisreset_script_block
}

function Cycle-Timer
{
    param( 
        [Xml.XmlElement] $config
    )

    $servers = Get-SPServers
    Log-Step -step "Invoke-Command -Computer $servers -ScriptBlock $sptimer_script_block"
    Invoke-Command -Computer $servers -ScriptBlock $sptimer_script_block
}

function Deploy-SSRSReport 
{
    param( 
        [Xml.XmlElement] $config
    )

    . (Join-Path $ENV:SCRIPTS_HOME "SSRS\Install-SSRS.ps1")
    
    $SSRS_WebService = Get-SSRSWebServiceUrl
    foreach( $report in ( Get-ChildItem $config.Source | Where { $_.Extension -eq ".rdl" } ) ) {
        Log-Step -step ("Install-SSRSRDL {0} {1} -reportFolder {2} -force" -f $SSRS_WebService, $report.FullName, $config.ReportFolder )
        Install-SSRSRDL $SSRS_WebService $report.FullName -reportFolder $config.ReportFolder -force
    }

}

function Execute-ManualScriptBlock 
{
    param( 
        [Xml.XmlElement] $config
    )

    if( (Test-Path $config.Source) ) {
        $script_block_text = Get-Content $config.Source | Out-String
        $script_block = [scriptblock]::Create($script_block_text)
        Log-Step -step ("Manual Powershell Scriptblock - {0}" -f $script_block_text) 
        &$script_block
    }
}

#Deploy Functions
function Validate-Environment
{
    param( 
        [Xml.XmlElement] $config
    )

    Log-Step -step ("$validate_environment -cfg {0} -SaveReply" -f $config.Rules)
    
    Set-Location ( Join-Path $ENV:SCRIPTS_HOME "Validate-URLs" )
	&$validate_environment -cfg $config.Rules -SaveReply
    Set-Location ( Join-Path $ENV:SCRIPTS_HOME "DeploySolutions" )
}