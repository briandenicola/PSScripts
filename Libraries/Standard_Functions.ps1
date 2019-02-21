function New-Salt {
    $saltLengthLimit = 32
    $salt = [System.Byte[]]::new($saltLengthLimit)
    $random = New-Object "System.Security.Cryptography.RNGCryptoServiceProvider"
    $random.GetNonZeroBytes($salt)
    return [System.Convert]::ToBase64String($salt)
}
function New-AesKey {
    $aes = New-Object "System.Security.Cryptography.AesManaged"
    $aes.KeySize = 256
    1 .. ( Get-Random -Minimum 500 -Maximum 1500) | ForEach-Object { $aes.GenerateKey() }
    return( [System.Convert]::ToBase64String($aes.Key) )
}

function Encrypt-File {
    param(
        [Parameter(Mandatory = $true)]
        [string] $fileName,

        [Parameter(Mandatory = $false)]	
        [string] $key,

        [Parameter(Mandatory = $false)]	
        [switch] $remove
    )

    $aes = New-Object "System.Security.Cryptography.AesManaged"
    $aes.KeySize = 256

    if ([string]::IsNullOrEmpty($key)) {
        $aes.GenerateKey()
    }
    else {
        $aes.Key = [System.Convert]::FromBase64String($key)
    }

    $encryptedFile = $fileName + ".enc"

    $reader = New-Object System.IO.FileStream($fileName, [System.IO.FileMode]::Open)
    $writer = New-Object System.IO.FileStream($encryptedFile, [System.IO.FileMode]::Create)

    $aes.GenerateIV()
    $encryptor = $aes.CreateEncryptor()
    $stream = New-Object System.Security.Cryptography.CryptoStream($writer, $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
    $reader.CopyTo($stream)
    
    $stream.FlushFinalBlock()
    $stream.Close()
    $reader.Close()
    $writer.Close()

    if ($remove) { Remove-Item -Path $fileName -Force -Confirm:$false}

    $opts = [ordered] @{
        OriginalFile  = $fileName
        EncryptedFile = $encryptedFile
        Key           = [System.Convert]::ToBase64String($aes.Key)
    }
    $result = New-Object psobject -Property $opts

    return $result 
}

function Encrypt-File {
    param(
        [Parameter(Mandatory = $true)]
        [string] $fileName,

        [Parameter(Mandatory = $false)]	
        [string] $key,

        [Parameter(Mandatory = $false)]	
        [switch] $remove
    )

    $aes = New-Object "System.Security.Cryptography.AesManaged"
    $aes.KeySize = 256

    if ([string]::IsNullOrEmpty($key)) {
        $aes.GenerateKey()
    }
    else {
        $aes.Key = [System.Convert]::FromBase64String($key)
    }

    $encryptedFile = $fileName + ".enc"

    $reader = New-Object System.IO.FileStream($fileName, [System.IO.FileMode]::Open)
    $writer = New-Object System.IO.FileStream($encryptedFile, [System.IO.FileMode]::Create)

    $aes.GenerateIV()
    $encryptor = $aes.CreateEncryptor()
    $stream = New-Object System.Security.Cryptography.CryptoStream($writer, $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
    $reader.CopyTo($stream)
    
    $stream.FlushFinalBlock()
    $stream.Close()
    $reader.Close()
    $writer.Close()

    if ($remove) { Remove-Item -Path $fileName -Force -Confirm:$false}
	
    $opts = [ordered] @{
        OriginalFile  = $fileName
        EncryptedFile = $encryptedFile
        Key           = [System.Convert]::ToBase64String($aes.Key)
    }
    $result = New-Object psobject -Property $opts

    return $result 
}

#https://www.powershellgallery.com/packages/psbbix/0.1.6/Content/epoch-time-convert.ps1
function Convert-SecondsFromEpochToDate {
    param(
        [int64] $totalSeconds
    )

    $epoch = Get-Date -Date "1/1/1970 12:00:00 AM"
    return $(Get-Date -date $epoch).AddSeconds($totalSeconds).ToLocalTime()
}

#https://gallery.technet.microsoft.com/JWT-Token-Decode-637cf001
function Get-DecodedJwtToken {
    param (
        [string] $Token
    )

    function Convert-FromBase64StringWithNoPadding {
        param( [string]$data )
        $data = $data.Replace('-', '+').Replace('_', '/')
        switch ($data.Length % 4) {
            0 { break }
            2 { $data += '==' }
            3 { $data += '=' }
            default { throw New-Object ArgumentException('data') }
        }
        return [System.Convert]::FromBase64String($data)
    }

    $parts = $Token.Split('.');
    $headers = [System.Text.Encoding]::UTF8.GetString( (Convert-FromBase64StringWithNoPadding -data $parts[0]) )
    $claims = [System.Text.Encoding]::UTF8.GetString( (Convert-FromBase64StringWithNoPadding -data $parts[1]) )
    $signature = (Convert-FromBase64StringWithNoPadding -data $parts[2])

    $customObject = [PSCustomObject] @{
        headers   = ($headers | ConvertFrom-Json)
        claims    = ($claims | ConvertFrom-Json)
        signature = $signature
    }

    return $customObject
}

function Get-DnsServer {
    [CmdletBinding()]
    param (
        [Parameter(DontShow)]
        [string] $Alias = "Ethernet"
    )

    return (Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object InterfaceAlias -eq  $Alias  | Select-Object -ExpandProperty ServerAddresses)
}

function Set-DnsServer {
    [CmdletBinding()]
    param (
        [switch] $Reset,

        [ValidateScript( {$_ -match [IPAddress]$_ })]  
        [string] $DNSServer = '1.1.1.1',

        [Parameter(DontShow)]
        [string] $Alias = "Ethernet"
    )

    Set-Variable -Name update  -Value "-Command &{ Set-DnsClientServerAddress -InterfaceAlias $Alias -ServerAddresses $DNSServer}" -Option Constant
    Set-Variable -Name restore -Value "-Command &{ Set-DnsClientServerAddress -InterfaceAlias $Alias -ResetServerAddresses}" -Option Constant

    $ArgumentList = $restore
    if (!$Reset) {
        $ArgumentList = $update
    }
    Start-Process -FilePath powershell.exe -verb runas -ArgumentList $ArgumentList  -WindowStyle Hidden -Wait

    $dns_addresses = Get-DnsClientServerAddress | Where-Object { $_.InterfaceAlias -eq $Alias -and $_.AddressFamily -eq 2} | Select-Object -ExpandProperty ServerAddresses
    Write-Verbose -Message ("The local DNS Server has been set to {0} . . . " -f $dns_addresses)
}

function Set-PublicKey {
    param ( 
        [string] $FilePath 
    )

    $ENV:PUBKEY = $FilePath
    [Environment]::SetEnvironmentVariable( "PUBKEY", $FilePath, "User" )
}

function Get-PublicKey {
    Get-Content -Path $ENV:PUBKEY | Set-Clipboard
}

function Set-RDPFile {
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Directory')]
        [ValidateScript( {Test-Path $_ -PathType 'Container'})] 
        [string] $Path,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [ValidateScript( {Test-Path $_ -PathType 'Leaf'})] 
        [string] $RDPFile
    )

    function Get-FullAddress {
        param  ( [string] $file )
        return ( Select-String -Pattern "full address"  -Path  $file | Select-Object -Expand Line -First 1 )
    }

    $rdp_settings = @"
        {0}
        prompt for credentials:i:1                    
        screen mode id:i:1                            
        desktopwidth:i:1280                           
        desktopheight:i:768                           
        redirectprinters:i:0                          
        redirectcomports:i:0                          
        redirectclipboard:i:1                         
        redirectposdevices:i:0                        
        drivestoredirect:s:*
"@

    switch ($PsCmdlet.ParameterSetName) { 
        "Directory" { 
            Get-ChildItem -Path $path -Recurse -Include "*.rdp" -Depth 0 | ForEach-Object {
                Write-Verbose -Message ("Updating RDP file {0} to preferred settings . . ." -f $_.FullName)
                $address = Get-FullAddress -file $_.FullName
                Set-Content -Encoding Ascii -Value ( $rdp_settings -f $address) -Path $_.FullName
            }
        }
        "File" { 
            Write-Verbose -Message ("Updating RDP file {0} to preferred settings . . ." -f $RDPFile)
            $address = Get-FullAddress -file $RDPFile
            Set-Content -Encoding Ascii -Value ( $rdp_settings -f $address) -Path $RDPFile
        }
    }
}

function Get-MyPublicIPAddress {
    param( [switch] $CopyToClipboard )
    $ip = Resolve-DnsName -Name o-o.myaddr.l.google.com -Type TXT -NoHostsFile -DnsOnly -Server ns1.google.com | Select-Object -ExpandProperty Strings 

    if ( $CopyToClipboard ) { $ip | Set-Clipboard }
    return $ip
}

#https://github.com/BornToBeRoot/PowerShell
function Get-WindowsProductKey {
    $key = [string]::Null 
    $chars = "BCDFGHJKMPQRTVWXY2346789" 

    $ProductKeyValue = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").digitalproductid[0x34..0x42]
    $Wmi_Win32 = Get-WmiObject -Class Win32_OperatingSystem
	   
    for ($i = 24; $i -ge 0; $i--) { 
        $r = 0 

        for ($j = 14; $j -ge 0; $j--) { 
            $r = ($r * 256) -bxor $ProductKeyValue[$j] 
            $ProductKeyValue[$j] = [math]::Floor([double]($r / 24)) 
            $r = $r % 24 
        }
 
        $key = $Chars[$r] + $key  
        if (($i % 5) -eq 0 -and $i -ne 0) { 
            $key = "-" + $key 
        } 
    } 

    return (New-Object -TypeName PSObject -Property @{
            ComputerName   = $ENV:COMPUTERNAME
            Caption        = $Wmi_Win32.Caption
            WindowsVersion = $Wmi_Win32.Version
            OSArchitecture = $Wmi_Win32.OSArchitecture
            BuildNumber    = $Wmi_Win32.BuildNumber
            ProductKey     = $key
        })
}

function Add-TrustedRemotingEndpoint {
    param(
        [string] $HostName
    )
    
    $WSMANPath = "WSMAN:\LocalHost\Client\TrustedHosts"
    $trustedHosts = Get-Item -Path $WSMANPath | Select-Object -Expand Value

    if ( [string]::IsNullOrEmpty($trustedHosts) ) {
        Set-Item -Path $WSMANPath -Value $HostName
    }
    else {
        Set-Item -Path $WSMANPath -Value ("{0},{1}" -f $trustedHosts, $HostName)
    }
}

function Get-TrustedRemotingEndpoint {    
    $WSMANPath = "WSMAN:\LocalHost\Client\TrustedHosts"
    $trustedHosts = Get-Item -Path $WSMANPath | Select-Object -Expand Value
    return $trustedHosts.Split(",")
}

function Get-Fonts {
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
    $objFonts = New-Object System.Drawing.Text.InstalledFontCollection
    return $objFonts.Families
}

function Update-PathVariable {
    param(	
        [Parameter(Mandatory = $true)]
        [ValidateScript( {Test-Path $_})]
        [string] $Path,
		
        [Parameter(Mandatory = $false)]
        [ValidateSet("User", "Machine")] 
        [string] $Target = "User" 
    )

    $current_path = [Environment]::GetEnvironmentVariable( "Path", $Target )
	
    Write-Verbose -Message ("[Update-PathVariable] - Current Path Value: {0}" -f $current_path )
	
    $current_path = $current_path.Split(";") + $Path
    $new_path = [string]::Join( ";", $current_path)
	
    Write-Verbose -Message ("[Update-PathVariable] - New Path Value: {0}" -f $new_path)
    [Environment]::SetEnvironmentVariable( "Path", $new_path, $Target )
}

function Get-GacAssembly {
    param(		
        [Parameter(Mandatory = $false)]
        [ValidateSet("v2.0", "v4.0")]
        [string] $TargetFramework = "v2.0|v4.0"
    )

    function Get-Architecture {
        param( [string] $Path )
        if ( $Path -imatch "_64"   ) { return "AMD64" }
        if ( $Path -imatch "_MSIL" ) { return "MSIL"  }
        return "x86"
    }

    $gac_locations = @(
        @{ "Path" = "C:\Windows\assembly"; "Version" = "v2.0" },
        @{ "Path" = "C:\Windows\Microsoft.NET\assembly"; "Version" = "v4.0" }
    )

    Set-Variable -Name assemblies -Value @()
	
    foreach ( $location in ($gac_locations | Where-Object Version -imatch $TargetFramework) ) {
        $framework = $location.Version 
        foreach ( $assembly in (Get-ChildItem -Path $location.Path -Include "*.dll" -Recurse) ) {
            $public_key = $assembly.Directory.Name.Split("_") | Select-Object -Last 1
		
            $properties = [ordered] @{
                Name         = $assembly.BaseName
                Version      = $assembly.VersionInfo.ProductVersion
                PublicKey    = $public_key
                LastModified = $assembly.LastWriteTime
                Framework    = $framework
                Architecture = Get-Architecture -Path $assembly.FullName 
            }
		
            $assemblies += (New-Object PSObject -Property $properties)
        } 
    }
	
    return $assemblies
}

function New-PSCredentials {
    param(
        [string] $UserName,
        [string] $Password
    )

    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    return ( New-Object System.Management.Automation.PSCredential ($UserName, $SecurePassword) )
}

function Check-ServerAccess {
    param(
        [string] $computer
    )

    Get-WmiObject -Query "Select Name from Win32_ComputerSystem" -ComputerName $computer -ErrorAction SilentlyContinue | Out-Null
    return $? 
}

function Create-DBConnectionString {
    param(
        [Parameter(Mandatory = $True)][string]$sql_instance,
        [Parameter(Mandatory = $True)][string]$database,

        [Parameter(Mandatory = $False, ParameterSetName = "Integrated")][switch] $integrated_authentication,
        [Parameter(Mandatory = $true, ParameterSetName = "SQL")][string]$user = [string]::empty,
        [Parameter(Mandatory = $true, ParameterSetName = "SQL")][string]$password = [string]::empty
    )
    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder['Data Source'] = $sql_instance
    $builder['Initial Catalog'] = $database

    if ( $integrated_authentication ) { 
        $builder['Integrated Security'] = $true
    }
    else { 
        $builder['User ID'] = $user
        $builder['Password'] = $password
    }

    return $builder.ConnectionString
}

function Get-RemoteDesktopSessions {
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [string[]] $computers
    )
     
    begin {
        $users = @()
        $filter = "name='explorer.exe'"
    }
    process {
        foreach ( $computer in $computers ) {
            foreach ( $process in (Get-WmiObject -ComputerName $computer -Class Win32_Process -Filter $filter ) ) {
                $users += (New-Object PSObject -Property @{
                        Computer = $computer
                        User     = $process.getOwner() | Select-Object -Expand User
                    })                     
            }
        }
    }
    end {
        return $users
    }
}

