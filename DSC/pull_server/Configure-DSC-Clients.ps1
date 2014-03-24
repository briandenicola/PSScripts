param(    [string] $pull_server)configuration LetsGetConfiguring{    param ($NodeId, $PullServer)    
    LocalConfigurationManager    {        AllowModuleOverwrite = 'True'        ConfigurationID = $NodeId        ConfigurationModeFrequencyMins = 30        ConfigurationMode = 'ApplyAndAutoCorrect'        RebootNodeIfNeeded = 'True'        RefreshMode = 'PULL'         DownloadManagerName = 'WebDownloadManager'        DownloadManagerCustomData = (@{ServerUrl = "https://$PullServer/psdscpullserver.svc"})    }}

$node = [guid]::NewGuid().Guid
LetsGetConfiguring -NodeId $node.ToString() -PullServer $pull_serverSet-DscLocalConfigurationManager -path LetsGetConfiguring

Write-Host "Copy This Guid Down = $($node.ToString())  . . ."
Get-DscLocalConfigurationManager