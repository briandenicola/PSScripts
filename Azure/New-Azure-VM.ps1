param (
    [string] $settings_file,
    [string] $subscription,
    [string] $service,
    [string] $network,
    [string] $storage,
    [string] $domain,
    [string] $name,
    [string] $size = "small",
    [string] $password = 'Pa$$w0rd'
)

$image = 'MSFT__Win2K8R2SP1-Datacenter-201207.01-en.us-30GB.vhd'

Import-Module "C:\Program Files (x86)\Microsoft SDKs\Windows Azure\PowerShell\Azure\Azure.psd1"
Import-AzurePublishSettingsFile $settings_file

Set-AzureSubscription -SubscriptionName $subscription -CurrentStorageAccount $storage
Select-AzureSubscription -SubscriptionName $subscription

$vm = New-AzureVMConfig -Name $name -InstanceSize $size -ImageName $image |
    Add-AzureProvisioningConfig -Windows -Password $password |
    Add-AzureDataDisk -CreateNew -DiskSizeInGB 50 -DiskLabel 'datadisk1' -LUN 0 |
    Add-AzureProvisioningConfig -WindowsDomain -Password $password -Domain $domain -DomainPassword $password -DomainUserName 'Administrator' -JoinDomain $domain

$dns = Get-AzureDeployment -ServiceName $service | Get-AzureDNS

New-AzureVM -ServiceName $service -VMs $vm -DnsSettings $dns -VNetName $vnet