param(
    [string] $path,
    [string] $domain
)

Add-WindowsFeature Adcs-Cert-Authority -IncludeManagementTools
Install-AdcsCertificationAuthority -CAType EnterpriseRootCA -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
    -CACommonName ("{0} Certificate Authority" -f $domain) `
    -KeyLength 2048 `
    -HashAlgorithmName SHA256 `
    -ValidityPeriod Years `
    -ValidityPeriodUnits 15 `
    -CADistinguishedNameSuffix ('dc={0},dc={1}' -f $domain.Split(".")[0], $domain.Split(".")[1]) `
    -DatabaseDirectory (Join-Path -Path $path -ChildPath "Certs\Database") `
    -LogDirectory (Join-Path -Path $path -ChildPath "Certs\Logs") `
    -Force:$true `
    -Confirm:$false