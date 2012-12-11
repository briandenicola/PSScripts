param (
	[string] $db = $(throw 'The SQL Database Server is required'),
	[string] $farm = "GT-SharePoint2010",
	[string] $port = 10000,
	[string] $account,
	[string] $passphrase
)

Import-Module .\Modules\SPModule.misc
Import-Module .\Modules\SPModule.setup
Add-PsSnapin Microsoft.SharePoint.PowerShell

$cred = get-credential $account
$secure_passphrase = ConvertTo-SecureString $passphrase -asPlainText -Force

New-SharePointFarm -DatabaseAccessAccount ($cred) -DatabaseServer $db -FarmName $farm -Port $port -PassPhrase $secure_passphrase