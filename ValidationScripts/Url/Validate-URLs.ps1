[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [string] $cfg,
    [switch] $SaveReply
)

. (Join-path -Path $ENV:SCRIPTS_HOME -ChildPath "Libraries\Standard_Functions.ps1")
. (Join-path -Path $PWD.Path         -ChildPath "Modules\Helper-Functions.ps1")

$url_to_validate = Get-Json -Config $cfg

foreach( $url in $url_to_validate ) {
    foreach( $server in ($url.servers | Select-Object -Expand server) ) {
        $results = Get-WebRequest -url $url.url -Server $server 
        if( $saveReply ) { Save-Reply -Url $url -Text $results -Server $server }
        Validate-Results -Rules $url.Rules -Results $results
    }
}
