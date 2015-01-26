#require -module Azure

Import-Module (Join-Path -Path $PWD.Path -ChildPath "Azure-Miscellaneous-Functions.psm1")

function New-AzureAffinityGroup
{
    param (
        [Parameter(Mandatory=$true)][string] $Name,
        [Parameter(Mandatory=$false)][string] $Location = "North Central US" 
    )

    Get-AzureAffinityGroup -Name $Name -ErrorAction SilentlyContinue
    if( $? ) {
        Write-Verbose -Message ("[{0}] - AffinityGroup - {1} - already exists. Skipping Creation." -f $(Get-Date), $Name)
    }
    else {
        Write-Verbose -Message ("[{0}] - Creating AffinityGroup - {1} " -f $(Get-Date), $Name)
        New-AzureAffinityGroup -Name $Name -Location $Location
    }
}

function New-AzureVirtualNetwork 
{
    param (
        [Parameter(Mandatory=$true)][string] $Name,
        [Parameter(Mandatory=$true)][string] $SubnetName,
        [Parameter(Mandatory=$true)][string] $AffinityGroup,
        [Parameter(Mandatory=$true)][string] $NetworkAddress, 
        [Parameter(Mandatory=$true)][string] $SubnetAddress,
        [Parameter(Mandatory=$true)][string] $DNSName,
        [Parameter(Mandatory=$true)][string] $DNSIP
    )
    
    $vnet_config = Join-Path -Path $ENV:TEMP -ChildPath ( [System.IO.Path]::GetRandomFileName() )
    Get-AzureVNetConfig -ExportToFile $vnet_config | Out-Null
    if (-not (Test-Path $vnet_config)) {
        Add-AzureVnetConfigurationFile -Path $vnet_config
    }
    
    Write-Verbose -Message ("[{0}] - Creating Virtual Network - {1} with IP Range - {2} and Subnet - {3} on {4} Affinity Group " -f $(Get-Date), $Name, $NetworkAddress, $SubnetAddress, $AffinityGroup  )
    Set-VNetFileValues -FilePath $vnet_config -VNet $Name -SubnetName $SubnetName -AffinityGroup $AffinityGroup -VNetAddressPrefix $NetworkAddress -SubnetAddressPrefix $SubnetAddress
    Set-AzureVNetConfig -ConfigurationPath $vnet_config 
    
    Add-AzureDnsServerConfiguration -Name $DNSName -IpAddress $DNSIp -VNetName $Name

    Remove-Item $vnet_config
}

Export-ModuleMember -Function New-AzureAffinityGroup