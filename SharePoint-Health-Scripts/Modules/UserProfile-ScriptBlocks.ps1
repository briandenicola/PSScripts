Set-Variable -Name check_user_profile_sb -Value ( [ScriptBlock]  {
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")

    $farm_user = (Get-SPFarm).DefaultServiceAccount.Name 

    $site = Get-SPSite ( Get-SPWebApplication | Select -Last 1 -Expand Url )
    $srvContext = Get-SPServiceContext $site

    $ups_manager = New-Object Microsoft.Office.Server.UserProfiles.UserProfileManager($srvContext) 
    
    $ups_config_manager = New-Object Microsoft.Office.Server.UserProfiles.UserProfileConfigManager($srvContext) 
    $sync = $ups_config_manager.GetSynchronizationStatus() | Select Stage, BeginTime, EndTime, State, Updates    

    net localgroup administrators $farm_user /delete

    return (New-Object PSObject -Property @{
        Count = $ups_manager.Count
        ChangeToken = $ups_manager.CurrentChangeToken
        IsSyncing = $ups_config_manager.IsSynchronizationRunning()
        MySiteHostUrl = $ups_manager.MySiteHostUrl
        SampleProfileUrl = ($ups_manager.GetUserProfile( $farm_user.Split("\")[1] ) | Select -Expand PersonalURl | Select -Expand OriginalString)
        State = $sync 
    })
})

Set-Variable -Name get_farm_account_sb -Value ( [ScriptBlock]  { 
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
    
    $farm_user = (Get-SPFarm).DefaultServiceAccount.Name  

    net localgroup administrators $farm_user /add

    return (New-Object PSObject -Property @{
        Name = $farm_user
        Password = Get-SPManageAccountPassword $farm_user.Split("\")[1]
    })
})

