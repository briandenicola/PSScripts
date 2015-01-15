<#
.SYNOPSIS
This PowerShell Script will is a Quick and Dirty First Pass as Automating some basis tasks in System Center Operations Manager

.EXAMPLE
.\QAD-Reset-Server-Health.ps1

.EXAMPLE
.\QAD-Reset-Server-Health.ps1 -scom_group "SharePoint Shared Service Application"

#>

param(
    [string] $scom_group = "SharePoint Server",
    [string] $scom_server = ""
)

#SharePoint Foundation 2010 Objects Group
#SharePoint Component
#SharePoint Database
#SharePoint Configuration Database
#SharePoint Farm
#Microsoft SharePoint 2010 Farm Group
#SharePoint Service Instance
#SharePoint Shared Service Application
#SharePoint Timer Job
#SharePoint Timer Job Instance
#SharePoint Server
#SharePoint Server Group
#SharePoint Service
#SharePoint Services Group
#SharePoint Site
#SharePoint Topology Application
#SharePoint Usage Application
#SharePoint Shared Service Group
#SharePoint Content Database
#SharePoint Content Database Collection
#SharePoint Web Application Instance
#SharePointWeb Application Instance Collection
#SharePoint Site Collection
#SharePoint Web Application Group
#Unidentified SharePoint Servers
#Unidentified SharePoint Machine
#SharePoint Installed Machine
#SharePoint 2010 Control Group
#SharePoint Installed Machine

Import-Module OperationsManager
New-SCOMManagementGroupConnection $scom_server

#Get-SCOMGroup -DisplayName $scom_group | Get-SCOMClassInstance  | Where HealthState -imatch "Error|Warning" | % { $_.ResetMonitoringState() }
Get-SCOMClass | Where DisplayName -eq $scom_group | Get-SCOMClassInstance | Where HealthState -imatch "Error|Warning" | % { $_.ResetMonitoringState() }