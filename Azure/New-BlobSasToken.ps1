[CmdletBinding()]
param(
    [ValidatePattern('[http|https]://(.*).blob.core.windows.net/(.*)/(.*)')]
    [string] $uri,

    [ValidateRange(1,36500)]
    [int]    $ValidDays = 1,

    [ValidateSet("r", "rwd", "rw", IgnoreCase = $true)]
    [string] $Permissions = "r"
)

Set-StrictMode -Version 5
Import-Module -Name Azure_Functions -Force

try { 
    $resources = Get-AzureRmContext
}
catch { 
    Write-Verbose -Message ("[{0}] - Logging into Azure" -f $(Get-Date))
    Login-AzureRmAccount 
}

$valid_uri = $uri -match "[http|https]://(.*).blob.core.windows.net/(.*)/(.*)"

if( $valid_uri ) {
    $storageAccount = $matches[1]
    $containerName = $matches[2]
    $blob = $matches[3]

    try {
        $resource = Get-AzureRmResource | Where-Object { $_.Name -eq $storageAccount -And $_. ResourceType -eq "Microsoft.Storage/storageAccounts" }
        $resourceGroup = $resource.ResourceGroupName
        $ctx = Get-AzureRMStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccount | Select-Object -ExpandProperty Context
        $Expiry = $(Get-Date).AddDays($ValidDays)
        $token =  New-AzureStorageBlobSASToken -Container $containerName -Permission $Permissions -Blob $blob -Context $ctx -StartTime $(Get-Date).AddHours(-1) -ExpiryTime $Expiry

        return ("Blob SAS Token - {0}{1}" -f $uri, $token)
    }
    catch {
        Write-Error  ("`n[{0}] - Caught Error:`n {1}" -f $(Get-Date), $_.Exception.ToString() )
    }
    
}
else {
    Write-Error ("[{0}] - Invalid Uri.`nExpected - http(s)://[storageaccount].blob.core.windows.net/[container]/[blob]`nReceived - {1}" -f $(Get-Date), $uri)
}