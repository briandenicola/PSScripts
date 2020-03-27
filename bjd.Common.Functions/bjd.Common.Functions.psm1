$pshistory_file = Join-Path -Path $ENV:USERPROFILE -ChildPath "AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt"

function Get-IsAdminConsole {
    $role = [Security.Principal.WindowsBuiltInRole] "Administrator"
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole($role) ) {
        return $false
    }
    return $true 
}
function Get-OSType {
    return $PSVersionTable.Platform
}

function Get-RunningServicesCommandline { 

    if ( (Get-OSType) -ne "Win32NT" ) {
        throw "Unsupported Operating system for this function"
        return -1 
    }

    if ( -not (Get-IsAdminConsole) ) {
        throw "Script must run in an Administrator console. Please restart console with Runas Administrator"
        return -1 
    }
  
    Set-Variable -Name Query -Value "SELECT Name,DisplayName,ProcessId,State FROM Win32_Service WHERE State = 'Running'" -Option Constant

    $processes = Get-Process -IncludeUserName | Group-Object -Property Id -AsHashTable -AsString 
    $all_services = Get-CimInstance -Query $Query

    $services = foreach ( $service in $all_services ) {
        
        $key = $service.ProcessId.ToString()
        $process = $processes[$key]

        New-Object PSObject -Property @{
            Name        = $service.Name
            DisplayName = $service.DisplayName
            User        = $process.UserName
            CommandLine = $process.Path
            PID         = $process.Id
        }   
    }

    return $services
}

