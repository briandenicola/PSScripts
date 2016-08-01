#require -module Azure

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

    Write-Verbose -Message ("[{0}] - Creating Azure VM Config for {1} of {2} size using {3}." -f $(Get-Date), $Name, $Size, $Image )
    $vm = New-AzureVMConfig -Name $Name -InstanceSize $Size -ImageName $image
        
    switch ($PsCmdlet.ParameterSetName)
    { 
        "JoinDomain" {
            Write-Verbose -Message ("[{0}] - Updating configuration to join Azure VM {1} to {2} domain." -f $(Get-Date), $Name, $Domain )
            $vm | Add-AzureProvisioningConfig -WindowsDomain -Password $AdminPassword -AdminUsername $AdminUser -DomainPassword $DomainPassword -DomainUserName $DomainUser -JoinDomain $Domain -Domain $Domain
        }
        default {
            Write-Verbose -Message ("[{0}] - Updating configuration for stand alone Azure VM {1}." -f $(Get-Date), $Name )
            $vm | Add-AzureProvisioningConfig -Windows -Password $AdminPassword -AdminUsername $AdminUser 
        }
    }
   
    foreach( $drive in $DataDrives ) {
        Write-Verbose -Message ("[{0}] - Updating configuration for data drive - {1}." -f $(Get-Date), $drive.DriveLabel )
        $vm | Add-AzureDataDisk -CreateNew -DiskSizeInGB $drive.DriveSize -DiskLabel $drive.DriveLabel -LUN $lun
        $lun++
    }

    foreach( $endpoint in $EndPoints ) {
        Write-Verbose -Message ("[{0}] - Updating configuration for end point - {1} ({2}:{3}." -f $(Get-Date), $endpoint.Name, $endpoint.LocalPort, $endpoint.RemotePort )
        $vm | Add-AzureEndpoint -Name $endpoint.Name -LocalPort $endpoint.LocalPort -PublicPort $endpoint.RemotePort -Protocol TCP
    }

    Write-Verbose -Message ("[{0}] - Creating VM {1}." -f $(Get-Date), $Name )
    $vm | New-AzureVM -ServiceName $CloudService -AffinityGroup $AffinityGroup -VNetName $VNetName -WaitForBoot

    $vm = Get-azureVM -ServiceName $CloudService -Name $Name
    if( -not ( [string]::IsNullOrEmpty($ScriptExtensionUri) ) ) {
        Write-Verbose -Message ("[{0}] - Setting Custom Script Extension for VM {1} to {2}." -f $(Get-Date), $Name, $script_to_run )
        $vm | Set-AzureVMCustomScriptExtension -FileUri $ScriptExtensionUri.Replace("https://","http://") -Run $script_to_run -Argument $ScriptExtensionUriArguments  | Update-AzureVM
    }
    if( -not ( [string]::IsNullOrEmpty($IpAddress) ) ) {
        Write-Verbose -Message ("[{0}] - Setting VM {1} to Static IP {2}." -f $(Get-Date), $Name, $IpAddress )
        $vm | Set-AzureSubnet -SubnetNames $SubnetName | Update-AzureVM
        $vm | Set-AzureStaticVNetIP -IPAddress $IpAddress | Update-AzureVM
    }
}

Export-ModuleMember -Function New-AzureVirtualMachine