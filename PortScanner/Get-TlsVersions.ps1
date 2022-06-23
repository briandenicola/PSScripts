<#
.SYNOPSIS
The script will test a HostName for supported TLS Alogrithms and provide TLS details

.DESCRIPTION
Version - 1.0.0
The script will test a HostName for supported TLS Alogrithms and provide TLS details

.EXAMPLE
.\Get-TlsVersions.ps1 HostName www.google.com 

.EXAMPLE
.\Get-TlsVersions.ps1 HostName www.google.com -Port 8443

.EXAMPLE
.\Get-TlsVersions.ps1 HostName www.google.com -TlsVersion Tls13

.EXAMPLE
.\Get-TlsVersions.ps1 HostName www.google.com -TlsVersion Tls13 -Simple

.PARAMETER HostName
Name or IP Address of URL to test

.PARAMETER Port
An array of ports to test. Default is 443

.PARAMETER TLSVersion
Tls Versions to check. Default is all supported TLS Versions configured on local machine

.PARAMETER Simple
Simplified Ouput. Will output if the TlsVesion is supported or not

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $HostName,

    [Int]    $Port = 443,
    [Switch]   $Simple,

    [ValidateSet(
        [System.Security.Authentication.SslProtocols]::Tls,
        [System.Security.Authentication.SslProtocols]::Tls11,
        [System.Security.Authentication.SslProtocols]::Tls12, 
        [System.Security.Authentication.SslProtocols]::Tls13)
    ]
    [System.Security.Authentication.SslProtocols]  $TLSVersion
)

function New-TlsObject ()
{
    param (
        [bool] $Supported
    )

    $properties = [ordered]@{
        Protocol                = $protocol
        CipherSuite             = [string]::Empty
        CipherAlgorithm         = [string]::Empty
        HashAlgorithm           = [string]::Empty
        KeyExchangeAlgorithm    = [string]::Empty
        CertificateThumbprint   = [string]::Empty
        CertificateSubject      = [string]::Empty
        CertificateIssuer       = [string]::Empty
        CertificateExpiration   = [string]::Empty
        Supported               = $Supported
    }

    return New-Object psobject -Property $properties
}

function Get-AllSupportedTlsProtocols {
    return(
        [System.Security.Authentication.SslProtocols] | 
            Get-Member -static -MemberType Property | 
            Where-Object { $_.Name -notin @("Default", "None") } | 
            Select-Object -ExpandProperty Name
    )
}

function Get-KeyExchangeAlgorithm {
    param( 
        [string] $TlsStreamValue
    )

    Write-Verbose -Message ("Received raw Get-KeyExchangeAlgorithm value {0} . . . ." -f $TlsStreamValue)

    switch ($TlsStreamValue) {
        {$_ -match "43522|44550"} { return "DiffieHellman" }
        0     { return "None" }
        41984 { return "RsaKeyX" }
        9216  { return "RsaSign" }
        default { return $TlsStreamValue }
    }
}

if( -not (Test-Connection -TargetName $HostName -TcpPort $Port -TimeoutSeconds 1 -Quiet) ) {
    Write-Error -Message ("Could not connect to {0}:{1}" -f $HostName, $Port) 
    exit 
}
 
$SupportedProtocols = @()

if( $null -eq $TLSVersion ) {
    $protocols = Get-AllSupportedTlsProtocols
} else {
    $protocols = @($TLSVersion)
}

foreach ( $protocol in $protocols ) 
{
    Write-Verbose -Message ("Testing {0} on {1}:{2} . . . ." -f $protocol, $HostName, $Port)

    $TcpClient = New-Object Net.Sockets.TcpClient
    $TcpClient.ReceiveTimeout = 1500
    $TcpClient.SendTimeout = 1500

    $TcpClient.Connect($HostName, $Port)
    $TlsStream = New-Object Net.Security.SslStream $TcpClient.GetStream()
    $TlsStream.ReadTimeout = 1500
    $TlsStream.WriteTimeout = 1500 

    try 
    {
        $TlsStream.AuthenticateAsClient($HostName, $null, $protocol, $false)
        Write-Verbose -Message ("Protocol {0} is supported on {1}:{2} . . . ." -f $protocol, $HostName, $Port)
        
        $tls = New-TlsObject -Supported $true
        $tls.Protocol                = $TlsStream.SslProtocol
        $tls.CipherSuite             = $TlsStream.NegotiatedCipherSuite
        $tls.CipherAlgorithm         = $TlsStream.CipherAlgorithm
        $tls.HashAlgorithm           = $TlsStream.HashAlgorithm
        $tls.KeyExchangeAlgorithm    = Get-KeyExchangeAlgorithm -TlsStreamValue $TlsStream.KeyExchangeAlgorithm
        $tls.CertificateThumbprint   = $TlsStream.RemoteCertificate.Thumbprint
        $tls.CertificateSubject      = $TlsStream.RemoteCertificate.Subject
        $tls.CertificateIssuer       = $TlsStream.RemoteCertificate.Issuer
        $tls.CertificateExpiration   = $TlsStream.RemoteCertificate.NotAfter
        $SupportedProtocols += $tls

    }
    catch 
    {
        Write-Verbose -Message ("Protocol {0} not supported on {1}:{2} . . . ." -f $protocol, $HostName, $Port)
        $SupportedProtocols += New-TlsObject -Supported $false
    }
    finally 
    {
        $TcpClient.Dispose()
        $TlsStream.Dispose()
    }
}

if($Simple) {
    return $SupportedProtocols | Select-Object Protocol, Supported 
}
return $SupportedProtocols