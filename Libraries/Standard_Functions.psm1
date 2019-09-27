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
    
    return (Get-ChildItem -Path $path -Recurse | Where-Object {$_.PSIsContainer -eq $True -and $_.GetFileSystemInfos().Count -eq 0 } | Select-Object -Expand FullName)
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
        [ValidateScript( {Test-Path $_})]
        [string] $Path,
        
        [Parameter(Position = 1, Mandatory = $false, ParameterSetName = "Update")]
        [ValidateSet("User", "Machine")] 
        [string] $Target = "User" 
    )

    if( $PSBoundParameters.ContainsKey('Path') ) {
        $current_path = [Environment]::GetEnvironmentVariable( "Path", $Target )
	    Write-Verbose -Message ("[Update-PathVariable] - Current {0} Path Value: {1}" -f $Target, $current_path )
	
        $current_path = $current_path.Split(";") + $Path | Select-Object -Unique
        $new_path = [string]::Join( ";", $current_path)
	
        Write-Verbose -Message ("[Update-PathVariable] - New {0} Path Value: {1}" -f $Target, $new_path)
        [Environment]::SetEnvironmentVariable( "Path", $new_path, $Target )
    }

    $updated_path = "Machine", "User" | ForEach-Object { [Environment]::GetEnvironmentVariable( "Path", $_ ) + ";" }
    Write-Verbose -Message ("[Update-PathVariable] - Refreshing Complete Path Value: {0}" -f $updated_path)
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

    if($DNS) {
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

Export-ModuleMember -Function * 