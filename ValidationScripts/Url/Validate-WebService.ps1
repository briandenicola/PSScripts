#require -version 4.0
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string] $cfg,
    [switch] $SaveReply
)

. (Join-path -Path $ENV:SCRIPTS_HOME -ChildPath "Libraries\Standard_Functions.ps1")
. (Join-path -Path $PWD.Path         -ChildPath "Modules\Helper-Functions.ps1")

Set-Variable -Name hostfile -Value (Join-Path $ENV:SYSTEMROOT "System32\drivers\etc\hosts") -Option Constant

function RemoveFrom-HostFile {
    param(
        [string] $url
    )

    ((Get-Content $hostfile) -notmatch "^$") -notmatch $url | Out-File -Encoding Ascii $hostfile	
}

function AddTo-HostFile {
    param(
        [string] $url,
        [string] $ip
    )
	
    "`n{0}`t{1}" -f $ip, $url | Out-File -Encoding Ascii -Append -FilePath $hostfile
}

$url_to_validate = Get-Json -Config $cfg

foreach ( $url in $url_to_validate ) {
    $hostname = Select-String -InputObject $url -Pattern 'http?://([\w-]+\.+[\w-]+\.[\w-]+).*' | 
        Select-Object -Expand Matches | 
        Select-Object -ExpandProperty Groups |
        Select-Object -ExpandProperty Value |
        Select-Object -Last 1

    foreach ( $server in ($url.servers | Select-Object -Expand server) ) {
        
        $ip = Resolve-DnsName $server | Select-Object -ExpandProperty IpAddress
        AddTo-HostFile -url $hostname -ip $ip
        Clear-DNSClientCache 

        $results = Get-WebserviceRequest -url $url.url -Server $server -WebService $url.WebService 
        if ( $saveReply ) { Save-Reply -Url $url -Text $results -Server $server }
        Validate-Results -Rules $url.Rules -Results $results 

        RemoveFrom-HostFile -url $hostname
    }
}