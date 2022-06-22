[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $HostName,
    [Int]    $Port = 443
)
function Get-SSLProtocols {
    return(
        [System.Security.Authentication.SslProtocols] | 
            Get-Member -static -MemberType Property | 
            Where-Object { $_.Name -notin @("Default", "None") } | 
            Select-Object -ExpandProperty Name
    )
}

$SupportedProtocols = @()
foreach ( $protocol in (Get-SSLProtocols) ) {
    Write-Verbose -Message ("Testing {0} on {1}:{2} . . . ." -f $protocol, $HostName, $Port)
    try {
        $TcpClient = New-Object Net.Sockets.TcpClient
        $TcpClient.Connect($HostName, $Port)
        $SslStream = New-Object Net.Security.SslStream $TcpClient.GetStream()
        $SslStream.ReadTimeout = 15000
        $SslStream.WriteTimeout = 15000 
    } 
    catch {
        throw ("Could not connect to {0}:{1}" -f $HostName, $Port)
    }

    try {
        $SslStream.AuthenticateAsClient($HostName, $null, $protocol, $false)
        $SupportedProtocols += New-Object psobject -Property @{
            Protocol      = $SslStream.SslProtocol
            CipherSuite   = $SslStream.NegotiatedCipherSuite
            Supported     = $true
        }
    }
    catch {
        $SupportedProtocols += New-Object psobject -Property @{
            Protocol      = $protocol
            CipherSuite   = "N/A"
            Supported     = $false
        }
    }
    finally {
        $TcpClient.Dispose()
        $SslStream.Dispose()
    }
}

return $SupportedProtocols

