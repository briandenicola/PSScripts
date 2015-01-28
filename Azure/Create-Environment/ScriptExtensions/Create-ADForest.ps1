param(
    [string] $path,
    [string] $domain,
    [string] $netbios
)

#Install Features
Import-Module ServerManager
Add-WindowsFeature AD-domain-Services

#Create Domain
Import-Module ADDSDeployment
Install-ADDSForest `
	-CreateDnsDelegation:$false `
	-DatabasePath (Join-Path -Path $path -ChildPath "NTDS") `
	-DomainMode "Win2012" `
	-DomainName $domain `
	-DomainNetbiosName $netbios `
	-ForestMode "Win2012" `
	-InstallDns:$true `
	-LogPath (Join-Path -Path $path -ChildPath "NTDS") `
	-NoRebootOnCompletion:$false `
	-SysvolPath (Join-Path -Path $path -ChildPath "SYSVOL") `
	-Force:$true

#Cert Authority
Add-WindowsFeature Adcs-Cert-Authority -IncludeManagementTools
Install-AdcsCertificationAuthority -CAType EnterpriseRootCA `
    -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
    -CACommonName ("{0} Certificate Authority" -f $domain) `
    -KeyLength 2048 `
    -HashAlgorithmName SHA1 `
    -ValidityPeriod Years `
    -ValidityPeriodUnits 15 ` 
    -CADistinguishedNameSuffix ('dc={0},dc={1}' -f $domain.Split(".")[0], $domain.Split(".")[1]) `
    -DatabaseDirectory (Join-Path -Path $path -ChildPath "Certs\Database")`
    -LogDirectory (Join-Path -Path $path -ChildPath "Certs\Logs")

Restart-Computer -Force 