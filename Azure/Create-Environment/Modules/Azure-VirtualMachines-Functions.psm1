#require -module Azure

. (Join-Path -Path $env:SCRIPTS_HOME -ChildPath "Libraries\Standard_Functions.ps1")
Load-AzureModules

function New-AzureVirtualMachine
{
    param(
        [Parameter(Mandatory=$true)][string] $Name,
        [Parameter(Mandatory=$false)][string] $Subscription = $global:subscription,
        [Parameter(Mandatory=$true)][string] $CloudService,
        [Parameter(Mandatory=$true)][string] $StorageAccount,
        [Parameter(Mandatory=$true)][string] $Size,
        [Parameter(Mandatory=$true)][string] $OperatingSystem,
        [Parameter(Mandatory=$false)][string] $AdminUser = "manager",
        [Parameter(Mandatory=$true)][string] $AdminPassword,
        [Parameter(Mandatory=$true)][string] $AffinityGroup,
        [Parameter(Mandatory=$true)][string] $VNetName,
        [Parameter(Mandatory=$false)][string] $SubnetName,
        [Parameter(Mandatory=$false)][string] $IpAddress,
        [Parameter(Mandatory=$false)][string] $ScriptExtensionUri,
        [Parameter(Mandatory=$false)][string] $ScriptExtensionUriArguments,
        [Parameter(Mandatory=$false)][System.Collections.Hashtable[]] $EndPoints,
        [Parameter(Mandatory=$false)][System.Collections.Hashtable[]] $DataDrives,
        [Parameter(ParameterSetName="JoinDomain",Mandatory=$false)][string] $DomainUser,
        [Parameter(ParameterSetName="JoinDomain",Mandatory=$false)][string] $DomainPassword,
        [Parameter(ParameterSetName="JoinDomain",Mandatory=$false)][string] $Domain
    )

    Set-Variable -Name lun -Value 0
    Set-Variable -Name script_to_run -Value ($ScriptExtensionUri.Split("/") | Select -Last 1)
    Set-Variable -Name image -Value (Get-LatestAzureVMImageName -image_family_name $OperatingSystem)

    Set-AzureSubscription -SubscriptionName $Subscription -CurrentStorageAccountName $StorageAccount

    $vm = New-AzureVMConfig -Name $Name -InstanceSize $Size -ImageName $image
        
    switch ($PsCmdlet.ParameterSetName)
    { 
        "JoinDomain" {
            $vm | Add-AzureProvisioningConfig -Windows -Password $AdminPassword -AdminUsername $AdminUser -DomainPassword $DomainPassword -DomainUserName $DomainUser -JoinDomain $Domain
        }
        default {
            $vm | Add-AzureProvisioningConfig -Windows -Password $AdminPassword -AdminUsername $AdminUser 
        }
    }
   
    foreach( $drive in $DataDrives ) {
        $vm | Add-AzureDataDisk -CreateNew -DiskSizeInGB $drive.DriveSize -DiskLabel $drive.DriveLabel -LUN $lun
        $lun++
    }

    foreach( $endpoint in $EntPoints ) {
        $vm | Add-AzureEndpoint -Name $endpoint.Name -LocalPort $endpoint.LocalPort -PublicPort $endpoint.RemotePort -Protocol TCP
    }

    $vm | New-AzureVM -ServiceName $CloudService -AffinityGroup $AffinityGroup -VNetName $VNetName -WaitForBoot

    $vm = Get-azureVM -ServiceName $CloudService -Name $Name
    if( -not ( [string]::IsNullOrEmpty($ScriptExtensionUri) ) ) {
        $vm | Set-AzureVMCustomScriptExtension -FileUri $ScriptExtensionUri.Replace("https://","http://") -Run $script_to_run -Argument $ScriptExtensionUriArguments  | Update-AzureVM
    }
    if( -not ( [string]::IsNullOrEmpty($IpAddress) ) ) {
        $vm | Set-AzureSubnet -SubnetNames $SubnetName | Update-AzureVM
        $vm | Set-AzureStaticVNetIP -IPAddress $IpAddress | Update-AzureVM
    }
}

Export-ModuleMember -Function New-AzureVirtualMachine