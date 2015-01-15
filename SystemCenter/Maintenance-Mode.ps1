[CmdletBinding(SupportsShouldProcess=$true)]
param ( 
    [Parameter(Mandatory=$true)]
	[ValidateSet("enable", "disable")]
    [string] $mode,

    [ValidateRange(0,48)]
    [int] $hours = 1,
    [string] $reason = "Application code deployment",

    [Parameter(ParameterSetName='url')]
    [string] $url,

    [Parameter(ParameterSetName='computer')]
    [string[]] $computers
)

Add-PSSnapin "Microsoft.EnterpriseManagement.OperationsManager.Client" -ErrorAction Stop
Import-Module (Join-Path $ENV:SCRIPTS_HOME "Libraries\Pingdom.psm1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")\

$scom_server = ""
$url_config_path = ""

$url_map = @(
    New-Object PSObject -Property @{ 'ID'=11111; 'URL'=''; 'Farm'=''; 'Environment'='Production'; 'Configs'=@() }  
    New-Object PSObject -Property @{ 'ID'=0; 'URL'=''; 'Farm'=''; 'Environment'='UAT'; 'Configs'=@() }
)

function Update-Url-Monitoring
{
    param (
       [string[]] $configs
    )

    Write-Host "[ $(Get-Date) ] - Updating URL Monitoring Configuration at $url_config_path . . ."
    foreach( $config in $configs ) {
        if( $mode -eq "enable" ) {
            Move-Item (Join-Path $url_config_path $config) (Join-Path $url_config_path ($config + ".maintainance")) -Force -Verbose
        }
        else {
            Move-Item (Join-Path $url_config_path ($config + ".maintainance")) (Join-Path $url_config_path $config) -Force -Verbose
        }
    }
}

function Update-Systemcenter-MaintenanceMode
{
    param(
        [string[]] $computers
    )
   
    $current_location = Get-Location
    Set-Location "OperationsManagerMonitoring::"

    New-ManagementGroupConnection -ConnectionString $scom_server | Out-Null
    $agents = Get-Agent

    foreach( $computer in $computers ) {
        try { 
            Write-Host "[ $(Get-Date) ] - Updating $computer maintenance mode setting on $scom_server . . ." 
            $agent =  $agents | Where { $_.ComputerName  -eq $computer }

            if( $mode -eq "enable" ) {
                $start_time = $(Get-Date).ToUniversalTime()
                $end_time = $start_time.AddHours($hours)

                Write-Host "[ $(Get-Date) ] - End Time will be $end_time UTC for $computer . . ."
                New-MaintenanceWindow -StartTime $start_time -EndTime $end_time -MonitoringObject $agent.HostComputer -Reason PlannedOther -Comment $reason
            }
            else {
                Set-MaintenanceWindow -EndTime $(Get-Date).AddMinutes(1) -MonitoringObject $agent.HostComputer
            }

        }
        catch {
            Write-Error ("Failed to set maintenance mode for $computer with Exception - {0} . . ." -f $_.Exception.ToString() )
        }
    }

    Set-Location $current_location

}

function main
{
    if($PsCmdlet.ParameterSetName -eq 'url' ) {
        $map = $url_map | where Url -eq $url 
        
        if( $map -eq $null ) {
            throw "Could not find $url in the mapping config. Maybe pass -computers instead . . ." 
        }

        if( $mode -eq "enable" -and $map.Id -ne 0 ) {
            Disable-PingdomAppMonitoring -id $map.id #Yes I meant to call Disable able here even though the nameing seems flipped.
        }
        else {
            Enable-PingdomAppMonitoring -id $map.id
        }
        Update-Url-Monitoring -configs $map.Configs
    
        Write-Host "[ $(Get-Date) ] - Getting Servers from SharePoint . . ."
        $computers = Get-SharePointServersWS | Where { $_.Farm -eq $map.Farm -and $_.Environment -eq $map.Environment } | Select -ExpandProperty SystemName
    }

    Update-Systemcenter-MaintenanceMode -computers $computers

}
main