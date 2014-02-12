#require -version 3.0
[CmdletBinding(SupportsShouldProcess=$true)]
param(   
    [Parameter(Mandatory = $true)][string] $website_name,
    [Parameter(Mandatory = $true)][String] $db_user,
    [Parameter(Mandatory = $true)][String] $db_password,
    [Parameter(Mandatory = $true)][String] $db_name,
    [string] $Location = "East US"
)

. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Azure_Functions.ps1")
. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

Set-Variable -Name external_ip_addresses -Value @("209.220.64.20","209.220.66.20","216.142.208.222","38.84.128.194") -Option Constant

function Get-SQLAzureDatabaseConnectionString {    
    param(
        [String] $DBServer,
        [String] $DBName,
        [String] $DBUser,
        [String] $DBPassword
    )
        
    $conn = [string]::Format(
        "Server=tcp:{0}.database.windows.net,1433;Database={1};User ID={2}@{0};Password={3};Trusted_Connection=False;Encrypt=True;Connection Timeout=30;",
        $DBServer,
        $DBName,
        $DBUser,
        $DBPassword
    )
    
    return (@{Name = "DefaultConnection"; Type = "SQLAzure"; ConnectionString = $conn})
}

Write-Host ("[{0}] - Creating Azure Web Site - {1}" -f $(Get-Date), $website_name)
$azure_website = New-AzureWebsite -Name $website_name -Location $Location 

Write-Host ("[{0}] - Creating Azure Database Server" -f $(Get-Date))
$azure_databaseServer = New-AzureSqlDatabaseServer -AdministratorLogin $db_user -AdministratorLoginPassword $db_password -Location $Location 

Write-Host ("[{0}] - Azure Database Server - {1}" -f $(Get-Date), $azure_databaseServer.ServerName)

Write-Host ("[{0}] - Setting Azure Database Server Firewall Rules " -f $(Get-Date))
New-AzureSqlDatabaseServerFirewallRule -ServerName $azure_databaseServer.ServerName -AllowAllAzureServices  -RuleName "AllowAllAzureIP"
foreach( $ip in $external_ip_addresses ) { 
    New-AzureSqlDatabaseServerFirewallRule -ServerName $azure_databaseServer.ServerName -StartIpAddress $ip -EndIpAddress $ip -RuleName ("GT External IP {0}" -f $ip)
}

$cred =  New-Object System.Management.Automation.PSCredential ( $db_user, (ConvertTo-SecureString $db_password -AsPlainText -Force) )
$context = New-AzureSqlDatabaseServerContext -ServerName $azure_databaseServer.ServerName -Credential $cred

Write-Host ("[{0}] - Creating Azure Database - {1}" -f $(Get-Date), $db_name)
New-AzureSqlDatabase -DatabaseName $db_name -Context $context    

$app_connection_string = Get-SQLAzureDatabaseConnectionString -DBServer $azure_databaseServer.ServerName -DBName $db_name -DBUser $db_user -DBPassword $db_password 

Write-Host ("[{0}] - Setting Azure Website Connection to - {1}" -f $(Get-Date), $app_connection_string.ConnectionString)
Set-AzureWebsite -Name $website_name -ConnectionStrings $app_connection_string -PhpVersion "off" -HttpLoggingEnabled 1

Write-Host ("[{0}] - Restatring Azure Website - {1}" -f $(Get-Date), $website_name)
Restart-AzureWebsite -Name $website_name