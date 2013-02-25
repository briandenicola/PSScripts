Add-PSSnapin Microsoft.SharePoint.PowerShell –erroraction SilentlyContinue

function Register-SharePointApp 
{
	param (
		[string] $url,
		[string] $cert_path,
		[string] $name
	)
	
	$reg_key_path = "HKLM:SOFTWARE\Microsoft\Shared Tools\Web Server Extensions\15.0\WSS" 
	$reg_key_name = "AppDeploymentCheckAppPrincipalAccessToken"
	$id = [System.Guid]::NewGuid().ToString()
	
	try {
		$web = Get-SPWeb $url
		$cert = Get-PfxCertificate $cert_path
		
		$realm = Get-SPAuthenticationRealm -ServiceContext $web.Site
		$app_id = "{0}@{1}" -f $id,$realm
		$app_principal = Register-SPAppPrincipal -Name $app_id -Site $web -DisplayName $name
		
		$token = New-SPTrustedSecurityTokenIssuer -Name $name -Cert $cert -RegisteredIssuerName $app_id
		
		New-ItemProperty -Path $reg_key_path -Name $reg_key_name -Value "0" -PropertyType dword -Force
		
		$sharepoint_servers = @(Get-SPServer | Where { $_.Role -ne "Invalid" } | Select -Expand Address)
		if( $sharepoint_servers.Length -gt 1 ) {
			$systems = $sharepoint_servers | Where { $_ -inotmatch $ENV:COMPUTERNAME }
			if( $systems ) {
				Invoke-Command -ComputerName $systems -ScriptBlock { 
					New-ItemProperty -Path $reg_key_path -Name $reg_key_name -Value "0" -PropertyType dword -Force
				}
			}
		}
		Write-Host "Application - $name - was registered withd id - $app_id"
	}
	catch [System.Exception] {
		Write-Error ("Register failed with - " +  $_.Exception.ToString() )
	}
}