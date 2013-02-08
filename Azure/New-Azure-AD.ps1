param (
    [string] $domain_name
)

if( $domain_name -notmatch "\." ) {
    throw "Domain name must be in the form of <name>.<toplevel> such as sharepoint.test"
}

$netbois_name, $top_level = $domain_name.Split(".")
$ca_name = "dc={0},dc={1}" -f $netbois_name, $top_level
$root_ca = "CN={0},{1}" -f "ca",$ca_name

#Install Features
Import-Module ServerManager
Add-WindowsFeatures AD-domain-Services,ADDS-Domain-Controller

#Create Domain
Import-Module ADDSDeployment
Install-ADDSForest `
	-CreateDnsDelegation:$false
	-DatabasePath "D:\AD\NTDS" 
	-DomainMode "Win2012" 
	-DomainName $domain_name #"sharepoint.test"
	-DomainNetbiosName $netbois_name #"SHAREPOINT"
	-ForestMode "Win2012"
	-InstallDns:$true
	-LogPath "D:\AD\NTDS" 
	-NoRebootOnCompletion:$false 
	-SysvolPath "D:\AD\SYSVOL"
	-Force:$true

#Cert Authority
Add-WindowsFeature Adcs-Cert-Authority -IncludeManagementTools
Install-AdcsCertificationAuthority -CAType EnterpriseRootCA 
    -CryptoProviderName “RSA# Microsoft Software Key Storage Provider” 
    -KeyLength 2048 
    -HashAlgorithmName SHA1 
    -ValidityPeriod Years 
    -ValidityPeriodUnits 15
    -CADistinguishedNameSuffix $ca_name #'dc=sharepoint,dc=test' 
    -Root-CA $root_ca #'CN=ca,dc=sharepoint,dc=test'
    -DatabaseDirectory 'D:\Certs\DB'
    -LogDirectory 'D:\Certs\Logs'