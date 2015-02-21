[CmdletBinding(SupportsShouldProcess=$true)] 
param()

Import-module ServerManager

Set-Variable -Option Constant -Name now          -Value $(Get-Date).ToString("yyyyMMdd")
Set-Variable -Option Constant -Name drive        -Value $ENV:SystemDrive 
Set-Variable -Option Constant -Name appcmd       -Value (Join-Path -Path $ENV:SystemRoot -ChildPath "system32\inetsrv\appcmd.exe")
Set-Variable -Option Constant -Name iis_dir      -Value (Join-Path -Path $Drive -ChildPath "IIS")
Set-Variable -Option Constant -Name web_dir      -Value (Join-Path -Path $Drive -ChildPath "Web")
Set-Variable -Option Constant -Name log_dir      -Value (Join-Path -Path $Drive -ChildPath "Logs")
Set-Variable -Option Constant -Name logFile      -Value (Join-Path -Path $Drive -ChildPath ("iis_install-{0}.log" -f $now))
Set-Variable -Option Constant -Name logFlags     -Value "Date, Time, ClientIP, UserName, ServerIP, Method, UriStem, UriQuery, HttpStatus, BytesSent, BytesRecv, TimeTaken"
Set-Variable -Option Constant -Name backup       -Value ("Backup-Before-Configuration-{0}" -f $now)
Set-Variable -Option Constant -Name iis_modules  -Value @(
"Web-Server",
"Web-Common-Http",
"Web-Static-Content",
"Web-Default-Doc",
"Web-Dir-Browsing",
"Web-Http-Errors",
"Web-ASP-NET",
"Web-Net-Ext",
"Web-ISAPI-Ext",
"Web-ISAPI-Filter",
"Web-Health",
"Web-Http-Logging",
"Web-Log-Libraries",
"Web-Request-Monitor",
"Web-Http-Tracing",
"Web-Custom-Logging",
"Web-Security",
"Web-Basic-Auth",
"Web-Windows-Auth",
"Web-Digest-Auth",
"Web-Filtering",
"Web-Performance",
"Web-Stat-Compression",
"Web-Dyn-Compression",
"Web-Mgmt-Tools",
"Web-Mgmt-Console",
"Web-Metabase",
"Web-WMI",
"Web-Scripting-Tools",
"Web-Lgcy-Scripting",
"Web-Asp-Net45",
"Web-Net-Ext45",
"Web-AppInit",
"Web-Http-Redirect",
"Web-Mgmt-Service")

Write-Verbose -Message "Enable PowerShell Remoting and CredSSP"
Enable-PSRemoting -Confirm:$false 
Enable-WSManCredSSP -Role Client -DelegateComputer * -Force:$true
Enable-WSManCredSSP -Role Server -Force:$true

Write-Verbose -Message "Set TimeZone to Central Time"
tzutil.exe /s "Central Standard Time" 

Write-Verbose -Message "Remove Prompt for Reboots"
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 00000000

Write-Verbose -Message "Format and Mount Additional Drives"
Get-Disk | Where { $_.PartitionStyle -eq "RAW" } | Initialize-Disk -PartitionStyle MBR 
Get-Disk | Where { $_.NumberOfPartitions -eq 0 } |   
    New-Partition -AssignDriveLetter -UseMaximumSize |
    Format-Volume -FileSystem NTFS -Force -Confirm:$false

Write-Verbose -Message "Install the Application Server Role"
Add-WindowsFeature -name Application-Server

Write-Verbose -Message "Install IIS Modules and .NET Framework"
Add-WindowsFeature -name $iis_modules

Write-Verbose -Message "Write Installed Modules to $logFile"
Get-WindowsFeature | Where { $_.Installed -eq $true } | Out-File -Encoding ascii $logFile

Write-Verbose -Message "Create new IIS Folders"
if( -not (Test-Path $log_dir) ) { New-Item -Name $log_dir -ItemType Directory }
if( -not (Test-Path $web_dir) ) { New-Item -Name $web_dir -ItemType Directory }

Write-Verbose -Message "Backup IIS config before we start changing config to point to the new path"
Backup-WebConfiguration -Name $backup

Write-Verbose -Message "Stop all IIS services"
Stop-Service W3SVC,WAS -force

Write-Verbose -Message "Remove Default Site"
Remove-Website -Name "Default Web Site"

Write-Verbose -Message "Move IIS Files to $iis_dir"
Set-Variable -Name default_iisroot -Value (Join-Path $ENV:systemdrive "inetpub")
Copy-Item -Path $default_iisroot -Destination $iis_dir -Recurse
Move-Item -Path $default_iisroot -Destination ("{0}.{1}" -f $default_iisroot, $now)
Remove-Item -Recurse (Join-Path $iis_dir "wwwroot")

Write-Verbose -Message "`Setup Home Directory Root"
New-Item -Path "HKLM\Software\Microsoft\" -Name "inetstp" 
New-ItemProperty -Path "HKLM\Software\Microsoft\inetstp" -Name "PathWWWRoot" -Value $web_dir -PropertyType REG_SZ

Write-Verbose -Message "Setup Directories"
&$appcmd set config "-section:system.applicationHost/sites" "-siteDefaults.traceFailedRequestsLogging.directory:$iis_dir\logs\FailedReqLogFiles"
&$appcmd set config "-section:system.applicationHost/sites" "-siteDefaults.logfile.directory:$log_dir"
&$appcmd set config "-section:system.applicationHost/log" "-centralBinaryLogFile.directory:$log_dir"
&$appcmd set config "-section:system.applicationHost/log" "-centralW3CLogFile.directory:$log_dir"

Write-Verbose -Message "Setup Logging Flags and Rollover"
&$appcmd set config "-section:system.applicationHost/sites" "-siteDefaults.logfile.logExtFileFlags:$logFlags"
&$appcmd set config "-section:system.applicationHost/sites" "-siteDefaults.logFile.localTimeRollover:true"

Write-Verbose -Message "Move config history location, temporary files, and the custom error locations"
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

Write-Verbose -Message "Start all IIS services"
Restart-Service -Name W3SVC,WAS -force

Write-Verbose -Message "Enable Remote Management"
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WebManagement\Server -Name EnableRemoteManagement -Value 1
Restart-Service -Name WMSVC -Verbose
netsh advfirewall firewall add rule name=”Allow Web Management” dir=in action=allow service=”WMSVC”