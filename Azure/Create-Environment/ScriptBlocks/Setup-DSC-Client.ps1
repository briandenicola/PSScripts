param (
    [string] $pull_server,
    [string] $guid
)

configuration ConfigureDSCPullServer {    param (
        [string] $NodeId, 
        [string] $PullServer
    )  
    
    Node "localhost"
    {
        LocalConfigurationManager        {            AllowModuleOverwrite = 'True'            ConfigurationID = $NodeId            ConfigurationModeFrequencyMins = 30             ConfigurationMode = 'ApplyAndAutoCorrect'            RebootNodeIfNeeded = 'True'            RefreshMode = 'PULL'             DownloadManagerName = 'WebDownloadManager'            DownloadManagerCustomData = @{                ServerUrl = "http://$PullServer/psdscpullserver.svc"                AllowUnsecureConnection = ‘true’            }          }    }}

Get-Disk | Where { $_.PartitionStyle -eq "RAW" } | Initialize-Disk -PartitionStyle MBR 
Get-Disk | Where { $_.NumberOfPartitions -eq 0 } |   
    New-Partition -AssignDriveLetter -UseMaximumSize |
    Format-Volume -FileSystem NTFS -Force -Confirm:$false

$dsc_path = Join-Path -Path $ENV:SystemDrive -ChildPath "DSCResources"
New-Item -Path $dsc_path -ItemType Directory 
Set-Location -Path $dsc_path

ConfigureDSCPullServer -NodeId $guid -PullServer $pull_serverSet-DscLocalConfigurationManager -Path ConfigureDSCPullServer -ComputerName localhost 
Add-Content -Encoding Ascii -Path ( Join-Path -Path $ENV:SystemDrive  -ChildPath $guid ) -Value $guid