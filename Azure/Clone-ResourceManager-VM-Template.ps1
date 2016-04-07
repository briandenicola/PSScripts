param(
    [string] $SubscriptionName,
    [string] $ResourceGroupName,
    [string] $StorageAccountName,
    [string] $SourceBlobName,
    [string] $DestinationBlobName,
    [string] $VMName,
    [string] $VMSize = "Standard_A1",
    [string] $Location = "northcentralus"
)

Import-Module Azure
Import-Module AzureRM.Profile
Import-Module AzureRM.Compute

Login-AzureRmAccount
Get-AzureRmSubscription -SubscriptionName $SubscriptionName | Tee-Object -Varible SubScriptionId | Select-AzureRmSubscription� | Out-Null
Set-AzureRmCurrentStorageAccount -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName

$params = @{
    SrcContainer = "vhds"
    SrcBlob = $SourceBlobName
    DestBlob = $DestinationBlobName
    DestContainer = "vhds"
}

Start-AzureStorageBlobCopy @params

$vhd_uri = "https://{0}.blob.core.windows.net/vhds/{1}" -f $StorageAccountName, $DestinationBlobName 
$subnet_id = "/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Network/virtualNetworks/{1}/subnets/default" -f $SubScriptionId.SubscriptionId, $ResourceGroupName  

$vm = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
Set-AzureRmVMOSDisk -VM $vm -VhdUri $vhd_uri -CreateOption attach -Name $VMName -Windows
$nic = New-AzureRmNetworkInterface -ResourceGroupName $ResourceGroupName -Name ("{0}-nic" -f $VMName) -Location $location -SubnetId $subnet_id
Add-AzureRmVMNetworkInterface -VM $vm -NetworkInterface $nic

New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $location -VM $vm