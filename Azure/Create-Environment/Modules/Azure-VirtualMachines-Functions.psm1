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
        [Parameter(Mandatory=$true)][string] $AffinityGroup,
        [Parameter(Mandatory=$false)][string] $ScriptExtensionUri,
        [Parameter(Mandatory=$false)][System.Collections.Hashtable[]] $EndPoints,
        [Parameter(Mandatory=$false)][System.Collections.Hashtable[]] $DataDrives,
        [Parameter(ParameterSetName="JoinDomain",Mandatory=$true)][string] $DomainUser,
        [Parameter(ParameterSetName="JoinDomain",Mandatory=$true)][string] $DomainPassword,
        [Parameter(ParameterSetName="JoinDomain",Mandatory=$true)][string] $Domain
    )

    Set-Variable -Name lun -Value 0
    Set-Variable -Name script_to_run -Value ($ScriptExtensionUri.Split("/") | Select -Last 1)
    Set-Variable -Name image -Value (Get-LatestAzureVMImageName -image_family_name $OperatingSystem)

    $vm = New-AzureVMConfig -Name $Name -InstanceSize $Size -ImageName $image | Set-AzureSubnet -SubnetNames $SubnetName  
        
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
        $vm | Add-AzureDataDisk -CreateNew -DiskSizeInGB $drive.DriveSize -DiskLabel $drive.DriveLabel -LUN $lun++
    }

    foreach( $endpoint in $EntPoints ) {
        $vm | Add-AzureEndpoint -Name $endpoint.Name -LocalPort $endpoint.LocalPort -PublicPort $endpoint.RemotePort -Protocol TCP
    }

    $vm | New-AzureVM -ServiceName $CloudService -AffinityGroup $AffinityGroup -WaitForBoot
    $vm | Set-AzureVMCustomScriptExtension -FileUri $ScriptExtensionUri -Run $script_to_run | Update-AzureVM
}

Export-ModuleMember -Function New-AzureVirtualMachine