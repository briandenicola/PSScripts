param (
	[string] $server
)
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1" )

Query-DatabaseTable -server $server -dbs master -sql "xp_ReadErrorLog"
