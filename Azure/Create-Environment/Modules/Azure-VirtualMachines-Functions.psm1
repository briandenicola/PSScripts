#require -module Azure

. (Join-Path -Path $env:SCRIPTS_HOME -ChildPath "Libraries\Standard_Functions.ps1")
Load-AzureModules

function New-AzureVirtualMachine
{
    param(
        [Parameter(Mandatory=$true)][string] $Name,
        [Parameter(Mandatory=$true)][string] $CloudService,
        [Parameter(Mandatory=$true)][string] $Size,
        [Parameter(Mandatory=$true)][string] $OperatingSystem,
        [Parameter(Mandatory=$true)][string] $AdminUser = "Administrator",
        [Parameter(Mandatory=$true)][string] $AdminPassword,
        [Parameter(Mandatory=$true)][string] $SubnetName,
        [Parameter(Mandatory=$false)][string] $ScriptExtensionUri,
        [Parameter(Mandatory=$false)][System.Collections.Hashtable[]] $EndPoints,
        [Parameter(Mandatory=$false)][System.Collections.Hashtable[]] $DataDrives,
        [Parameter(ParameterSetName="JoinDomain",Mandatory=$true)][string] $DomainUser,
        [Parameter(ParameterSetName="JoinDomain",Mandatory=$true)][string] $DomainPassword
    )

    $image = Get-LatestAzureVMImageName -image_family_name $OperatingSystem

    $vm = New-AzureVMConfig -Name $Name -InstanceSize $Size -ImageName $image |
        Add-AzureProvisioningConfig -Windows -Password $AdminPassword -AdminUsername $AdminUser |
        Set-AzureSubnet -SubnetNames $SubnetName  
    
    foreach( $drive in $DataDrives ) {
        $vm | Add-AzureDataDisk -ImportFrom -MediaLocation $storage_url -LUN 1 -DiskLabel "DATA"
    }

    foreach( $drive in $DataDrives ) {
        $vm | Add-AzureDataDisk -ImportFrom -MediaLocation $storage_url -LUN 1 -DiskLabel "DATA"
    }
}

Export-ModuleMember -Function New-AzureVirtualMachine