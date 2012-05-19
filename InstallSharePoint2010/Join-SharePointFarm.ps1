param (
	[string] $db = $(throw 'The SQL Database Server is required'),
	[string] $configDB = "GT-SharePoint2010_SharePoint_Configuration_Database"
)

Import-Module .\Modules\SPModule.misc
Import-Module .\Modules\SPModule.setup
Add-PsSnapin Microsoft.SharePoint.PowerShell

Write-Host "Please enter the Farm's Passphrase"
$passphrase = ConvertTo-SecureString -asPlainText -Force
Join-SharePointFarm -Passphrase $passphrase -DatabaseServer $db -ConfigurationDatabaseName $configDB 
