Import-module ServerManager

$now = $(Get-Date).ToString("yyyyMMdd")

Set-Variable -Option Constant -Name appcmd -Value "$ENV:windir\system32\inetsrv\appcmd.exe"

if( (Get-PSDrive -PSProvider FileSystem | where { $_.Root -eq "D:\" }) ) { $drive = "D:" } else { $drive = "C:" }

Set-Variable -Option Constant -Name iis_dir -Value "$Drive\IIS"
Set-Variable -Option Constant -Name web_dir -Value "$Drive\Web"
Set-Variable -Option Constant -Name log_dir -Value "$Drive\Logs"

Set-Variable -Option Constant -Name iis_modules -Value ".\modules_to_install_common.txt"
Set-Variable -Option Constant -Name iis8_modules -Value ".\modules_to_install_8.txt"
Set-Variable -Option Constant -Name logFile -Value "$ENV:Temp\iis_install-$now.log"

Set-Variable -Option Constant -Name logFlags -Value "Date, Time, ClientIP, UserName, ServerIP, Method, UriStem, UriQuery, HttpStatus, BytesSent, BytesRecv, TimeTaken"

Write-Host "1.0 Install Software"
Write-Host "`t1.1 Install the Application Server Role and the .NET Framework"
Add-WindowsFeature -name Application-Server

Write-Host "`t1.2 Install Web Server Role (IIS8)"
Add-WindowsFeature -name (gc $iis_modules)
Add-WindowsFeature -name (gc $iis8_modules)

Write-Host "`t1.3 Write Installed Modules to $logFile"
Get-WindowsFeature | where { $_.Installed -eq $true } | Out-File -Encoding ascii $logFile

Write-Host "2.0 Create new IIS Folders"
if( -not (Test-Path $log_dir) ) { mkdir $log_dir }
if( -not (Test-Path $web_dir) ) { mkdir $web_dir }

Write-Host "3.0 Backup IIS config before we start changing config to point to the new path"
&$appcmd add backup BackupBeforeConfiguration

Write-Host "4.0 Stop all IIS services"
iisreset /stop

Write-Host "5.0 Remove Default Site"
Remove-Website -Name "Default Web Site"

Write-Host "`t5.1 Move Files"
Copy-Item -Recurse $ENV:systemdrive\inetpub $iis_dir\
Remove-Item -Recurse $iis_dir\wwwroot
Move-Item $ENV:SystemDrive\inetpub $ENV:SystemDrive\inetpub.org.$now

Write-Host "`t5.2 Setup Home Directory Root"
reg add HKLM\Software\Microsoft\inetstp /v PathWWWRoot /t REG_SZ /d $web_dir /f 

Write-Host "6.0 Setup Logging"
Write-Host "`t6.1 Setup Directories"
&$appcmd set config "-section:system.applicationHost/sites" "-siteDefaults.traceFailedRequestsLogging.directory:$iis_dir\logs\FailedReqLogFiles"
&$appcmd set config "-section:system.applicationHost/sites" "-siteDefaults.logfile.directory:$log_dir"
&$appcmd set config "-section:system.applicationHost/log" "-centralBinaryLogFile.directory:$log_dir"
&$appcmd set config "-section:system.applicationHost/log" "-centralW3CLogFile.directory:$log_dir"

Write-Host "`t6.2 Setup Logging Flags and Rollover"
&$appcmd set config "-section:system.applicationHost/sites" "-siteDefaults.logfile.logExtFileFlags:$logFlags"
&$appcmd set config "-section:system.applicationHost/sites" "-siteDefaults.logFile.localTimeRollover:true"

Write-Host "7.0 Move config history location, temporary files, and the custom error locations"
&$appcmd set config "-section:system.applicationhost/configHistory" "-path:$iis_dir\history"
&$appcmd set config "-section:system.webServer/asp" "-cache.disktemplateCacheDirectory:$iis_dir\temp\ASP Compiled Templates"
&$appcmd set config "-section:system.webServer/httpCompression" "-directory:$iis_dir\temp\IIS Temporary Compressed Files"
reg add HKLM\System\CurrentControlSet\Services\WAS\Parameters /v ConfigIsolationPath /t REG_SZ /d $iis_dir\temp\appPools

&$appcmd set config "-section:httpErrors" "/[statusCode='401'].prefixLanguageFilePath:$iis_dir\custerr"
&$appcmd set config "-section:httpErrors" "/[statusCode='403'].prefixLanguageFilePath:$iis_dir\custerr"
&$appcmd set config "-section:httpErrors" "/[statusCode='404'].prefixLanguageFilePath:$iis_dir\custerr"
&$appcmd set config "-section:httpErrors" "/[statusCode='405'].prefixLanguageFilePath:$iis_dir\custerr"
&$appcmd set config "-section:httpErrors" "/[statusCode='406'].prefixLanguageFilePath:$iis_dir\custerr"
&$appcmd set config "-section:httpErrors" "/[statusCode='412'].prefixLanguageFilePath:$iis_dir\custerr"
&$appcmd set config "-section:httpErrors" "/[statusCode='500'].prefixLanguageFilePath:$iis_dir\custerr"
&$appcmd set config "-section:httpErrors" "/[statusCode='501'].prefixLanguageFilePath:$iis_dir\custerr"
&$appcmd set config "-section:httpErrors" "/[statusCode='502'].prefixLanguageFilePath:$iis_dir\custerr"

Write-Host "8.0 Start all IIS services"
iisreset /start

Write-Host "9.0 Enable Remote Management"
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WebManagement\Server -Name EnableRemoteManagement -Value 1
Restart-Service WMSVC -Verbose
netsh advfirewall firewall add rule name=”Allow Web Management” dir=in action=allow service=”WMSVC”

