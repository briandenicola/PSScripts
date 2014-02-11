$LocalizedData = ConvertFrom-StringData @'    
    AnErrorOccurred=An error occurred while creating IIS Site: {1}.
    InnerException=Nested error trying to create IIS Site: {1}.
'@

function Get-TargetResource 
{
    [OutputType([Hashtable])]
    param 
    (       
        [ValidateSet("Present")]
        [string] $ensure = "Present"
    )

    try {
        $Configuration = @{
            Ensure = 'Present'
        }

        return $Configuration
    }
    catch {
        $exception = $_    
        while ($exception.InnerException -ne $null)  {
            $exception = $exception.InnerException
            Write-Error ($LocalizedData.InnerException -f $name, $exception.message)
        }
    }        
} 

function Set-TargetResource 
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param 
    (       
        [ValidateSet("Present")]
        [string]$Ensure = "Present"
    )
 
    try {
        Import-module ServerManager

        $now = $(Get-Date).ToString("yyyyMMdd")

        Set-Variable -Name iis_modules  -Value @("Web-Server","Web-Common-Http","Web-Static-Content","Web-Default-Doc","Web-Dir-Browsing","Web-Http-Errors","Web-ASP-NET","Web-Net-Ext","Web-ISAPI-Ext","Web-ISAPI-Filter","Web-Health","Web-Http-Logging","Web-Log-Libraries","Web-Request-Monitor","Web-Http-Tracing","Web-Custom-Logging","Web-Security","Web-Basic-Auth","Web-Windows-Auth","Web-Digest-Auth","Web-Filtering","Web-Performance","Web-Stat-Compression","Web-Dyn-Compression","Web-Mgmt-Tools","Web-Mgmt-Console","Web-Metabase","Web-WMI","Web-Scripting-Tools","Web-Lgcy-Scripting")
        Set-Variable -Name iis8_modules -Value @("Web-Asp-Net45","Web-Net-Ext45","Web-AppInit","Web-Http-Redirect","Web-Mgmt-Service")

        Set-Variable -Option Constant -Name appcmd -Value "$ENV:windir\system32\inetsrv\appcmd.exe"

        if( (Get-PSDrive -PSProvider FileSystem | where { $_.Root -eq "D:\" }) ) { $drive = "D:" } else { $drive = "C:" }

        Set-Variable -Option Constant -Name iis_dir -Value "$Drive\IIS"
        Set-Variable -Option Constant -Name web_dir -Value "$Drive\Web"
        Set-Variable -Option Constant -Name log_dir -Value "$Drive\Logs"

        Set-Variable -Option Constant -Name iis_modules -Value ".\modules_to_install_common.txt"
        Set-Variable -Option Constant -Name iis8_modules -Value ".\modules_to_install_8.txt"
        Set-Variable -Option Constant -Name logFile -Value "$ENV:Temp\iis_install-$now.log"
        Set-Variable -Option Constant -Name logFlags -Value "Date, Time, ClientIP, UserName, ServerIP, Method, UriStem, UriQuery, HttpStatus, BytesSent, BytesRecv, TimeTaken"

        Add-WindowsFeature -name Application-Server
        Add-WindowsFeature -name $iis_modules
        Add-WindowsFeature -name $iis8_modules
        Get-WindowsFeature | where { $_.Installed -eq $true } | Out-File -Encoding ascii $logFile

        if( -not (Test-Path $log_dir) ) { mkdir $log_dir }
        if( -not (Test-Path $web_dir) ) { mkdir $web_dir }

        &$appcmd add backup BackupBeforeConfiguration

        iisreset /stop
        Remove-Website -Name "Default Web Site"
        Copy-Item -Recurse $ENV:systemdrive\inetpub $iis_dir\
        Remove-Item -Recurse $iis_dir\wwwroot
        Move-Item $ENV:SystemDrive\inetpub $ENV:SystemDrive\inetpub.org.$now
        reg add HKLM\Software\Microsoft\inetstp /v PathWWWRoot /t REG_SZ /d $web_dir /f 

        &$appcmd set config "-section:system.applicationHost/sites" "-siteDefaults.traceFailedRequestsLogging.directory:$iis_dir\logs\FailedReqLogFiles"
        &$appcmd set config "-section:system.applicationHost/sites" "-siteDefaults.logfile.directory:$log_dir"
        &$appcmd set config "-section:system.applicationHost/log" "-centralBinaryLogFile.directory:$log_dir"
        &$appcmd set config "-section:system.applicationHost/log" "-centralW3CLogFile.directory:$log_dir"
        &$appcmd set config "-section:system.applicationHost/sites" "-siteDefaults.logfile.logExtFileFlags:$logFlags"
        &$appcmd set config "-section:system.applicationHost/sites" "-siteDefaults.logFile.localTimeRollover:true"
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

        iisreset /start

        Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WebManagement\Server -Name EnableRemoteManagement -Value 1
        Restart-Service WMSVC -Verbose
        netsh advfirewall firewall add rule name=”Allow Web Management” dir=in action=allow service=”WMSVC”
    }
    catch {
        $exception = $_    
        while ($exception.InnerException -ne $null)  {
            $exception = $exception.InnerException
            Write-Error ($LocalizedData.InnerException -f $name, $exception.message)
        }
    } 
}

function Test-TargetResource 
{
    [OutputType([boolean])]
    param (
        [ValidateSet("Present")]
        [string]$Ensure = "Present"
    )  


    try {
        if( (Get-PSDrive -PSProvider FileSystem | where { $_.Root -eq "D:\" }) ) { $drive = "D:" } else { $drive = "C:" }

        Set-Variable -Option Constant -Name iis_dir -Value "$Drive\IIS"
        Set-Variable -Option Constant -Name web_dir -Value "$Drive\Web"
        Set-Variable -Option Constant -Name log_dir -Value "$Drive\Logs"
        Set-Variable -Name iis_modules  -Value @("Web-Server","Web-Common-Http","Web-Static-Content","Web-Default-Doc","Web-Dir-Browsing","Web-Http-Errors","Web-ASP-NET","Web-Net-Ext","Web-ISAPI-Ext","Web-ISAPI-Filter","Web-Health","Web-Http-Logging","Web-Log-Libraries","Web-Request-Monitor","Web-Http-Tracing","Web-Custom-Logging","Web-Security","Web-Basic-Auth","Web-Windows-Auth","Web-Digest-Auth","Web-Filtering","Web-Performance","Web-Stat-Compression","Web-Dyn-Compression","Web-Mgmt-Tools","Web-Mgmt-Console","Web-Metabase","Web-WMI","Web-Scripting-Tools","Web-Lgcy-Scripting")
        Set-Variable -Name iis8_modules -Value @("Web-Asp-Net45","Web-Net-Ext45","Web-AppInit","Web-Http-Redirect","Web-Mgmt-Service")

        foreach( $location in @($iis_dir, $web_dir, $log_dir) ) {
            if( -not ( Test-Path $location ) ) { return $false }
        }

        $features = Get-WindowsFeature | Where Installed -eq $true | Select -ExpandProperty Name 
        foreach( $module in ($iis8_modules + $iis_modules) ) {
            if(-not ( $module -in $features ) ) { return $false }
        }

        return $true 

    }
    catch {
        $exception = $_    
        while ($exception.InnerException -ne $null)  {
            $exception = $exception.InnerException
            Write-Error ($LocalizedData.InnerException -f $name, $exception.message)
        }
    } 
}
