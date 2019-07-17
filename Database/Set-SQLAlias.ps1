
param( 
    [string] $instance, 
    [int]    $port, 
    [string] $alias
)

[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
$objComputer = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer "."

$newalias = New-Object ("Microsoft.SqlServer.Management.Smo.Wmi.ServerAlias")
$newalias.Parent = $objComputer
$newalias.Name = $alias
$newalias.ServerName = $instance
$newalias.ConnectionString = $port
$newalias.ProtocolName = 'tcp' 
$newalias.Create()