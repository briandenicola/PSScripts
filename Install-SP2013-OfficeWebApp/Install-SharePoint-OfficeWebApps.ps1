[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [string] $config = ".\Configs\owa_setup.xml",
	[switch] $record
)

ImportSystemModules

#Set Variables
$cfg = [xml] ( gc $config )

$url = $cfg.Settings.Common.url 
$source = $cfg.Settings.Common.Source
$scripts_home = $cfg.Settings.Common.scripts
$utils_home = $cfg.Settings.Common.utils
$webpi = $cfg.Settings.Common.webpi
$logs_home = $cfg.Settings.Common.logs


function Copy-Files
{
	xcopy /e/v/f/s (Join-Path $source "Scripts") $scripts_home
	xcopy /e/v/f/s (Join-Path $source "Utils") $utils_home
}

function Setup-Base
{
	cscript.exe //H:cscript
	setx -m SCRIPTS_HOME $scripts_home
	$ENV:SCRIPTS_HOME = $scripts_home

	Disable-InternetExplorerESC
	Disable-UserAccessControl

	Enable-PSRemoting -force
	Enable-WSmanCredSSP -role server -force
	Enable-WSManCredSSP -role client -delegate * -Force

	New-Item -Path "HKLM:SOFTWARE\Policies\Microsoft\Windows NT\" -Name "Reliability" 
	New-ItemProperty -Path "HKLM:SOFTWARE\Policies\Microsoft\Windows NT\Reliability" -Name "ShutdownReasonOn" -Value "0" -PropertyType dword
}

function Setup-IIS
{
	cd  (Join-Path $ENV:SCRIPTS_HOME "iis\install")
	
	$ver = Get-WMIObject win32_operatingSystem | Select -Expand name
	if( $ver -imatch "2008 R2" ) { 
		.\install_and_config_iis7.ps1 
	} elseif( $ver -imatch "2012" ) { 
		.\install_and_config_iis8.ps1
	} else { 
		throw "Invalid Operating System Detected . . ."
	}
}

function Setup-DotNet
{
	#Install .Net Apps
	Write-Host "[ $(Get-Date) ] - Installing Required Features . . ."
    $features = @(
        "Web-Server",
        "Web-Mgmt-Tools",
        "Web-Mgmt-Console",
        "Web-WebServer",
        "Web-Common-Http",
        "Web-Default-Doc",
        "Web-Static-Content",
        "Web-Performance",
        "Web-Stat-Compression",
        "Web-Dyn-Compression",
        "Web-Security",
        "Web-Filtering",
        "Web-Windows-Auth",
        "Web-App-Dev",
        "Web-Net-Ext45",
        "Web-Asp-Net45",
        "Web-ISAPI-Ext",
        "Web-ISAPI-Filter",
        "Web-Includes",
        "InkandHandwritingServices"
    )
	Add-WindowsFeature $features -Verbose

}

function Update-Audit 
{
    $audit = audit-Servers -Servers $ENV:COMPUTERNAME
    WriteTo-SPListViaWebService -url $url -list Servers -Item $(Convert-ObjectToHash $audit) -TitleField SystemName  
}

function Install-OWA
{
    $pwd = $PWD.Path
    Mount-DiskImage $cfg.Settings.Common.Setup
    $drive = Get-Volume | Where FileSystemLabel -imatch "15.0.4420" | Select -ExpandProperty DriveLetter
    Set-Location "$drive`:\"
    .\setup.exe 
    Set-Location $pwd
    DisMount-DiskImage $cfg.Settings.Common.Setup
}

function Config-OWA
{
	New-OfficeWebAppsFarm –InternalURL $cfg.Settings.owa_url –AllowHttp -EditingEnabled
	Set-OffcieWebAppsFarm -ExternalURL $cfg.Settings.owa_url
	iisreset
}

function main
{	
	Set-ExecutionPolicy unrestricted -force
	if( !(Test-Path $logs_home) ) { 
		mkdir $logs_home
		mkdir (Join-Path $logs_home "Trace")
        New-SmbShare -Name Logs -Path $logs_home -ReadAccess everyone
	}
	
	$log = ".\Logs\System-Setup-" + $ENV:COMPUTERNAME + "-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".log"
	&{Trap{continue};Start-Transcript -Append -Path $log}
        
	Copy-Files
	Setup-Base
	Setup-IIS
    Setup-DotNet
    Install-OWA
    Read-Host "Press any key to continue after the binaries are installed."
    Config-OWA	

    if( $record ) { Update-Audit } 
	Stop-Transcript
}
main