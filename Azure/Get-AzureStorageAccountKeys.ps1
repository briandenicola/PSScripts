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
        Select-Object StorageAccountName, Location, @{N="PrimayKey";E={((Get-AzureRmStorageAccountKey -ResourceGroupName $_.ResourceGroupName -StorageAccountName $_.StorageAccountName).Value | Select -First 1)}}
}

$acts | Export-CSV -NoTypeInformation -Encoding ASCII -Path $CSVPath