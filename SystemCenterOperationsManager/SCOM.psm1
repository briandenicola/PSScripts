. (Join-Path $env:SCRIPTS_HOME "Libraries\Standard_Variables.ps1")
Import-Module OperationsManager
New-SCOMManagementGroupConnection $global:scom_mgmt_server

function Reset-SCOMHealthState
{
    <#
    .SYNOPSIS
    This PowerShell function will recalculate an object's health state in System Center.

    .EXAMPLE
    Reset-SCOMHealthState

    .EXAMPLE
    Reset-SCOMHealthState -scom_group "SharePoint Shared Service Application"

    #>

    param( [string] $scom_group = "SharePoint Server")
    New-SCOMManagementGroupConnection $global:scom_mgmt_server
    Get-SCOMClass | Where DisplayName -eq $scom_group | Get-SCOMClassInstance | Where HealthState -imatch "Error|Warning" | ForEach-Object { $_.ResetMonitoringState() }
}

function Close-SCOMAlert
{
    <#
    .SYNOPSIS
    This PowerShell function will close any open System Center alert for a given Group.

    .EXAMPLE
    Close-SCOMAlert

    .EXAMPLE
    Close-SCOMAlert -scom_group "SharePoint Shared Service Application" -Comment "Closed by Brian"

    #>

    param( 
        [string] $scom_group = "SharePoint Server",
        [string] $comment = "Closed by PowerShell"
    )

    Get-SCOMClass | Where DisplayName -eq $scom_group | 
        Get-SCOMClassInstance | 
        ForEach-Object { $_.GetMonitoringAlerts() } | 
        Where ResolutionState -ne 255 |
        Resolve-SCOMAlert -Comment $commnet -Verbose 
}

function Get-SCOMAlerts
{
    <#
    .SYNOPSIS
    This PowerShell 

    .EXAMPLE
    Get-SCOMAlerts

    .EXAMPLE
    Get-SCOMAlerts -scom_group "SharePoint Shared Service Application"

    #>

    param( [string] $scom_group = "SharePoint Server")

    Get-SCOMClass | Where DisplayName -eq $scom_group | 
        Get-SCOMClassInstance | 
        ForEach-Object { $_.GetMonitoringAlerts() } | 
        Sort-Object -Property TimeRaised -Descending | 
        Format-Table -GroupBy ResolutionState
}

function Get-SCOMHealthState
{
    <#
    .SYNOPSIS
    This PowerShell function will get a SCOM Group's object Health State Sorted by the HealthState

    .EXAMPLE
    Get-SCOMHealthState

    .EXAMPLE
    Get-SCOMHealthState -scom_group "SharePoint Shared Service Application"

    #>

    param( [string] $scom_group = "SharePoint Server")

    Get-SCOMClass | Where DisplayName -eq $scom_group | Get-SCOMClassInstance | Sort -Property HealthState | Format-Table -GroupBy HealthState
}

Export-ModuleMember -Function Get-SCOMHealthState, Get-SCOMAlerts, Close-SCOMAlert, Reset-SCOMHealthState