function New-PSWindow { 
    param( 
        [switch] $noprofile
    )
	
    if ($noprofile) { 
        cmd.exe /c start powershell.exe -NoProfile
    }
    else {
        cmd.exe /c start powershell.exe 
    }
}

function Get-InstalledDotNetVersions {
    $path = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP'

    return (
        Get-ChildItem $path -recurse | 
            Get-ItemProperty -Name Version  -ErrorAction SilentlyContinue | 
            Select-Object  -Unique -Expand Version
    )
}

function Get-DetailedServices {
    param(
        [string] $ComputerName = $ENV:COMPUTERNAME,
        [string] $state = "running"
    )
    
    $services = @()

    $processes = Get-WmiObject Win32_process -ComputerName $ComputerName
    foreach ( $service in (Get-WmiObject -ComputerName $ComputerName -Class Win32_Service -Filter ("State='{0}'" -f $state ) )  ) {
        
        $process = $processes | Where-Object { $_.ProcessId -eq $service.ProcessId }
    
        $services += (New-Object PSObject -Property @{
                Name        = $service.Name
                DisplayName = $service.DisplayName
                User        = $process.getOwner().user
                CommandLine = $process.CommandLine
                PID         = $process.ProcessId
                Memory      = [math]::Round( $process.WorkingSetSize / 1mb, 2 )
            })    

    }

    return $Services
}

