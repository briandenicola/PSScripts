[CmdletBinding(SupportsShouldProcess = $true)]
param ( 
    [Parameter(Mandatory = $true)]	
    [string[]] $computers,
    [switch] $upload,
    [switch] $sharepoint,
    [switch] $citrix
)

. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

if ( $sharepoint ) {
    $global:url = ""
    $global:list = "Servers"
}
elseif ( $citrix ) { 
    $global:url = ""
    $global:list = "Citrix Servers"
}
else { 
    $global:url = ""
    $global:list = "AppServers"
}

foreach ( $server in $computers ) { 

    Write-Verbose "Working on $($server) . . ."

    if ( !(Check-ServerAccess -computer $server ) ) {
        Write-Error "ACCESS DENIED - $server . . ."
        continue 
    }

    $properties = audit-Server $server 
	
    if ( $upload ) {
        Write-Verbose "[ $(Get-Date) ] - Upload was passed on command line. Will upload results to $global:url ($global:list)  . . . "
        WriteTo-SPListViaWebService -url $global:url -list $global:list -Item $(Convert-ObjectToHash $properties) -TitleField SystemName 
    }
    else {
        $properties
    }
}