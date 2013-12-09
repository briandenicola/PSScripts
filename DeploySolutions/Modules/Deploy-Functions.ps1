#Variables
Set-Variable -Name deploy_solutions -Value (Join-Path $ENV:SCRIPTS_HOME "DeploySolutions\Deploy-Sharepoint-Solutions.ps1") -Option Constant
Set-Variable -Name deploy_configs -Value (Join-Path $ENV:SCRIPTS_HOME "DeployConfig\DeployConfigs.ps1") -Option Constant
Set-Variable -Name enable_features -Value (Join-Path $ENV:SCRIPTS_HOME "DeploySolutions\Enable-$app-Features.ps1") -Option Constant
Set-Variable -Name sptimer_script_block -Value { Restart-Service -Name sptimerv4 -Verbose }
Set-Variable -Name iisreset_scipt_block -Value { iisreset }
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

$menu = @(
	@{ "Text" = "Deploy SharePoint Solutions"; "ScriptBlock" = "Deploy-Solutions" },
    @{ "Text" = "Enable $app Features"; "ScriptBlock" = "Enable-Features" },
    @{ "Text" = "Deploy $app Web Config Files"; "ScriptBlock" = "Deploy-Config" },
    @{ "Text" = "Install MSI Files"; "ScriptBlock" = "Install-MSIFile" },
    @{ "Text" = "Uninstall MSI Files"; "ScriptBlock" = "Uninstall-MSIFile" },
    @{ "Text" = "Install Files to GAC"; "ScriptBlock" = "DeployTo-GAC" },
    @{ "Text" = "Sync Web Code"; "ScriptBlock" = "Sync-Files" },
    @{ "Text" = "Cycle IIS On All SharePoint Servers"; "ScriptBlock" = "Cycle-IIS" },
    @{ "Text" = "Cycle Timer Service on All SharePoint Servers"; "ScriptBlock" = "Cycle-Timer" },
    @{ "Text" = "Record and Quit"; "ScriptBlock" = "break" }
)
#End Variables 

#Deploy Functions
function Deploy-Solutions
{
    Log-Step -step "$deploy_solutions -web_application $url -deploy_directory $src -noupgrade"
    Log-Step -step "$deploy_configs -operation backup -url $url"

    Get-SPWebApplication $url -EA Silentlycontinue | Out-Null
    if( !$? ) {
        throw ("Could not find " + $url + " this SharePoint farm. Are you sure you're on the right one?")
        exit
    }

    cd ( Join-Path $ENV:SCRIPTS_HOME "DeploySolutions" )
	&$deploy_solutions -web_application $url -deploy_directory $src -noupgrade
	cd (Join-Path $ENV:SCRIPTS_HOME "DeployConfig" )
	&$deploy_configs -operation backup -url $url				
    cd ( Join-Path $ENV:SCRIPTS_HOME "DeploySolutions" )
}

function Deploy-Config
{
    Log-Step -step "$deploy_configs -operation deploy -url $url" 
    Log-Step -step "$deploy_configs -operation validate -url $url" 
    
	cd (Join-Path $ENV:SCRIPTS_HOME "DeployConfig" )
	&$deploy_configs -operation deploy -url $url
	&$deploy_configs -operation validate -url $url 
    cd ( Join-Path $ENV:SCRIPTS_HOME "DeploySolutions" )
}

function Enable-Features 
{
    if( !( Test-Path $enable_features ) ) { 
        Write-Error "Could not find $enable_features script"
        return
    }

	Log-Step -step "$enable_features -webApp $url"

	cd (Join-Path $ENV:SCRIPTS_HOME  "DeploySolutions" )
	&$enable_features -webApp $url			
    cd ( Join-Path $ENV:SCRIPTS_HOME "DeploySolutions" )
}

function Install-MSIFile
{
	Log-Step -step "Get-ChildItem $src -filter *.msi | % { Start-Process -FilePath msiexec.exe -ArgumentList /i, $_.FullName -Wait }"
	
	foreach( $msi in (Get-ChildItem $src -Filter *.msi) ) {
		Write-Host "[ $(Get-Date) ] - Installing MSI - $($msi.FullName)  . . ."
		Start-Process -FilePath msiexec.exe -ArgumentList /i, $msi.FullName -Wait  
	} 
}

function Uninstall-MSIFile
{ 
	Log-Step -step "Get-Content (Join-Path $src uninstall.txt) | % { Start-Process -FilePath msiexec.exe -ArgumentList /x,$_,/qn -Wait }" 

    $uninstall_file = (Join-Path $src "uninstall.txt") 
    if( !( Test-Path $uninstall_file )) {
        throw "Could not file the file that contains the MSIs to uninstall at $uninstall_file"
        return
    } 
	
    Get-Content $uninstall_file | Foreach { 
		Write-Host "[ $(Get-Date) ] - Removing MSI with ID - $_  . . ."
		Start-Process -FilePath msiexec.exe -ArgumentList /x,$_,/qn -Wait  
	} 
}

function Sync-Files
{
    $dst = Read-Host "Enter the Destination Directory to Sync Files to"
    $servers = (Read-Host "Enter servers to copy files to(separated by a comma) ").Split(",")

	Log-Step -step "Executed on $servers - (Join-Path $ENV:SCRIPTS_HOME Sync\Sync-Files.ps1) -src $src -dst $dst  -verbose -logging"

    Invoke-Command -Computer $servers -Authentication CredSSP -Credential (Get-Creds) -ScriptBlock $sync_file_script_block -ArgumentList $src, $dst, $log_home
}

function DeployTo-GAC
{
    $servers =  Get-SPServers -type "Microsoft SharePoint Foundation Web Application"
	Log-Step -step "Executed on $servers -(Join-Path $ENV:SCRIPTS_HOME Misc-SPScripts\Install-Assemblies-To-GAC.ps1) -src $src" 
	 
	Invoke-Command -Computer $servers -Authentication CredSSP -Credential (Get-Creds)-ScriptBlock $gac_script_block -ArgumentList $src
}

function Cycle-IIS 
{
    $servers = Get-SPServers
    Log-Step -step "Invoke-Command -Computer $servers -ScriptBlock $iisreset_script_block" 
    Invoke-Command -Computer $servers -ScriptBlock $iisreset_scipt_block
}

function Cycle-Timer
{
    $servers = Get-SPServers
    Log-Step -step "Invoke-Command -Computer $servers -ScriptBlock $sptimer_script_block"
    Invoke-Command -Computer $servers -ScriptBlock $sptimer_script_block
}