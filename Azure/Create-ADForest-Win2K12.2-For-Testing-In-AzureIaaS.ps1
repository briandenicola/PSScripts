$ans = Read-Host "This script will install and configure Active Directory Domain Services on this system. Do you want to continue ?"

#Install Features
Import-Module ServerManager
Add-WindowsFeature AD-domain-Services

#Create Domain
Import-Module ADDSDeployment
Install-ADDSForest `
	-CreateDnsDelegation:$false `
	-DatabasePath "C:\AD\NTDS" `
	-DomainMode "Win2012" `
	-DomainName "sharepoint.test" `
	-DomainNetbiosName "sharepoint" `
	-ForestMode "Win2012" `
	-InstallDns:$true `
	-LogPath "c:\AD\NTDS" `
	-NoRebootOnCompletion:$false `
	-SysvolPath "C:\AD\SYSVOL" `
	-Force:$true

#Create Users
$plain = 'Pa&&word'
$pass = ConvertTo-SecureString $plain -AsPlainText -Force
New-ADUser svc_farm -AccountPassword $pass -PasswordNeverExpires $true -Enabled $true -Path "CN=Managed Service Accounts,DC=sharepoint,DC=test"
New-ADUser svc_search -AccountPassword $pass -PasswordNeverExpires $true -Enabled $true -Path "CN=Managed Service Accounts,DC=sharepoint,DC=test"
New-ADUser svc_profile -AccountPassword $pass -PasswordNeverExpires $true -Enabled $true -Path "CN=Managed Service Accounts,DC=sharepoint,DC=test"
New-ADUser svc_web -AccountPassword $pass -PasswordNeverExpires $true -Enabled $true -Path "CN=Managed Service Accounts,DC=sharepoint,DC=test"
New-ADUser svc_sql -AccountPassword $pass -PasswordNeverExpires $true -Enabled $true -Path "CN=Managed Service Accounts,DC=sharepoint,DC=test"

#Cert Authority
Add-WindowsFeature Adcs-Cert-Authority -IncludeManagementTools
Install-AdcsCertificationAuthority -CAType EnterpriseRootCA `
    -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
    -CACommonName "GTCloud CA" `
    -KeyLength 2048 `
    -HashAlgorithmName SHA1 `
    -ValidityPeriod Years `
    -ValidityPeriodUnits 15 ` 
    -CADistinguishedNameSuffix 'dc=sharepoint,dc=test' `
    -DatabaseDirectory 'C:\Certs\DB' `
    -LogDirectory 'C:\Certs\Logs'