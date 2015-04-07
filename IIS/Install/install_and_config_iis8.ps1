[CmdletBinding(SupportsShouldProcess=$true)]
param()

Import-module ServerManager

$now = $(Get-Date).ToString("yyyyMMdd")

Set-Variable -Option Constant -Name appcmd -Value "$ENV:windir\system32\inetsrv\appcmd.exe"

function Detect-RunningOnAzure
{
    #Not implemenated yet
    return $false
}

if( ( [system.IO.DriveInfo]::GetDrives()  | Select -Expand Name) -contains "D:" -and !(Detect-RunningOnAzure) ) {
    $drive = "D:"
}

Set-Variable -Option Constant -Name iis_dir -Value (Join-Path $Drive "IIS")
Set-Variable -Option Constant -Name web_dir -Value (Join-Path $Drive "Web")
Set-Variable -Option Constant -Name log_dir -Value (Join-Path $Drive "Logs")

Set-Variable -Option Constant -Name iis_modules -Value (Join-Path $PWD.Path "modules_to_install_common.txt")
Set-Variable -Option Constant -Name iis8_modules -Value (Join-Path $PWD.Path "modules_to_install_8.txt")
Set-Variable -Option Constant -Name logFile -Value (Join-Path $ENV:Temp ("iis_install-{0}.log" -f $now))
Set-Variable -Option Constant -Name backup_configuration_name -Value ("Backup-Before-Configuration-{0}" -f $now)

Set-Variable -Option Constant -Name logFlags -Value "Date, Time, ClientIP, UserName, ServerIP, Method, UriStem, UriQuery, HttpStatus, BytesSent, BytesRecv, TimeTaken"

Write-Verbose -Message "1.0 Install Software"
Write-Verbose -Message "`t1.1 Install the Application Server Role and the .NET Framework"
Add-WindowsFeature -name Application-Server

Write-Verbose -Message "`t1.2 Install Web Server Role (IIS8)"
Add-WindowsFeature -name (Get-Content $iis_modules)
Add-WindowsFeature -name (Get-Content $iis8_modules)

Write-Verbose -Message "`t1.3 Write Installed Modules to $logFile"
Get-WindowsFeature | where { $_.Installed -eq $true } | Out-File -Encoding ascii $logFile

Write-Verbose -Message "2.0 Create new IIS Folders"
if( -not (Test-Path $log_dir) ) { New-Item -Name $log_dir -ItemType Directory }
if( -not (Test-Path $web_dir) ) { New-Item -Name $web_dir -ItemType Directory }

Write-Verbose -Message "3.0 Backup IIS config before we start changing config to point to the new path"
Backup-WebConfiguration $backup_configuration_name

Write-Verbose -Message"4.0 Stop all IIS services"
Stop-Service W3SVC,WAS -force

Write-Verbose -Message "5.0 Remove Default Site"
Remove-Website -Name "Default Web Site"

Write-Verbose -Message "`t5.1 Move Files"
Copy-Item -Recurse (Join-Path $ENV:systemdrive "inetpub") $iis_dir
Remove-Item -Recurse (Join-Path $iis_dir "wwwroot")
Move-Item (Join-Path $ENV:SystemDrive "inetpub") (Join-Path $ENV:SystemDrive "inetpub.org.{0}" -f $now)

Write-Verbose -Message "`t5.2 Setup Home Directory Root"
New-Item -Path "HKLM\Software\Microsoft\" -Name "inetstp" 
New-ItemProperty -Path "HKLM\Software\Microsoft\inetstp" -Name "PathWWWRoot" -Value $web_dir -PropertyType REG_SZ

Write-Verbose -Message "6.0 Setup Logging"
Write-Verbose -Message "`t6.1 Setup Directories"
&$appcmd set config "-section:system.applicationHost/sites" "-siteDefaults.traceFailedRequestsLogging.directory:$iis_dir\logs\FailedReqLogFiles"
&$appcmd set config "-section:system.applicationHost/sites" "-siteDefaults.logfile.directory:$log_dir"
&$appcmd set config "-section:system.applicationHost/log" "-centralBinaryLogFile.directory:$log_dir"
&$appcmd set config "-section:system.applicationHost/log" "-centralW3CLogFile.directory:$log_dir"

Write-Verbose -Message "`t6.2 Setup Logging Flags and Rollover"
&$appcmd set config "-section:system.applicationHost/sites" "-siteDefaults.logfile.logExtFileFlags:$logFlags"
&$appcmd set config "-section:system.applicationHost/sites" "-siteDefaults.logFile.localTimeRollover:true"

Write-Verbose -Message "7.0 Move config history location, temporary files, and the custom error locations"
&$appcmd set config "-section:system.applicationhost/configHistory" "-path:$iis_dir\history"
&$appcmd set config "-section:system.webServer/asp" "-cache.disktemplateCacheDirectory:$iis_dir\temp\ASP Compiled Templates"
&$appcmd set config "-section:system.webServer/httpCompression" "-directory:$iis_dir\temp\IIS Temporary Compressed Files"
New-ItemProperty -Path "HKLM\System\CurrentControlSet\Services\WAS\Parameters" -Name "ConfigIsolationPath" -Value (Join-Path $iis_dir "temp\appPools") -PropertyType REG_SZ

&$appcmd set config "-section:httpErrors" "/[statusCode='401'].prefixLanguageFilePath:$iis_dir\custerr"
&$appcmd set config "-section:httpErrors" "/[statusCode='403'].prefixLanguageFilePath:$iis_dir\custerr"
&$appcmd set config "-section:httpErrors" "/[statusCode='404'].prefixLanguageFilePath:$iis_dir\custerr"
&$appcmd set config "-section:httpErrors" "/[statusCode='405'].prefixLanguageFilePath:$iis_dir\custerr"
&$appcmd set config "-section:httpErrors" "/[statusCode='406'].prefixLanguageFilePath:$iis_dir\custerr"
&$appcmd set config "-section:httpErrors" "/[statusCode='412'].prefixLanguageFilePath:$iis_dir\custerr"
&$appcmd set config "-section:httpErrors" "/[statusCode='500'].prefixLanguageFilePath:$iis_dir\custerr"
&$appcmd set config "-section:httpErrors" "/[statusCode='501'].prefixLanguageFilePath:$iis_dir\custerr"
&$appcmd set config "-section:httpErrors" "/[statusCode='502'].prefixLanguageFilePath:$iis_dir\custerr"

Write-Verbose -Message "8.0 Start all IIS services"
Restart-Service W3SVC,WAS -force

Write-Verbose -Message "9.0 Enable Remote Management"
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WebManagement\Server -Name EnableRemoteManagement -Value 1
Restart-Service WMSVC -Verbose
netsh advfirewall firewall add rule name=”Allow Web Management” dir=in action=allow service=”WMSVC”