function Resolve-JwtToken {
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

function Remove-3DObjects {
    $regRoot = "HKLM:\SOFTWARE"
    $regChildPaths = @(
        'WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}',
        'Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}'
    )

    foreach( $regChildPath in $regChildPaths ) {
        $regPath = Join-Path -Path $regRoot -ChildPath $regChildPath
        if( Test-Path -Path $regPath ) {
            Remove-Item -Path $regPath -Confirm:$false -Force
        }
    }
}

function Update-FileTimeStamp {
    param(
        [Parameter(Mandatory = $true)]
        [string] $FileName
    )

    if( Test-Path -Path $FileName ) {
        $file= Get-Item -Path $FileName
        $file.LastWriteTime = (Get-Date)
    }
    else {
        Add-Content -Path $FileName -Value ([string]::Empty)
    }
}

function Get-ExecutablePath {
    param(
        [string] $processName
    )

    #Get-Command -CommandType Application -Name $processName | Select -ExpandProperty Source
    $directories = (Get-EnvironmentVariable -Key Path) -split ";"

    if( $processName -inotmatch "\.exe" ) {
        $processName = "{0}.exe" -f $processName
    }

    foreach( $directory in $directories ) {
        $processPath = Get-ChildItem -Path $directory -Filter $processName -ErrorAction SilentlyContinue -File 

        if(-not [string]::IsNullOrEmpty($processPath)) {
            return $processPath.FullName
        }
    }

    return $null
}

function Get-PSHistory {
    param(
        [int] $last = 4096
    )
   
    if( -not( Test-Path -Path $pshistory_file ) ) {
        Write-Errror -Message ("History file not fount - {0}" -f $history_file)
        return $false
    }

    $count = 1
    $lines = [System.Object[]]::new($last+1)

    foreach( $line in (Get-Content -Tail $last -Path $pshistory_file) ) {
        $lines[$count] = New-Object psobject -Property @{"Id" = $count; "CommandLine" = $line} 
        $count++
    }
     
    return $lines
}

function Clear-PSHistory {
    param(
        [switch] $Force
    )

    if( -not( Test-Path -Path $pshistory_file ) ) {
        Write-Errror -Message ("History file not fount - {0}" -f $history_file)
        return $false
    }

    Clear-History 
    Out-File -FilePath $pshistory_file -InputObject $Nul -Confirm:(!$Force)

}

function Get-EncodedHtml {
    param(
        [string] $html
    )

    Add-Type -AssemblyName System.Web
    return ( [System.Web.HttpUtility]::HtmlEncode($html)  )
}

function Get-DecodedHtml {
    param(
        [string] $html
    )

    Add-Type -AssemblyName System.Web
    return ( [System.Web.HttpUtility]::HtmlDecode($html)  )
}

function New-Uuid {
    return (New-Guid).ToString('N').Substring(20)
}

function Get-EmptyDirectories 
{
    param(
        [ValidateScript({Test-Path $_})]
        [Parameter(Mandatory = $true)]
        [string] $Path
    )
    
    return (Get-ChildItem -Path $path -Recurse -Directory | Where-Object { $_.GetFileSystemInfos().Count -eq 0 } | Select-Object -Expand FullName)
}

function New-Salt 
{
    $saltLengthLimit = 32
    $salt = [System.Byte[]]::new($saltLengthLimit)
    $random = New-Object "System.Security.Cryptography.RNGCryptoServiceProvider"
    $random.GetNonZeroBytes($salt)
    return [System.Convert]::ToBase64String($salt)
}

function New-AesKey 
{
    $aes = New-Object "System.Security.Cryptography.AesManaged"
    $aes.KeySize = 256
    1 .. ( Get-Random -Minimum 500 -Maximum 1500) | ForEach-Object { $aes.GenerateKey() }
    return( [System.Convert]::ToBase64String($aes.Key) )
}

#https://www.powershellgallery.com/packages/psbbix/0.1.6/Content/epoch-time-convert.ps1
function Convert-SecondsFromEpochToDate
{
    param(
        [int64] $totalSeconds
    )

    $epoch = Get-Date -Date "1/1/1970 12:00:00 AM"
    return $(Get-Date -date $epoch).AddSeconds($totalSeconds).ToLocalTime()
}

function Get-PowerShellVersion 
{
    return $Host.Version
}

function Start-WindowsPowerShellCmdlet
{
    param(
        [string] $ArgumentList
    )
    
    $pwsh = New-Object System.Diagnostics.ProcessStartInfo
    $pwsh.FileName = "powershell.exe"
    $pwsh.RedirectStandardError = $true
    $pwsh.RedirectStandardOutput = $true
    $pwsh.UseShellExecute = $false
    $pwsh.Arguments = $ArgumentList

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pwsh
    $p.Start() | Out-Null
    $p.WaitForExit()

    return $p
}

function Start-ElevatedConsole 
{
    $pwsh = "pwsh.exe"
    Start-process -FilePath $pwsh -Verb RunAs -WorkingDirectory $PWD.Path 
}

function Get-StandardOutput 
{
    param(
        [System.Diagnostics.Process] $process
    )

    return $process.StandardOutput.ReadToEnd()
}

function Get-DnsServer 
{
    [CmdletBinding()]
    param (
        [Parameter(DontShow)]
        [string] $Alias = "Ethernet"
    )

    Set-Variable -Name os      -Value $ENV:OS
    Set-Variable -Name command -Value "Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object InterfaceAlias -eq  $Alias  | Select-Object -ExpandProperty ServerAddresses" -Option Constant

    if( $os -eq "Windows_NT") {
        if( Get-PowerShellVersion -ge [Version]::New(6,0,0) ) {
            $process = Start-WindowsPowerShellCmdlet -ArgumentList "-Command &{ $command }" 
            $dnsServers = Get-StandardOutput -Process $process
        }
        else {
            $dnsServers = Invoke-Expression -Command $command
        }
    }
    else {
        Write-Errror -Message ("Get-DnsClientServerAddress does not work on {0}" -f $os)
        return $false
    }

    return $dnsServers

}

function Set-DnsServer 
{
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

    $dns_addresses = Get-DnsServer -Alias $Alias
    Write-Verbose -Message ("The local DNS Server has been set to {0} . . . " -f $dns_addresses)
}

function Get-EnvironmentVariable
{
    [cmdletbinding(DefaultParameterSetName='ALL')]
    param ( 
        [Parameter(ParameterSetName='ID', Mandatory = $true)]
        [string] $Key,

        [Parameter(ParameterSetName='ALL')]
        [switch] $ALL
    )

    if($PSCmdlet.ParameterSetName -eq "ALL" -or $all) {
        return [Environment]::GetEnvironmentVariables()
    }
    else {
        return [Environment]::GetEnvironmentVariable($key)
    }
}

function Set-EnvironmentVariable
{
    param ( 
        [string] $Key,
        [string] $Value,
        [ValidateSet("User","Machine")]
        [string] $Scope = "User"
    )

    [Environment]::SetEnvironmentVariable( $Key, $Value, $Scope )
}

function Update-PathVariable 
{
    param(	
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = "Refresh")]
        [switch] $Refresh,

        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = "Update")]
        [string] $Path,
        
        [Parameter(Position = 1, Mandatory = $false, ParameterSetName = "Update")]
        [ValidateSet("User", "Machine")] 
        [string] $Target = "User",

        [Parameter(Position = 2, Mandatory = $false, ParameterSetName = "Update")]
        [switch] $Remove,

        [Parameter(Position = 3, Mandatory = $false, ParameterSetName = "Update")]
        [switch] $Force
    )

    if( $PsCmdlet.ParameterSetName -eq "Update" ) {
        if( $Force -or (Test-Path -Path $Path -PathType Container)) {
            $current_path = [Environment]::GetEnvironmentVariable( "Path", $Target )
	        Write-Verbose -Message ("Current {0} Path Value: {1}" -f $Target, $current_path )
	
            if($Remove) {
                $current_path = $current_path -split ";"  | Where-Object { $_ -ine $Path } | Select-Object -Unique
            }
            else {
                $current_path = ($current_path -split ";") + $Path | Where-Object { $_ -ine [string]::Empty } | Select-Object -Unique
            }

            $new_path = [string]::Join( ";", $current_path)
    
            Write-Verbose -Message ("New {0} Path Value: {1}" -f $Target, $new_path)
            [Environment]::SetEnvironmentVariable( "Path", $new_path, $Target )
        }
        else {
            Write-Error -Message ("Path Value: {0} could not be found. Exiting" -f $Path )
            return 
        }
    }

    $updated_path = "Machine", "User" | ForEach-Object { [Environment]::GetEnvironmentVariable( "Path", $_ ) + ";" }
    Write-Verbose -Message ("Refreshing Complete Path Value: {0}" -f $updated_path)
    $ENV:Path = $updated_path
    return
}

