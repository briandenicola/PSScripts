
$AutoUpdateNotificationLevels = @{
    0 = "Not configured"; 
    1 = "Disabled" ; 
    2 = "Notify before download"; 
    3 = "Notify before installation"; 
    4 = "Scheduled installation"
}

$AutoUpdateDays = @{
    0 = "Every Day"; 
    1 = "Every Sunday"; 
    2 = "Every Monday"; 
    3 = "Every Tuesday"; 
    4 = "Every Wednesday"; 
    5 = "Every Thursday"; 
    6 = "Every Friday"; 
    7 = "EverySaturday"
}

$AUSettings = (New-Object -com "Microsoft.Update.AutoUpdate").Settings

$AUObj = New-Object -TypeName PSObject -Property @{
    NotificationLevel  = $AutoUpdateNotificationLevels[$AUSettings.NotificationLevel]
    UpdateDays         = $AutoUpdateDays[$AUSettings.ScheduledInstallationDay]
    UpdateHour         = $AUSettings.ScheduledInstallationTime 
    RecommendedUpdates = $(IF ($AUSettings.IncludeRecommendedUpdates) {"Included."}  else {"Excluded."})
}

return $AuObj
