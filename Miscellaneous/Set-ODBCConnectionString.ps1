param (
    [Parameter(Mandatory=$true)]
    [string] $connectionName,

    [Parameter(Mandatory=$true)]
    [string] $serverName, 

    [Parameter(Mandatory=$true)]
    [string] $databaseName, 

    [Parameter(Mandatory=$true)]
    [string] $keystorePrincipalId, 

    [Parameter(Mandatory=$true)]
    [string] $keystoreSecret 
)

$odbcPath = "HKLM:\SOFTWARE\ODBC\ODBC.INI\ODBC Data Sources"
$KeyName  = "HKLM:\SOFTWARE\ODBC\ODBC.INI\{0}" -f $connectionName 
$settings = @(
    @{Name="Driver";                    Value= "C:\Windows\system32\msodbcsql17.dll"},
    @{Name="KeystoreAuthentication";    Value="KeyVaultClientSecret"},
    @{Name="KeystorePrincipalId";       Value=$keystorePrincipalId},
    @{Name="Encrypt";                   Value="Yes"},
    @{Name="TrustServerCertificate";    Value="No"},
    @{Name="ColumnEncryption";          Value="Enabled"}
    @{Name="KeystoreSecret";            Value=$keystoreSecret},
    @{Name="Authentication";            Value="ActiveDirectoryMSI"}
)

if( -not (Test-Path -Path $odbcPath)) {
    New-Item -Path $odbcPath -ItemType Key    
}
Set-ItemProperty -Path $odbcPath -Name $connectionName -Value "ODBC Drive 17 for SQL Server"

New-Item -Path $keyName -ItemType Key
foreach( $setting in $settings ) {
    Set-ItemProperty -Path $KeyName -Name $setting.Name -Value $setting.Value 
}
