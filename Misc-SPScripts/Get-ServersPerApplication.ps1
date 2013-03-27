param (
    [string] $application
)

. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

$url = "http://teamadmin.gt.com/sites/ApplicationOperations/applicationsupport/"
$list = "Applications - Production"

function Split-Servers([string] $servers)
{
    return @($servers.Split(";#") | Where { $_ -imatch "(\w+)-(\w+)-.*" })
}

function Split-DBServer([string] $server, [string] $port, [string] $instance)
{
    $servers = Split-Servers $server
    $ports = @( $port.Split(";#") | where { $_ -imatch "[0-9]+\..*" } )
    $instances = @( $instance.Split(";#") | Where { $_ -imatch "[A-Za-z]+" } )

    $dbs = @()
    for( $i=0; $i -lt $servers.Length; $i++ ) {
        $dbs += "{0},{1}\{2}" -f ($servers[$i]).TrimEnd(), ([int]$ports[$i]).ToString().TrimEnd(), ($instances[$i]).TrimEnd()
    }

    return $dbs
}
    
function main
{
    $app = Get-SPListViaWebService -url $url -list $list | Where Name -imatch $application 

    $systems = @()
    foreach( $web_server in (Split-Server -server $app.WebServers) ) {
        $systems += ( New-Object PSObject -Property @{
            App = $app.Name
            Type = "Web Server"
            Server = $web_server
        })
    }

    foreach( $app_server in (Split-Server -server $app."Application Servers") ) {
        $systems += ( New-Object PSObject -Property @{
            App = $app.Name
            Type = "Application Server"
            Server = $app_server
        })
    }
    
    foreach( $citrix_server in (Split-Server -server $app."Citrix Servers") ) {
        $systems += ( New-Object PSObject -Property @{
            App = $app.Name
            Type = "Citrix Server"
            Server = $citrix_server
        })
    }

    foreach( $db_server in (Split-DBServer -server $app."Database Server" -port $app."Database Server:Port" -instance $app."Database Server:Instance") ) {
        $systems += ( New-Object PSObject -Property @{
            App = $app.Name
            Type = "Database Server"
            Server = $db_server
        })

    }
    return $systems 
}
main