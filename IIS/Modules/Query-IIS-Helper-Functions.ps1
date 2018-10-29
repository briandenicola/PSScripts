. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

function Lookup-Servers-In-SharePoint {
    param ( 
        [string[]] $computers,
        [string] $url,
        [string] $list,
        [string] $view
    )

    $sp_formatted_data = @()
    $sp_server_list = Get-SPListViaWebService -url $url -list $list -view $view
	
    foreach ( $computer in $computers ) { 
        if ( $computer -imatch "(.*)\\(.*)" ) { $computer = $Matches[1] }
        $sp_formatted_data += "{0};#{1}" -f ($sp_server_list | Where { $_.SystemName -imatch $computer -or $_."Client Alias" -eq $computer}).ID, $computer.ToUpper()
    }
	
    return ( [string]::join( ";#", $sp_formatted_data ) )
}


function Get-ScriptBlock( [string] $file ) {
    [ScriptBlock]::Create( (gc $file | Out-String ) )
}

function Upload-Results {
    param (
        [PSCustomObject[]] $results,
        [string] $list_url,
        [HashTable] $sql,
        [HashTable] $web
    )

    foreach ( $result in $results ) {
        Write-Host ("[" + $(Get-Date) + "] - Uploading " + $result.WebApplication + " . . . ")
        $result.Real_x0020_Servers = Lookup-Servers-In-SharePoint -computers $result.Real_x0020_Servers.Split(";") -url $list_url -list $web.Name -view $web.View
        $result.SQL_x0020_Servers = Lookup-Servers-In-SharePoint -computers $result.SQL_x0020_Servers.Split(";") -url $list_url -list $sql.Name -view $sql.View
        
        Write-Verbose ("Upload Result - " + $result)
        WriteTo-SPListViaWebService -url $list_url -list $list_websites -Item (Convert-ObjectToHash $result) -TitleField "WebApplication"
    }
}