function Set-PublicKey 
{
    param ( 
        [string] $FilePath 
    )

    $ENV:PUBKEY = $FilePath
    Set-EnvironmentVariable -key "PUBKEY" -Value $FilePath -Scope "User"
}

function Get-PublicKey 
{
    param(
        [switch] $CopyToClipboard 
    )

    $pub_key = Get-Content -Path $ENV:PUBKEY 
    
    if ( $CopyToClipboard ) { $pub_key | Set-Clipboard }
    return $pub_key
}

function Get-MyPublicIPAddress 
{
    param( 
        [switch] $UsingDNS,
        [switch] $CopyToClipboard 
    )

    if($UsingDNS) {
        $ip = Resolve-DnsName -Name o-o.myaddr.l.google.com -Type TXT -NoHostsFile -DnsOnly -Server ns1.google.com | Select-Object -ExpandProperty Strings 
    }
    else {
        $reply = Invoke-WebRequest -UseBasicParsing -Uri http://checkip.dyndns.org | Select-Object -ExpandProperty Content 
        $reply -imatch "([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})" | Out-Null 
        $ip = $Matches[1]
    }

    if ( $CopyToClipboard ) { $ip | Set-Clipboard }
    return $ip
}

function Add-TrustedRemotingEndpoint 
{
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

function Get-TrustedRemotingEndpoint 
{    
    $WSMANPath = "WSMAN:\LocalHost\Client\TrustedHosts"
    $trustedHosts = Get-Item -Path $WSMANPath | Select-Object -Expand Value
    return $trustedHosts.Split(",")
}

function New-PSCredentials 
{
    param(
        [string] $UserName,
        [string] $Password
    )

    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    return ( New-Object System.Management.Automation.PSCredential ($UserName, $SecurePassword) )
}

function Get-ServerAccess 
{
    param(
        [string] $computer
    )

    Get-WmiObject -Query "Select Name from Win32_ComputerSystem" -ComputerName $computer -ErrorAction SilentlyContinue | Out-Null
    return $? 
}

function New-PSWindow 
{ 
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

function Get-PSSecurePassword 
{
    param (
        [String] $password
    )
    return ConvertFrom-SecureString ( ConvertTo-SecureString $password -AsPlainText -Force )
}

function Get-PlainTextPassword 
{
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

function Get-Base64Encoded 
{
    param( [string] $strEncode )
    return ( [convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($strEncode)) )
}

function Get-Base64Decoded 
{
    param( [string] $strDecode )
    return ( [Text.Encoding]::ASCII.GetString([convert]::FromBase64String($strDecode)) )
}

#Export-ModuleMember -Function * 