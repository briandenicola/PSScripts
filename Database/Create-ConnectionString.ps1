param(
    [Parameter(Mandatory = $True)][string]$sql_instance,
    [Parameter(Mandatory = $True)][string]$database,

    [Parameter(Mandatory = $False, ParameterSetName = "Integrated")][switch] $integrated_authentication,
    [Parameter(Mandatory = $true, ParameterSetName = "SQL")][string]$user = [string]::empty,
    [Parameter(Mandatory = $true, ParameterSetName = "SQL")][string]$password = [string]::empty
)
$builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
$builder['Data Source'] = $sql_instance
$builder['Initial Catalog'] = $database

if ( $integrated_authentication ) { 
    $builder['Integrated Security'] = $true
}
else { 
    $builder['User ID'] = $user
    $builder['Password'] = $password
}

return $builder.ConnectionString
