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

function Get-DnsServer 
{
    [CmdletBinding()]
    param (
        [Parameter(DontShow)]
        [string] $Alias = "Ethernet"
    )

    return (Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object InterfaceAlias -eq  $Alias  | Select-Object -ExpandProperty ServerAddresses)
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

    $dns_addresses = Get-DnsClientServerAddress | Where-Object { $_.InterfaceAlias -eq $Alias -and $_.AddressFamily -eq 2} | Select-Object -ExpandProperty ServerAddresses
    Write-Verbose -Message ("The local DNS Server has been set to {0} . . . " -f $dns_addresses)
}

function Set-PublicKey 
{
    param ( 
        [string] $FilePath 
    )

    $ENV:PUBKEY = $FilePath
    [Environment]::SetEnvironmentVariable( "PUBKEY", $FilePath, "User" )
}

function Get-PublicKey 
{
    Get-Content -Path $ENV:PUBKEY | Set-Clipboard
}

function Get-MyPublicIPAddress 
{
    param( [switch] $CopyToClipboard )
    $ip = Resolve-DnsName -Name o-o.myaddr.l.google.com -Type TXT -NoHostsFile -DnsOnly -Server ns1.google.com | Select-Object -ExpandProperty Strings 

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
function Update-PathVariable 
{
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