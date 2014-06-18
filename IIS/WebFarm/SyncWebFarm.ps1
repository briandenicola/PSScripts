param(
    [Parameter(Mandatory=$true)]
    [string[]] $destination_servers,
    [string] $site
)

Add-PSSnapin WDeploySnapin3.0 -EA SilentlyContinue

$src_publishing_file = Join-Path $ENV:TEMP ("{0}.publishsettings" -f $ENV:COMPUTERNAME)
$options = @{
    ComputerName = $ENV:COMPUTERNAME
    AgentType = "MSDepSvc"
    FileName = $src_publishing_file
}

if( ![string]::IsNullOrEmpty($site) ) {
    $options.Add("Site", $site)
}

New-WDPublishSettings @options 

foreach( $computer in ($destination_servers | where { $_ -inotmatch $ENV:COMPUTERNAME} )) {
    Write-Output "Syncing $computer"

    $dst_publishing_file = Join-Path $ENV:TEMP ("{0}.publishsettings" -f $computer)
    $dst_options = @{
        ComputerName = $computer
        AgentType = "MSDepSvc"
        FileName = $dst_publishing_file
    }

    if( ![string]::IsNullOrEmpty($site) ) {
        $dst_options.Add("Site", $site)
    }

    New-WDPublishSettings @dst_options    
    Sync-WDServer -SourcePublishSettings $src_publishing_file -DestinationPublishSettings $dst_publishing_file
    Remove-Item $dst_publishing_file -Force
}

Remove-Item $src_publishing_file