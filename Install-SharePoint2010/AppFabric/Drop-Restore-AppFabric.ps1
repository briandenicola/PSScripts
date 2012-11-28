param(
	[string] $sql_server
)

Import-Module ApplicationServer
. D:\Scripts\Libraries\Standard_Functions.ps1

$ErrorActionPreference = "SilentlyContinue"

# Gets a SQL connection string to the specified server and database.
function Create-SqlConnString([string]$server, [string]$database)
{
    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder.PSBase.DataSource = $server
    $builder.PSBase.InitialCatalog = $database
    $builder.PSBase.IntegratedSecurity = $true
    return [string] $builder.ToString()
}

$admin_group = "USGTAD\(IT) SharePoint Admins"
$users_group = "$ENV:COMPUTERNAME\IIS_Users"

$persistence_database = "AppFabric_Persistence_Store"
Query-DatabaseTable -dbs master -server $sql_server -sql "Alter Database $persistence_database SET SINGLE_USER WITH ROLLBACK IMMEDIATE"
Query-DatabaseTable -dbs master -server $sql_server -sql "Drop Database $persistence_database"

$persistence_connection = Create-SqlConnString $sql_server $persistence_database

Initialize-ASPersistenceSqlDatabase -Server $sql_server -Database $persistence_database -Admins $admin_group -Readers $readers_group -Users $admin_group
Set-ASAppSqlServicePersistence -ConnectionStringName $persistence_database -Root -HostLockRenewalPeriod "00:00:20" -InstanceEncodingOption "GZip" -InstanceCompletionAction "DeleteNothing" -InstanceLockedExceptionAction "BasicRetry" |out-null

Query-DatabaseTable -dbs $persistence_database -server $sql_server -sql "exec sp_helpfile" | out-null
Query-DatabaseTable -dbs $persistence_database -server $sql_server -sql "exec sp_grantdbaccess 'USGTAD\worksite'"
Query-DatabaseTable -dbs $persistence_database -server $sql_server -sql "exec sp_addrolemember db_datareader, 'USGTAD\worksite'" 
Query-DatabaseTable -dbs $persistence_database -server $sql_server -sql "exec sp_addrolemember db_datawriter, 'USGTAD\worksite'" 
