param(
	[ValidateSet("HostingServices","CachingService","CacheClient","CacheAdmin","Complete")]
	[string] $module = "HostingServices"
)

function log( [string] $txt ) 
{
	"[" + (Get-Date).ToString() + "] - " + $txt 
}

ImportSystemModules
Add-WindowsFeature  AS-Web-Support
Add-WindowsFeature  AS-HTTP-Activation 

$source = "http://download.microsoft.com/download/1/A/D/1ADC8F3E-4446-4D31-9B2B-9B4578934A22/WindowsServerAppFabricSetup_x64_6.1.exe"
$dest = "D:\Temp"
$exe = "WindowsServerAppFabricSetup_x64_6.1.exe"

if( -not ( Test-Path (Join-Path $dest $exe) ) )
{
	log -txt "Downloading $source"
	$wc = New-Object System.Net.WebClient
	$wc.DownloadFile( $source, (Join-Path $dest $exe) )
}

if( $module -eq "complete" ) { $module = "HostingServices,CachingService,CacheClient" }

log -txt "Installing $exe with $module modules"
&(Join-Path $dest $exe) /install $module

while( (Get-Process | where { $_.ProcessName -eq $exe }))
{ 
	Write-Host -NoNewline "."
	Sleep 5
}
log -txt "`n Install Complete"
