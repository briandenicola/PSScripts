Param (
    [Parameter(Mandatory=$true)][string] $vm_name,
    [Parameter(Mandatory=$true)][string] $cloud_service,
    [Parameter(Mandatory=$true)][string] $password,
    [Parameter(Mandatory=$false)][string] $config = '.\Config\clone_config.xml'
)

. (Join-Path $ENV:SCRIPTS_HOME "Azure_Functions.ps1")

$cfg = [xml] ( Get-Content $config ) 

Set-AzureSubscription -SubscriptionName $global:subscription -CurrentStorageAccount $cfg.azure.storage
Select-AzureSubscription -SubscriptionName $global:subscription

$e_drive_destination_blob = [string]::Format( "{0}-E-Drive.vhd", $vm_name  )
$storage_url = [string]::Format( "http://{0}.blob.core.windows.net/vhds/{1}" , $cfg.azure.storage, $e_drive_destination_blob  )

$container = Get-AzureStorageContainer 
$params = @{
    SrcContainer = $container.Name
    DestContainer = $container.Name
    SrcBlob = $cfg.azure.vm_e_drive_source
    DestBlob = $e_drive_destination_blob
}

$job = Start-AzureStorageBlobCopy @params
$job | Get-AzureStorageBlobCopyState -WaitForComplete

$vm = New-AzureVMConfig -Name $vm_name -InstanceSize $cfg.azure.vm_size -ImageName $cfg.azure.vm_image |
    Add-AzureProvisioningConfig -Windows -Password $password -AdminUsername $cfg.azure.admin_user |
    Set-AzureSubnet -SubnetNames $cfg.azure.subnet | 
    Add-AzureDataDisk -ImportFrom -MediaLocation $storage_url -LUN 1 -DiskLabel "DATA"

New-AzureVM -VMs $vm -ServiceName $cloud_service -AffinityGroup $cfg.azure.vm_affinity  -VNetName $cfg.azure.vm_affinity