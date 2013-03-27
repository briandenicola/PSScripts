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
    if( $servers -is [string] ) {
        $dbs += "{0},{1}\{2}" -f $servers, ([int]$ports[0]).ToString(), $instances[0]
    } else {
        for( $i=0; $i -lt $servers.Length; $i++ ) {
            $dbs += "{0},{1}\{2}" -f $servers[$i], ([int]$ports[$i]).ToString(), $instances[$i]
        }
    }
    return $dbs
}
    
function main
{
    $apps = Get-SPListViaWebService -url $url -list $list | Where Name -imatch $application 

    $systems = @()
    foreach( $app in $apps) {
        foreach( $web_server in (Split-Servers -server $app.WebServers) ) {
            $systems += ( New-Object PSObject -Property @{
                App = $app.Name
                Type = "Web Server"
                Server = $web_server
            })
        }

        if( ! [string]::IsNullorEmpty($app.IISFarm) -and $app.IISFarm -ne "StandAlone" ) {
            $systems += ( New-Object PSObject -Property @{
                App = $app.Name
                Type = "Web Farm"
                Server = $app.IISFarm
            })
        }

        foreach( $app_server in (Split-Servers -server $app."Application Servers") ) {
            $systems += ( New-Object PSObject -Property @{
                App = $app.Name
                Type = "Application Server"
                Server = $app_server
            })
        }
    
        foreach( $citrix_server in (Split-Servers -server $app."Citrix Servers") ) {
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
    }
    return $systems 
}
main