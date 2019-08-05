Write-Output -InputObject ("[{0}] - Importing Modules" -f $(Get-Date))
Import-module ServerManager

Write-Output -InputObject ("[{0}] - Setting Variables" -f $(Get-Date))
$now = $(Get-Date).ToString("yyyyMMdd")

Set-Variable -Option Constant -Name drive   -Value ($ENV:SystemDrive)
Set-Variable -Option Constant -Name web_dir -Value (Join-Path $Drive "Web")
Set-Variable -Option Constant -Name log_dir -Value (Join-Path $Drive "Logs")

Set-Variable -Option Constant -Name logFile -Value (Join-Path $ENV:Temp ("iis_install-{0}.log" -f $now))
Set-Variable -Option Constant -Name backup_configuration_name -Value ("Backup-Before-Configuration-{0}" -f $now)
Set-Variable -Option Constant -Name logFlags -Value "Date, Time, ClientIP, UserName, ServerIP, Method, UriStem, UriQuery, HttpStatus, BytesSent, BytesRecv, TimeTaken"

Write-Output -InputObject ("[{0}] - Adding Features" -f $(Get-Date))
Add-WindowsFeature -name @( "NET-Framework-45-ASPNET", "Web-Asp-Net45", "Web-Http-Redirect", "Web-Server","Web-Common-Http", "Web-Static-Content", "Web-Default-Doc","Web-Dir-Browsing", 
"Web-Http-Errors", "Web-Health", "Web-Http-Logging", "Web-Log-Libraries", "Web-Request-Monitor", "Web-Http-Tracing", "Web-Custom-Logging",
"Web-Security", "Web-Basic-Auth", "Web-Windows-Auth", "Web-Filtering", "Web-Performance", "Web-Stat-Compression", "Web-Dyn-Compression", "Web-Mgmt-Tools", "Web-Mgmt-Console")
Get-WindowsFeature | Where-Object { $_.Installed -eq $true } | Out-File -Encoding ascii $logFile

Write-Output -InputObject ("[{0}] - Creating Directories" -f $(Get-Date))
if( -not (Test-Path $web_dir) ) { New-Item -Path $web_dir -ItemType Directory }
if( -not (Test-Path $log_dir) ) { New-Item -Path $log_dir -ItemType Directory }

Write-Output -InputObject ("[{0}] - Backing Up Configuration" -f $(Get-Date))
Backup-WebConfiguration $backup_configuration_name

Write-Output -InputObject ("[{0}] - Removing Default Site" -f $(Get-Date))
Stop-Service W3SVC,WAS -force
Remove-Website -Name "Default Web Site"
Remove-Item -Recurse (Join-Path -Path $ENV:SystemDrive -ChildPath "\inetpub\wwwroot")

Write-Output -InputObject ("[{0}] - Updating Log Directories" -f $(Get-Date))
Set-WebConfigurationProperty "/system.applicationHost/sites/siteDefaults" -name logfile.directory -value $log_dir
Set-WebConfigurationProperty "/system.applicationHost/sites/siteDefaults" -name logfile.logExtFileFlags -value $logFlags
Set-WebConfigurationProperty "/system.applicationHost/sites/siteDefaults" -name logfile.localTimeRollover -value $true

$site_name = "01"
$site_path = Join-Path -Path $web_dir -ChildPath $site_name 

Write-Output -InputObject ("[{0}] - Creating Default Site" -f $(Get-Date))
New-Item -Path $site_path -ItemType Directory 
New-WebSite -PhysicalPath $site_path -Name $site_name
'<html><head></head><body><form runat="server">The server name is: <%=System.Net.Dns.GetHostName().ToString() %> <BR/></form></body></html>' | 
    Out-File -FilePath (Join-Path -Path $site_path -ChildPath "default.aspx") -Encoding ascii -Append

#Start-Service W3SVC,WAS