param (
	[string] $db = $(throw 'The SQL Database Server is required'),
	[string] $configDB = "SP2013_SharePoint_Configuration_Database",
	[string] $passphrase
)

Import-Module .\Modules\SPModule.misc
Import-Module .\Modules\SPModule.setup
Add-PsSnapin Microsoft.SharePoint.PowerShell

$secure_passphrase = ConvertTo-SecureString $passphrase -asPlainText -Force
Join-SharePointFarm -Passphrase $secure_passphrase -DatabaseServer $db -ConfigurationDatabaseName $configDB
