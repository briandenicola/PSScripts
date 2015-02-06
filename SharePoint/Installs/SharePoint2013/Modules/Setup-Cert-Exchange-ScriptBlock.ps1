param(
	[string] $RemoteCentralAdmin,
	[string] $RemoteFarmType
)

if( (Get-PSDrive -PSProvider FileSystem | where { $_.Root -eq "D:\" }) ) { $drive = "D:" } else { $drive = "C:" }
$cert_home = (Join-Path $drive "Certs") + "\"

Add-PSSnapin Microsoft.SharePoint.Powershell –EA SilentlyContinue

Write-Host "[ $(Get-Date) ] - Importing $RemoteFarmType Farm Trust and STS Certificates ($RemoteCentralAdmin)"

if( Test-Path ( "\\$RemoteCentralAdmin\Certs" ) ) {
	Copy-Item \\$RemoteCentralAdmin\Certs\$RemoteFarmType-Root.cer $cert_home
	Copy-Item \\$RemoteCentralAdmin\Certs\$RemoteFarmType-STS.cer $cert_home
	
	$trustCert = Get-PfxCertificate (Join-Path $cert_home "$RemoteFarmType-Root.cer")
	New-SPTrustedRootAuthority "SP-Farm-$RemoteFarmType" -Certificate $trustCert
	
	$stsCert = Get-PfxCertificate (Join-Path $cert_home "$RemoteFarmType-STS.cer")
	New-SPTrustedServiceTokenIssuer "SP-Farm-$RemoteFarmType" -Certificate $stsCert
}
else {
	Write-Host "[ $(Get-Date) ] - \\$RemoteCentralAdmin\Certs was not found. Can not import certs." -ForegroundColor Red
}