function Get-FileEncoding {
    param (
        [Parameter(Mandatory = $True)] 
        [string] $Path
    )

    [byte[]]$byte = Get-Content -Encoding byte -ReadCount 4 -TotalCount 4 -Path $Path

    $fileType = 'ASCII'
    if ( $byte[0] -eq 0xef -and $byte[1] -eq 0xbb -and $byte[2] -eq 0xbf ) {
        $fileType = 'UTF8' 
    } 
    elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff) {
        $fileType = 'Unicode' 
    }
    elseif ($byte[0] -eq 0 -and $byte[1] -eq 0 -and $byte[2] -eq 0xfe -and $byte[3] -eq 0xff) {
        $fileType = 'UTF32' 
    }
    elseif ($byte[0] -eq 0x2b -and $byte[1] -eq 0x2f -and $byte[2] -eq 0x76) {
        $fileType = 'UTF7'
    }

    return $fileType
}

function Disable-InternetExplorerESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer
    Write-Verbose -Message ("IE Enhanced Security Configuration (ESC) has been disabled.")
}

function Enable-InternetExplorerESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 1
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 1
    Stop-Process -Name Explorer
    Write-Verbose -Message ("IE Enhanced Security Configuration (ESC) has been enabled.")
}

function Disable-UserAccessControl {
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 00000000
    Write-Verbose -Message ("User Access Control (UAC) has been disabled.")
}
 
