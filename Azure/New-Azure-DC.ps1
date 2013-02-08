param (
    [string] $settings_file,
    [string] $subscription,
    [string] $service,
    [string] $network,
    [string] $storage,
    [string] $dns_ip,
    [string] $name,
    [string] $size = "small",
    [string] $password = 'Pa$$w0rd'
)

Import-Module "C:\Program Files (x86)\Microsoft SDKs\Windows Azure\PowerShell\Azure\Azure.psd1"

Import-AzurePublishSettingsFile $settings_file

Set-AzureSubscription -SubscriptionName $subscription -CurrentStorageAccount $storage
Select-AzureSubscription -SubscriptionName $subscription

$dns = New-AzureDNS -Name 'DNS-Server' -IPAddress $dns_ip

# OS Image to Use
$image = 'MSFT__Win2K8R2SP1-Datacenter-201207.01-en.us-30GB.vhd'

#VM Configuration
$dc = New-AzureVMConfig -name $name -InstanceSize $size -ImageName $image |
    Add-AzureProvisioningConfig -Windows -Password $password
  
New-AzureVM -ServiceName $service -VMs $dc -DnsSettings $dns -VNetName $network 