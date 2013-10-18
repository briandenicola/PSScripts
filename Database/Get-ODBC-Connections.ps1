param ( 
	[Parameter(Mandatory=$true)]
	[string[]] $computers
)

$sb = {
    $odbc_connections = @()

    foreach( $key in (Get-ChildItem -Path HKLM:\SOFTWARE\ODBC\ODBC.INI ) ) {
        $item = Get-Item -Path $key.Name.Replace("HKEY_LOCAL_MACHINE","HKLM:\")

        if( ! [string]::IsNullOrEmpty( $item.GetValue("Database") ) ) {
            $odbc_connections += (New-Object PSObject -Property @{
                Name = $item.GetValue("Description")
                Server = $env:COMPUTERNAME
                DBServer = $item.GetValue("Server")
                Database = $item.GetValue("Database")
                User = $item.GetValue("LastUser")
            })
        }
    }

    return $odbc_connections
}

function main 
{
    Invoke-Command -ComputerName $computers -ScriptBlock $sb | 
        Select Server, Name, DBServer, Database, User |
        Sort Name
}
main