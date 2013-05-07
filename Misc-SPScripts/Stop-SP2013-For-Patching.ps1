<# ============================================================== 
// 
// Microsoft provides programming examples for illustration only, 
// without warranty either expressed or implied, including, but not 
// limited to, the implied warranties of merchantability and/or 
// fitness for a particular purpose. 
// 
// This sample assumes that you are familiar with the programming 
// language being demonstrated and the tools used to create and debug 
// procedures. Microsoft support professionals can help explain the 
// functionality of a particular procedure, but they will not modify 
// these examples to provide added functionality or construct 
// procedures to meet your specific needs. If you have limited 
// programming experience, you may want to contact a Microsoft 
// Certified Partner or the Microsoft fee-based consulting line at 
//  (800) 936-5200 . 
// 
// For more information about Microsoft Certified Partners, please 
// visit the following Microsoft Web site: 
// https://partner.microsoft.com/global/30000104 
// 
// Author: Russ Maxwell (russmax@microsoft.com) 
// 
// ---------------------------------------------------------- #>
param(
    [Parameter(Mandatory=$true)]
    [string] $patch
)

if( !(Test-Path $patch) ) {
    throw "Could not find $patch. Must exit . . ."
}

$services = @(
    "OSearch15", 
    "SPSearchHostController",
    "IISADMIN",
    "SPTimerV4"
)

function Patch-Server 
{
    $filename = (Get-ChildItem $patch).BaseName

    Write-Host "[ $(Get-Date) ] - Patching . . ." -ForegroundColor Magenta 
    $start = Get-Date

    &$patch /passive

    Start-Sleep -seconds 20 
    (Get-Process $filename).WaitForExit()

    $finish = Get-Date 
    $diff = ($finish - $start).TotalSeconds 

    Write-Host "[ $(Get-Date) ] - Patch installation complete after $diff seconds . . ." -foregroundcolor green 
}

function Stop-Services 
{

    Write-Host "[ $(Get-Date) ] - Pausing Search Application . . ." -foregroundcolor yellow 
    $ssa = Get-SPEnterpriseSearchsSrviceApplication  
    $ssa.pause() 

    if( (Get-Service "appfabriccachingservice").status -eq "Running" ) { 
        Write-Host "[ $(Get-Date) ] - Gracefully stopping Distributed Cache, this could take a few minutes  . . ." -foregroundcolor Yellow
        Stop-SPDistributedCacheServiceInstance -Graceful 
        Write-Host "[ $(Get-Date) ] - Distributed Cache disabled  . . ." 
    }

    foreach( $service in $services ) {
        Write-Host "[ $(Get-Date) ] - Stopping $service Service . . ." -foregroundcolor yellow 
        Get-Service -Name $service | Stop-Service -Force -ErrorAction SilentlyContinue
        Set-Service -Name $service -startuptype Disabled 
    }

    Write-Host "[ $(Get-Date) ] - Stopping IIS . . ." -foregroundcolor yellow 
    iisreset -stop -noforce 
}

function Start-Services
{
    foreach( $service in $services ) {
        Write-Host "[ $(Get-Date) ] - Stopping $service Service . . ." -foregroundcolor yellow 
        Get-Service -Name $service | Start-Service -Force -ErrorAction SilentlyContinue
        Set-Service -Name $service -startuptype Automatic 
    }
    Write-Host "[ $(Get-Date) ] - Starting IIS . . ." -foregroundcolor yellow 
    iisreset -start

    $server = Get-SPServer $env:COMPUTERNAME
    $dcache = Get-SPServiceInstance | where { ($_.TypeName -eq "Distributed Cache") -and ($_.Server -eq $server) }
    if($dcache.status -eq "Disabled") { 
        Write-Host "[ $(Get-Date) ] - Starting Distributed Cache Service . . ." -foregroundcolor "Yellow" 
        $dcache.start() 
    }

    Write-Host "[ $(Get-Date) ] - Resuming the Search Service Application . . ." -foregroundcolor yellow 
    $ssa = Get-SPEnterpriseSearchsSrviceApplication 
    $ssa.resume() 
}

function main
{
    Write-Host "[ $(Get-Date) ] - Stopping Services . . . " -foregroundcolor yellow
    Stop-Services

    Write-Host "[ $(Get-Date) ] - Going to patch . . . " -foregroundcolor yellow
    Patch-Server

    Write-Host "[ $(Get-Date) ] - Starting Services . . . " -foregroundcolor yellow
    Start-Services

    Write-Host "[ $(Get-Date) ] - Script Complete . . ."
}
main