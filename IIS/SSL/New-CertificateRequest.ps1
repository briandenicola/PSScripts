#Version -3
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $CommonName,

    [Parameter(Mandatory = $true)]
    [string] $OrganizationalUnit,

    [Parameter(Mandatory = $true)]
    [string] $Organization,

    [Parameter(Mandatory = $true)]
    [string] $City,

    [Parameter(Mandatory = $true)]
    [string] $State,

    [Parameter(Mandatory = $false)]
    [string] $Country = "US",

    [Parameter(Mandatory = $false)]
    [ValidateSet(2048, 4096)] 
    [int]    $KeyLength = 2048,

    [Parameter(Mandatory = $true)]
    [string] $CertificateRequestFile
)

$cert_req = "c:\windows\system32\certreq.exe"
if ( !(Test-Path $cert_req) ) {
    throw ("Could not find {0}..." -f $cert_req)
}

$cert_request_template = @"
[NewRequest]
Subject="CN={0},OU={1},O={2},L={3},C={4}"
Exportable=TRUE
KeyLength=2048
HashAlgorithm=sha256
MachineKeySet=TRUE
FriendlyName={5}
RequestType = PKCS10
ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
KeySpec=1

[EnhancedKeyUsageExtension]
OID=1.3.6.1.5.5.7.3.1
"@ -f $CommonName, $OrganizationalUnit, $Organization, $City, $Country, $CommonName

$template = New-TemporaryFile
Add-Content -Encoding Ascii -Value $cert_request_template -Path $template
&$cert_req -New $template $CertificateRequestFile
Remove-Item -Path $template -Force | Out-Null