function Get-Url {
    param(
        [string] $url,
        [ValidateSet("NTLM", "BASIC", "NONE")]
        [string] $AuthType = "NTLM",
        [ValidateSet("HEAD", "POST", "GET")]
        [string] $Method = "HEAD",
        [int] $timeout = 8,
        [string] $Server,
        [Management.Automation.PSCredential] $creds
    )
    
    $request = [System.Net.WebRequest]::Create($url)
    $request.Method = $Method
    $request.Timeout = $timeout * 1000
    $request.AllowAutoRedirect = $false
    $request.ContentType = "application/x-www-form-urlencoded"
    $request.UserAgent = "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0; .NET CLR 1.1.4322)"
    
    if ($AuthType -eq "BASIC") {
        $network_creds = $creds.GetNetworkCredential()
        $auth = "Basic " + [Convert]::ToBase64String([Text.Encoding]::Default.GetBytes($network_creds.UserName + ":" + $network_creds.Password))
        $request.Headers.Add("Authorization", $auth)
        $request.Credentials = $network_creds
        $request.PreAuthenticate = $true
    }
    elseif ( $AuthType -eq "NTLM" ) {
        $request.Credentials = [System.Net.CredentialCache]::DefaultCredentials
    }
       
    if ( -not [String]::IsNullorEmpty($Server) ) {
        #$request.Headers.Add("Host", $HostHeader)
        $request.Proxy = new-object -typename System.Net.WebProxy -argumentlist $Server
    }
    
    #Wrap this with a measure-command to determine type
    "[{0}][REQUEST] Getting $url ..." -f $(Get-Date)
    try {
        $timing_request = Measure-Command { $response = $request.GetResponse() }
        $stream = $response.GetResponseStream()
        #$reader = New-Object System.IO.StreamReader($stream)

        "[{0}][REPLY] Server = {1} " -f $(Get-Date), $response.Server
        "[{0}][REPLY] Status Code = {1} {2} . . ." -f $(Get-Date), $response.StatusCode, $response.StatusDescription
        "[{0}][REPLY] Content Type = {1} . . ." -f $(Get-Date), $response.ContentType
        "[{0}][REPLY] Content Length = {1} . . ." -f $(Get-Date), $response.ContentLength
        "[{0}][REPLY] Total Time = {1} . . ." -f $(Get-Date), $timing_request.TotalSeconds

    }
    catch [System.Net.WebException] {
        Write-Error ("The request failed with the following WebException - " + $_.Exception.ToString() )
    }
    
}

