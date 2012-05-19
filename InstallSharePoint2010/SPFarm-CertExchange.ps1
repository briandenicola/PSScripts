param (
	[Parameter(Mandatory=$true)]
	[ValidateSet("services","internal","external")]
	[string] 
	$RemotefarmType,
	
	[Parameter(Mandatory=$true)]
	[string]
	$RemoteCentralAdmin
)
Add-PSSnapin Microsoft.SharePoint.PowerShell –erroraction SilentlyContinue

if( $RemotefarmType -eq "services" )
{
	if( Test-Path ( "\\$RemoteCentralAdmin\D$\Certs\ServicesFarmRoot.cer" ) )
	{
		Copy-Item \\$RemoteCentralAdmin\D$\Certs\ServicesFarmRoot.cer D:\Certs\
		$trustCert = Get-PfxCertificate "D:\Certs\ServicesFarmRoot.cer"
		New-SPTrustedRootAuthority "GT-ServicesFarm" -Certificate $trustCert
	} 
	else
	{
		Write-Host "\\$RemoteCentralAdmin\D$\Certs\ServicesFarmRoot.cer was not found. Can not import certs." -ForegroundColor Red
	}
}
else
{
	if( Test-Path ( "\\$RemoteCentralAdmin\D$\Certs" ) )
	{
		Copy-Item \\$RemoteCentralAdmin\D$\Certs\$RemotefarmType-Root.cer D:\Certs\
		Copy-Item \\$RemoteCentralAdmin\D$\Certs\$RemotefarmType-STS.cer D:\Certs\
		Copy-Item \\$RemoteCentralAdmin\D$\Certs\$RemotefarmType-Id.txt D:\Certs\
		
		$trustCert = Get-PfxCertificate "D:\Certs\$RemotefarmType-Root.cer"
		New-SPTrustedRootAuthority "GT-$RemotefarmType" -Certificate $trustCert
		
		$stsCert = Get-PfxCertificate "D:\Certs\$RemotefarmType-STS.cer"
		New-SPTrustedServiceTokenIssuer "GT-$RemotefarmType" -Certificate $stsCert
		
		$farm_id = Get-Content "D:\Certs\$RemotefarmType-Id.txt"
		
		$security = Get-SPTopologyServiceApplication | Get-SPServiceApplicationSecurity 
		$claimProvider = (Get-SPClaimProvider System).ClaimProvider
		$principal = New-SPClaimsPrincipal -ClaimType http://schemas.microsoft.com/sharepoint/2009/08/claims/farmid -ClaimProvider $claimProvider -ClaimValue $farm_id
	}
	else
	{
		Write-Host "\\$RemoteCentralAdmin\D$\Certs was not found. Can not import certs." -ForegroundColor Red
	}
}

