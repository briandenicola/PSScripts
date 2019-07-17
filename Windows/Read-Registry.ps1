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