function Get-Clipboard {
    PowerShell -NoProfile -STA -Command { Add-Type -Assembly PresentationCore; [Windows.Clipboard]::GetText() }
}

function Set-Clipboard {
    param(
        [Parameter(ValueFromPipeline = $true)]
        [object[]] $inputObject
    )
    begin {
        $objectsToProcess = @()
    }
    process {
        $objectsToProcess += $inputObject
    }
    end {
        $objectsToProcess | PowerShell -NoProfile -STA -Command {
            Add-Type -Assembly PresentationCore
            $clipText = ($input | Out-String -Stream) -join "`r`n" 
            [Windows.Clipboard]::SetText($clipText)
        }
    }
}

function Get-Uptime {
    param(
        [string] $computer
    )
	
    $uptime_template = "System ({0}) has been online since : {1} days {2} hours {3} minutes {4} seconds"
    $lastboottime = (Get-WmiObject -Class Win32_OperatingSystem -computername $computer).LastBootUpTime
    $sysuptime = (Get-Date) - [System.Management.ManagementDateTimeconverter]::ToDateTime($lastboottime)
	
    $uptime = $uptime_template -f $computer, $sysuptime.days, $sysuptime.hours, $sysuptime.minutes, $sysuptime.seconds
	
    return $uptime
}

