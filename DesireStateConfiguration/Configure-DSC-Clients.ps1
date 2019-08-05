param(
    [string] $pull_server
)

configuration Configure_DCSClient
{
    param ($NodeId, $PullServer)   
    LocalConfigurationManager
    {
        AllowModuleOverwrite = 'True'
        ConfigurationID = $NodeId
        ConfigurationModeFrequencyMins = 30
        ConfigurationMode = 'ApplyAndAutoCorrect'
        RebootNodeIfNeeded = 'True'
        RefreshMode = 'PULL'
        DownloadManagerName = 'WebDownloadManager'
        DownloadManagerCustomData = (@{ServerUrl = "https://$PullServer/psdscpullserver.svc"})
    }
}

$node = [guid]::NewGuid().Guid
Configure_DCSClient -NodeId $node.ToString() -PullServer $pull_server
Set-DscLocalConfigurationManager -path Configure_DCSClient

Write-Host "Copy This Guid Down = $($node.ToString())  . . ."
Get-DscLocalConfigurationManager