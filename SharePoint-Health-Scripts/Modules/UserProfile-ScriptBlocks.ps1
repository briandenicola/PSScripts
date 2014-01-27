Set-Varaible -Name check_user_profile_sb -Value ( [ScriptBlock]  {
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")

    $farm_user = Get-FarmAccount . 

    $site = Get-SPSite ( Get-SPWebApplication | Select -Last 1 -Expand Url )
    $srvContext = Get-SPServiceContext $site

    $ups_manager = New-Object Microsoft.Office.Server.UserProfiles.UserProfileManager($srvContext) 
    
    $ups_config_manager = New-Object Microsoft.Office.Server.UserProfiles.UserProfileConfigManager($srvContext) 
    $sync = $ups_config_manager.GetSynchronizationStatus() | Select Stage, BeginTime, EndTime, State, Updates    

    net localgroup administrators ($ENV:userdomain + "\" + $farm_user.User) /delete

    return (New-Object PSObject -Property @{
        Count = $ups_manager.Count
        IsSyncing = $ups_config_manager.IsSynchronizationRunning()
        State = $sync 
    })
})