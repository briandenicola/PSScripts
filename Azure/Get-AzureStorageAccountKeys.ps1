[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $CSVPath,

    [string] $ResourceGroup = "securitydata"
)

try{
    Get-AzureRmContext | Out-Null
}
catch {
    Login-AzureRMAccount
}

$acts = @()
foreach( $subscription in (Get-AzureRMSubscription)) {
    Write-Verbose -Message ("[{0}] - Working on Subscription {1} ({2})" -f $(Get-Date), $subscription.SubscriptionName, $subscription.SubscriptionId)
    Set-AzureRMContext -SubscriptionId $subscription.SubscriptionId | Out-Null
    $acts += Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroup |
        Select-Object StorageAccountName, Location, @{N="PrimayKey";E={$_.Context.StorageAccount.Credentials.ExportBase64EncodedKey()}}
}

$acts | Export-CSV -NoTypeInformation -Encoding ASCII -Path $CSVPath