Param (
    [string] $vm_name,
    [string] $password,
    [string] $settings = ""
)

#. (Join-Path $ENV:SCRIPTS_HOME "Azure_Functions.ps1")

Set-Variable -Name vhd_e_drive -Value "" -Option Constant
Set-Variable -Name storage -Value "" -Option Constant
Set-Variable -Name subscription -Value "" -Option Constant
Set-Variable -Name vm_size -Value "Medium" -Option Constant
Set-Variable -Name vm_image -Value "" -Option Constant
Set-Variable -Name vm_affinity -Value "" -Option Constant
Set-Variable -Name admin_user -Value "manager" -Option Constant
Set-Variable -Name subnet -Value "servers" -Option Constant

Import-AzurePublishSettingsFile $settings

Set-AzureSubscription -SubscriptionName $subscription -CurrentStorageAccount $storage
Select-AzureSubscription -SubscriptionName $subscription

$e_drive = [string]::Format( "{0}-E-Drive.vhd", $vm_name  )
$storage_url = [string]::Format( "http://{0}.blob.core.windows.net/vhds/{1}" , $storage, $e_drive )

$container = Get-AzureStorageContainer 
$params = @{
    SrcContainer = $container.Name
    DestContainer = $container.Name
    SrcBlob = $vhd_e_drive
    DestBlob = $e_drive 
}
$job = Start-AzureStorageBlobCopy @params

$status = $job | Get-AzureStorageBlobCopyState 
while( $status.Status -eq "Pending" ){
  $status = $job | Get-AzureStorageBlobCopyState 
  Start-Sleep 10
}

$vm = New-AzureVMConfig -Name $vm_name -InstanceSize $vm_size -ImageName $vm_image |
    Add-AzureProvisioningConfig -Windows -Password $password -AdminUsername $admin_user |
    Set-AzureSubnet -SubnetNames $subnet | 
    Add-AzureDataDisk -ImportFrom -MediaLocation $storage_url -LUN 1 -DiskLabel "DATA"

New-AzureVM -VMs $vm -ServiceName $vm_name -AffinityGroup $vm_affinity  -VNetName $vm_affinity