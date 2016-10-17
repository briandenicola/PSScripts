[CmdletBinding()]
param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [String[]] $ComputerName,
    
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int[]]    $Ports = @(1..65535),

    [Parameter(Mandatory=$false)]
    [ValidateRange(1,10)]
    [int]      $TimeOut = 1,

    [Parameter(Mandatory=$false)]
    [switch]   $IgnoreICMP
 )

Set-Variable -Name opened_ports -Value @()

foreach ( $computer in $ComputerName ) {
    if( $IgnoreICMP -or (Test-Connection -ComputerName $computer -Count 1 -ErrorAction SilentlyContinue) ) { 
        foreach ( $port in $ports ) {
            Write-Verbose -Message ("[{0}] - Test Port {1} - {2} . . ." -f $(Get-Date), $port, $computer)

            try { 
                $socket = New-Object system.Net.Sockets.TcpClient 
                Write-Debug -Message ("[{0}] - Begin Connect on Port {1} - {2} . . ." -f $(Get-Date), $port, $computer)
                $connect = $socket.BeginConnect($computer,$port,$null,$null) 

                Write-Debug -Message ("[{0}] - Async Wait Handle on Port {1} - {2} . . ." -f $(Get-Date), $port, $computer)
                $wait = $connect.AsyncWaitHandle.WaitOne(($TimeOut*1000),$false) 

                if(!$wait) {
                    Write-Debug -Message ("[{0}] - Not Wait Handle on Port {1} - {2} . . ." -f $(Get-Date), $port, $computer)
                    $socket.Close()
                }
                else {
                    Write-Debug -Message ("[{0}] - Success! Closing Handle on Port {1} - {2} . . ." -f $(Get-Date), $port, $computer)
                    $socket.EndConnect($connect)
                    $socket.Close()
                    $opened_ports += (New-Object PSObject -Property @{ ComputerName = $computer; Port = $port })
                }
            }
            catch [System.Net.Sockets.SocketException] {}
            catch [System.Exception] { 
                Write-Error -Message ("Error - {0}" -f $_.Exception )
            }
        }
    }
    else {
        Write-Error -Message ("[{0}] - Error while trying to ping {1}. Will not probe ports on this system." -f $(Get-Date), $computer)
    }
}

$opened_ports