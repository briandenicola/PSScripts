param(
	[string] $RemoteCentralAdmin,
	[string] $RemoteFarmType
)

Add-PSSnapin Microsoft.SharePoint.Powershell –EA SilentlyContinue

Write-Host "[$(Get-Date)] - Importing $RemoteFarmType Farm Trust and STS Certificates ($RemoteCentralAdmin)"

if( Test-Path ( "\\$RemoteCentralAdmin\D$\Certs" ) )
{
	Copy-Item \\$RemoteCentralAdmin\D$\Certs\$RemoteFarmType-Root.cer D:\Certs\
	Copy-Item \\$RemoteCentralAdmin\D$\Certs\$RemoteFarmType-STS.cer D:\Certs\
	
	$trustCert = Get-PfxCertificate "D:\Certs\$RemoteFarmType-Root.cer"
	New-SPTrustedRootAuthority "RemoteFarm-$RemoteFarmType" -Certificate $trustCert
	
	$stsCert = Get-PfxCertificate "D:\Certs\$RemoteFarmType-STS.cer"
	New-SPTrustedServiceTokenIssuer "RemoteFarm-$RemoteFarmType" -Certificate $stsCert
}
else
{
	Write-Host "[$(Get-Date)] - \\$RemoteCentralAdmin\D$\Certs was not found. Can not import certs." -ForegroundColor Red
}