Set-Variable -Name SChannelProtocolRoot           -Value "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\{0}"                                -Option Constant
Set-Variable -Name SChannelClientProtocolKey      -Value "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\{0}\Client"                          -Option Constant
Set-Variable -Name SChannelServerProtocolKey      -Value "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\{0}\Server"                          -Option Constant
Set-Variable -Name SChannelMPUHProtocolKey        -Value "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\Multi-Protocol Unified Hello\Server" -Option Constant
Set-Variable -Name EnabledItemPropertyValue       -Value "Enabled"                                                                                                         -Option Constant
Set-Variable -Name DisabledByDefaultPropertyValue -Value "DisabledByDefault"                                                                                               -Option Constant

$TLS_Lookup = New-Object PSObject -Property @{
    PCT   = "PCT 1.0"
    SSL2  = "SSL 2.0"
    SSL3  = "SSL 3.0"
    TLS1  = "TLS 1.0"
    TLS11 = "TLS 1.1"
    TLS12 = "TLS 1.2"
}

$DWORD = New-Object PSObject -Property @{
    ALL_ZEROS = "00000000"
    ALL_ONES  = "4294967295"
    ONE       = "00000001"
}

$returnValue = @{
    PCT   = $false
    SSL2  = $false
    SSL3  = $false
    TLS1  = $false
    TLS11 = $false
    TLS12 = $false
}

$TLS_Lookup.psobject.Properties | Select -ExpandProperty Name

foreach( $protocol in ($TLS_Lookup.psobject.Properties | Select -ExpandProperty Name) ) {
    if( (Test-Path -Path ($SChannelProtocolRoot -f $TLS_Lookup.$protocol) ) ) {
        $client_bydefault = Get-ItemProperty -Path ($SChannelClientProtocolKey -f $TLS_Lookup.$protocol) -Name $DisabledByDefaultPropertyValue  | Select -ExpandProperty $DisabledByDefaultPropertyValue
        $server_enabled   = Get-ItemProperty -Path ($SChannelServerProtocolKey -f $TLS_Lookup.$protocol) -Name $EnabledItemPropertyValue        | Select -ExpandProperty $EnabledItemPropertyValue
        $server_bydefault = Get-ItemProperty -Path ($SChannelServerProtocolKey -f $TLS_Lookup.$protocol) -Name $DisabledByDefaultPropertyValue  | Select -ExpandProperty $DisabledByDefaultPropertyValue

        if( $client_bydefault -eq $DWORD.ALL_ZEROS -and $server_enabled -eq $DWORD.ALL_ONES -and $server_bydefault -eq $DWORD.ALL_ZEROS ) {
            $returnValue.$protocol = $true
        }
    }
}

$returnValue