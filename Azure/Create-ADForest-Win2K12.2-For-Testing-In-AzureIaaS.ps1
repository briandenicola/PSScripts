param(
   [string] $DomainName,
   [string] $RecoveryPassword
)

#Install Features
Import-Module ServerManager
Add-WindowsFeature AD-domain-Services

$SecureRecoveryPassword  = ConvertTo-SecureString $RecoveryPassword -AsPlainText -Force

$opts = @{
    DomainMode = "Win2012"
    ForestMode = "Win2012"
	DomainName = $DomainName
	DomainNetbiosName = ($DomainName.Split(".")[0])
	InstallDns = $true 
    CreateDnsDelegation = $false 
	NoRebootOnCompletion = $true
    Force = $true
	SysvolPath = "C:\AD\SYSVOL"
    LogPath = "c:\AD\NTDS"
    DatabasePath = "C:\AD\NTDS"
    SafeModeAdministratorPassword = $SecureRecoveryPassword 
}

#Create Domain
Import-Module ADDSDeployment
Install-ADDSForest @opts

Restart-Computer 