function Get-CpuLoad {
    param(
        [string] $ComputerName = $ENV:COMPUTERNAME,
        [int]    $Refresh = 5
    )

    $query = "select * from Win32_PerfRawData_PerfProc_Process"
    $filter = " where Name = `"{0}`""

    Clear-Host

    while (1) {
                
        $system_utilization = @()
        $all_running_processes = Get-WmiObject -Query $query -ComputerName $ComputerName
        
        Start-Sleep -Milliseconds 500
        
        foreach ( $process in $all_running_processes ) {
            $process_utlization_delta = Get-WmiObject -Query ($query + $Filter -f $process.Name) -ComputerName $ComputerName
            $cpu_utilization = [math]::Round((($process_utlization_delta.PercentProcessorTime - $process.PercentProcessorTime) / ($process_utlization_delta.Timestamp_Sys100NS - $process.Timestamp_Sys100NS)) * 100, 2)
        
            $system_utilization += (New-Object psobject -Property @{
                    ComputerName  = $ComputerName
                    ProcessName   = $process.Name
                    PID           = $process.IDProcess
                    ThreadCount   = $process.ThreadCount
                    PercentageCPU = $cpu_utilization
                    WorkingSetKB  = $process.WorkingSetPrivate / 1kb
                })
        }
        Clear-Host
        $system_utilization | Sort-Object -Property PercentageCPU -Descending | Select -First 10 | Format-Table -AutoSize
        Start-Sleep -Seconds $Refresh
    }
}

function Get-ScheduledTasks {
    param(
        [string] $ComputerName
    )

    $tasks = @()
	
    $tasks_com_connector = New-Object -ComObject("Schedule.Service")
    $tasks_com_connector.Connect($ComputerName)
	
    foreach ( $task in ($tasks_com_connector.GetFolder("\").GetTasks(0) | Select Name, LastRunTime, LastTaskResult, NextRunTime, XML )) {
	
        $xml = [xml] ( $task.XML )
		
        $tasks += (New-Object PSObject -Property @{
                HostName    = $ComputerName
                Name        = $task.Name
                LastRunTime = $task.LastRunTime
                LastResult  = $task.LastTaskResult
                NextRunTime = $task.NextRunTime
                Author      = $xml.Task.RegistrationInfo.Author
                RunAsUser   = $xml.Task.Principals.Principal.UserId
                TaskToRun   = $xml.Task.Actions.Exec.Command
            })
    }
	
    return $tasks
}

function Import-PfxCertificate {    
    param(
        [String] $certPath,
        [String] $certRootStore = "LocalMachine",
        [String] $certStore = "My",
        [object] $pfxPass = $null
    )
    
    $pfx = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2    
   
    if ($pfxPass -eq $null) {
        $pfxPass = read-host "Enter the pfx password" -assecurestring
    }
   
    $pfx.import($certPath, $pfxPass, "Exportable,PersistKeySet")    
   
    $store = new-object System.Security.Cryptography.X509Certificates.X509Store($certStore, $certRootStore)    
    $store.open("MaxAllowed")    
    $store.add($pfx)    
    $store.close()    
} 
 
function Remove-Certificate {
    param(
        [String] $subject,
        [String] $certRootStore = "LocalMachine",
        [String] $certStore = "My"
    )

    $cert = Get-ChildItem -path cert:\$certRootStore\$certStore | Where-Object { $_.Subject.ToLower().Contains($subject) }
    $store = new-object System.Security.Cryptography.X509Certificates.X509Store($certStore, $certRootStore)
	
    $store.Open("ReadWrite")
    $store.Remove($cert)
    $store.Close()
	
}

function Export-Certificate {
    param(
        [string] $subject,
        [string] $certStore = "My",
        [string] $certRootStore = "LocalMachine",
        [string] $file,
        [object] $pfxPass 
    )
	
    $cert = Get-ChildItem -path cert:\$certRootStore\$certStore | Where-Object { $_.Subject.ToLower().Contains($subject) }
    $type = [System.Security.Cryptography.X509Certificates.X509ContentType]::pfx
 
    if ($pfxPass -eq $null) {
        $pfxPass = Read-Host "Enter the pfx password" -assecurestring
    }
	
    $bytes = $cert.export($type, $pfxPass)
    [System.IO.File]::WriteAllBytes($file , $bytes)
}

function pause {
    #From http://www.microsoft.com/technet/scriptcenter/resources/pstips/jan08/pstip0118.mspx
    Write-Output "Press any key to exit..."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Get-PerformanceCounters {
    param (
        [String[]] $counters = @("\processor(_total)\% processor time", "\physicaldisk(_total)\% disk time", "\memory\% committed bytes in use", "\physicaldisk(_total)\current disk queue length"),
        [String[]] $computers,
        [int] $samples = 10,
        [int] $interval = 10		
    )
	
    Get-Counter $counters -ComputerName $computers -MaxSamples $samples -SampleInterval $interval |
        ForEach-Object { $t = $_.TimeStamp; $_.CounterSamples } | 
        Select-Object @{Name = "Time"; Expression = {$t}}, Path, CookedValue 
}

function Get-PSSecurePassword {
    param (
        [String] $password
    )
    return ConvertFrom-SecureString ( ConvertTo-SecureString $password -AsPlainText -Force)
}

function Get-PlainTextPassword {
    param (
        [String] $password,
        [byte[]] $key
    )

    if ($key) {
        $secure_string = ConvertTo-SecureString $password -Key $key
    }
    else {
        $secure_string = ConvertTo-SecureString $password
    }
	
    return ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto( [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure_string) ) )
}

function Get-NewPasswords {
    param (
        [int] $number = 10,
        [int] $length = 16,
        [switch] $hash
    )

    [void][Reflection.Assembly]::LoadWithPartialName("System.Web")
    $algorithm = 'sha256'

    $passwords = @()
    for ( $i = 0; $i -lt $number; $i++) {
        $pass = [System.Web.Security.Membership]::GeneratePassword($length, 1)
        if ( $hash ) {
            $hasher = [System.Security.Cryptography.HashAlgorithm]::create($algorithm)
            $computeHash = $hasher.ComputeHash( [Text.Encoding]::UTF8.GetBytes( $pass.ToString() ) )
            $pass = ( ([system.bitconverter]::tostring($computeHash)).Replace("-", "") )
        }
        $passwords += $pass
    }
    return $passwords
}

function Set-SQLAlias {
    param( 
        [string] $instance, 
        [int]    $port, 
        [string] $alias
    )
	
    [reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
    $objComputer = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer "."

    $newalias = New-Object ("Microsoft.SqlServer.Management.Smo.Wmi.ServerAlias")
    $newalias.Parent = $objComputer
    $newalias.Name = $alias
    $newalias.ServerName = $instance
    $newalias.ConnectionString = $port
    $newalias.ProtocolName = 'tcp' 
    $newalias.Create()
}

function Get-WindowsUpdateConfig {
    $AutoUpdateNotificationLevels = @{0 = "Not configured"; 1 = "Disabled" ; 2 = "Notify before download"; 3 = "Notify before installation"; 4 = "Scheduled installation"}
    $AutoUpdateDays = @{0 = "Every Day"; 1 = "Every Sunday"; 2 = "Every Monday"; 3 = "Every Tuesday"; 4 = "Every Wednesday"; 5 = "Every Thursday"; 6 = "Every Friday"; 7 = "EverySaturday"}
	
    $AUSettings = (New-Object -com "Microsoft.Update.AutoUpdate").Settings

    $AUObj = New-Object -TypeName PSObject -Property @{
        NotificationLevel  = $AutoUpdateNotificationLevels[$AUSettings.NotificationLevel]
        UpdateDays         = $AutoUpdateDays[$AUSettings.ScheduledInstallationDay]
        UpdateHour         = $AUSettings.ScheduledInstallationTime 
        RecommendedUpdates = $(IF ($AUSettings.IncludeRecommendedUpdates) {"Included."}  else {"Excluded."})
    }
    return $AuObj
} 

function Get-LocalAdmins {
    param ( [string] $computer )
    $adsi = [ADSI]("WinNT://" + $computer + ",computer") 
    $Group = $adsi.psbase.children.find("Administrators") 
    $members = $Group.psbase.invoke("Members") | % {$_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)} 
	
    return $members
}

function Get-LocalGroup {
    param ( [string] $computer, [string] $Group )
    $adsi = [ADSI]("WinNT://" + $computer + ",computer") 
    $adGroup = $adsi.psbase.children.find($group) 
    $members = $adGroup.psbase.invoke("Members") | % {$_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)} 
	
    return $members
}

function Add-ToLocalGroup {
    param ( [string] $computer, [string] $LocalGroup, [string] $DomainGroup )
    $aslocalGroup = [ADSI]"WinNT://$computer/$LocalGroup,group"
    $aslocalGroup.Add("WinNT://$domain_controller/$DomainGroup,group")
}

function Add-LocalAdmins {
    param ( [string] $computer, [string] $Group )
    $localGroup = [ADSI]"WinNT://$computer/Administrators,group"
    $localGroup.Add("WinNT://$domain_controller/$Group,group")
}

function Convert-ObjectToHash {
    param ( 
        [Object] $obj
    )
	
    $ht = @{}
    $Keys = $obj | Get-Member -MemberType NoteProperty | Select -Expand Name

    foreach ( $key in $Keys ) { 
        if ( $obj.$key -is [System.Array] ) { 
            $value = [String]::Join(" | ", $obj.$key )
        }
        else {
            $value = $obj.$key
        }
        $ht.Add( $Key, $Value )
    }

    return $ht
}

function Get-RunningServices {
    param( [string] $computer )
    Get-WmiObject Win32_Service -computer $Computer | Where-Object { $_.State -eq "Running" } | Select-Object Name, PathName, Id, StartMode  
}

function Get-Certs {
    Get-ChildItem -path Cert:\LocalMachine\My | Select-Object FriendlyName, Issuer, NotAfter, HasPrivateKey | Sort-Object NotAfter
}
	
function Get-DirHash {
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $True)]
        [ValidateScript( {Test-Path $_})]
        [string] $Directory = $PWD.Path 
    )
    begin {
        $ErrorActionPreference = "silentlycontinue"
        $hashes = @()
    }
    process {
        $hashes = Get-ChildItem -Recurse -Path $Directory | 
            Where-Object { $_.PsIsContainer -eq $false } | 
            Select-Object Name, DirectoryName, @{Name = "SHA1 Hash"; Expression = {Get-Hash1 $_.FullName -algorithm "sha1"}}
    }
    end {
        return $hashes 
    }
}

function Get-LoadedModules {
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $True)]
        [string] $proc
    )
    begin {
        $modules = @()		
    }
    process {
        $procInfo = Get-Process | Where-Object { $_.Name.ToLower() -eq $proc.ToLower() }
        $modules = $procInfo | Select-Object Name, Modules
    }
    end {
        return $modules 
    }
}

function Get-IPAddress {
    param ( [string] $name )
    return ( try { [System.Net.Dns]::GetHostAddresses($name) | Select-Object -Expand IPAddressToString } catch {} )
}

function Get-Base64Encoded {
    param( [string] $strEncode )
    [convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($strEncode))
}

function Get-Base64Decoded {
    param( [string] $strDecode )
    [Text.Encoding]::ASCII.GetString([convert]::FromBase64String($strDecode))
}

function Ping-Multiple {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $ComputerName
    )
    begin {
        $replies = @()
        $timeout = 1000
        $ping = New-Object System.Net.NetworkInformation.Ping 
    }
    process {
        trap { continue }
			
        $reply = $ping.Send($ComputerName , $timeout)
        $replies += (New-Object PSObject -Property @{
                ComputerName = $ComputerName	
                Address      = $reply.Address
                Time         = $reply.RoundtripTime
                Status       = $reply.Status
            })
    }
    end {
        return $replies
    }
}

function Read-RegistryHive {
    param(
        [string[]] $servers,
        [string] $key,
        [string] $rootHive = "LocalMachine"
    )
	
    $regPairs = @()
    foreach ( $server in $servers ) {
        if ( Test-Connection -Computername $server -Count 1 ) {
            $hive = [Microsoft.Win32.RegistryHive]::$rootHive
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($hive, $server )
            $regKey = $reg.OpenSubKey($key)
            foreach ( $regValue in $regKey.GetValueNames() ) { 
                $regPairs += (New-Object PSObject -Property @{
                        Server = $server
                        Key    = $key + "\" + $regValue
                        Value  = $regKey.GetValue($_.ToString())
                    })
            }
            foreach ( $regSubKey in $regKey.GetSubKeyNames() ) {
                $regPairs += Read-RegistryHive -Servers $server -Key "$key\$regSubKey"
            }
        } 
        else {
            Write-Error -Message ("Could not ping {0} . . ." -f $server)
        }
	
    }
    return $regPairs
}

function log {
    param ( [string] $txt, [string] $log ) 
    Out-File -FilePath $log -Append -Encoding ASCII -InputObject ("[{0}] - {1}" -f $(Get-Date).ToString(), $txt )
}

function Get-Hash1 {
    param(
        [string] $file = $(throw 'a filename is required'),
        [string] $algorithm = 'sha256'
    )

    $fileStream = [system.io.file]::openread($file)
    $hasher = [System.Security.Cryptography.HashAlgorithm]::create($algorithm)
    $hash = $hasher.ComputeHash($fileStream)
    $fileStream.Close()
	
    return ( ([system.bitconverter]::tostring($hash)).Replace("-", "") )
}

function Get-FileVersion {
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $True)]
        [ValidateScript( {Test-Path $_})]
        [string] $FilePath
    )
    begin {
        $info = @()
    }
    process {
        $info += [system.diagnostics.fileversioninfo]::GetVersionInfo($FilePath)
    }
    end {
        return $info
    }
}

function Query-DatabaseTable {
    param (
        [string] $server, 
        [string] $dbs, 
        [string] $sql
    )
	
    $Columns = @()
    $con = "server={0};Integrated Security=true;Initial Catalog={1}" -f $server, $dbs
	
    $ds = New-Object "System.Data.DataSet" "DataSet"
    $da = New-Object "System.Data.SqlClient.SqlDataAdapter" ($con)
	
    $da.SelectCommand.CommandText = $sql 
    $da.SelectCommand.Connection = $con
	
    $da.Fill($ds) | out-null
    $ds.Tables[0].Columns | Select-Object ColumnName | ForEach-Object { $Columns += $_.ColumnName }
    $res = $ds.Tables[0].Rows  | Select-Object $Columns
	
    $ds.Clear()
    $da.Dispose()
    $ds.Dispose()

    return $res
}
function Is-64Bit {   
    return ( [IntPtr]::Size -eq 8 ) 
}