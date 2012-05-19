param (
	[string] $db = $(throw 'The SQL Database Server is required'),
	[string] $farm = "GT-SharePoint2010",
	[string] $port = 10000
)

Import-Module .\Modules\SPModule.misc
Import-Module .\Modules\SPModule.setup
Add-PsSnapin Microsoft.SharePoint.PowerShell

$cred = get-credential
Write-Host "Please enter the Farm's Passphrase. This can be changed later using Set-SPPassPhase"
$passphrase = ConvertTo-SecureString -asPlainText -Force

New-SharePointFarm -DatabaseAccessAccount ($cred) -DatabaseServer $db -FarmName $farm -Port $port -PassPhrase $passphrase