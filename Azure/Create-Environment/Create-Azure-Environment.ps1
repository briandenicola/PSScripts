#requires -version 3.0
#requires -RunAsAdministrator

[CmdletBinding()]
param(
    [ValidateScript({Test-Path $_})]
    [Parameter(Mandatory=$true)][string] $config
)

Set-StrictMode -Version Latest 

#Import Modules
. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
Load-AzureModules

Import-Module -Name (Join-Path -Path $PWD.Path -ChildPath "Modules\Azure-BlobStorage-Functions.psm1")
Import-Module -Name (Join-Path -Path $PWD.Path -ChildPath "Modules\Azure-Miscellaneous-Functions.psm1")
Import-Module -Name (Join-Path -Path $PWD.Path -ChildPath "Modules\Azure-VirtualMachines-Functions.psm1")
Import-Module -Name (Join-Path -Path $PWD.Path -ChildPath "Modules\Azure-VNetwork-Functions.psm1")
Import-Module -Name (Join-Path -Path $PWD.Path -ChildPath "Modules\Azure-Automation-Functions.psm1")

#Get Configuration 
$cfg = [xml]( Get-Content -Path $config ) 

#Varibles
Set-Variable -Name log  -Value (Join-Path -Path $PWD.Path -ChildPath ("Logs\Azure-IaaS-Setup-for-{0}.{1}.log" -f $cfg.Azure.SubScription, $(Get-Date).ToString("yyyyMMddhhmmss")))

#Start Transcript...
try{Stop-Transcript|Out-Null} catch {}
Start-Transcript -Append -Path $log

#Set Error Action Perference to Stop
$ErrorActionPreference = "Stop"

#Setup Affinity Group
Write-Verbose -Message ("[{0}] - Calling New-AzureAffinityOrResourceGroup" -f $(Get-Date))
New-AzureAffinityOrResourceGroup -Name $cfg.Azure.AffinityGroup -Location $cfg.Azure.Location 

#Setup Storage
Write-Verbose -Message ("[{0}] - Calling New-AzureStorage" -f $(Get-Date))
New-AzureStorage -Name $cfg.Azure.BlobStorage -AffinityGroup $cfg.Azure.AffinityGroup

#Setup Virtual Network
$opts_network = @{
    Name           = $cfg.Azure.VNet.Name
    SubnetName     = $cfg.Azure.VNet.Subnet.Name
    AffinityGroup  = $cfg.Azure.AffinityGroup
    NetworkAddress = $cfg.Azure.VNet.AddressPrefix
    SubnetAddress  = $cfg.Azure.VNet.Subnet.AddressPrefix
    DNSName        = $cfg.Azure.VNet.DNSServer.Name
    DNSIP          = $cfg.Azure.VNet.DNSServer.IpAddress
}
Write-Verbose -Message ("[{0}] - Calling New-AzureVirtualNetwork - {1}" -f $(Get-Date), (Write-HashTableOutput -ht $opts_network))
New-AzureVirtualNetwork @opts_network

#Upload Script Extensions
$opts_uploads = @{
    StorageName   = $cfg.Azure.BlobStorage 
    ContainerName = $cfg.Azure.ScriptExtension.ContainerName
    Subscription  = $cfg.Azure.Subscription
    FilePaths     = @($cfg.Azure.ScriptExtension.Script | Select -Expand FilePath)
}
Write-Verbose -Message ("[{0}] - Calling Publish-AzureExtensionScriptstoStorage - {1}" -f $(Get-Date), (Write-HashTableOutput -ht $opts_uploads))
Publish-AzureExtensionScriptstoStorage @opts_uploads

#Create Azure VM for AD
if( $cfg.Azure.ActiveDirectory.Enabled -eq $true ) {
    $dc_data_drives = @(@{DriveSize=$cfg.Azure.ActiveDirectory.VM.DriveSize;DriveLabel=$cfg.Azure.ActiveDirectory.VM.DriveLabel})
    $dc_opts = @{
        Name            = $cfg.Azure.ActiveDirectory.VM.ComputerName
        Subscription    = $cfg.Azure.SubScription
        StorageAccount  = $cfg.Azure.BlobStorage
        CloudService    = $cfg.Azure.CloudService
        Size            = $cfg.Azure.ActiveDirectory.VM.VMSize
        OperatingSystem = $cfg.Azure.ActiveDirectory.VM.OS 
        AdminPassword   = $cfg.Azure.ActiveDirectory.Domain.DomainAdminPassword 
        AffinityGroup   = $cfg.Azure.AffinityGroup 
        IpAddress       = $cfg.Azure.ActiveDirectory.VM.IpAddress 
        DataDrives      = $dc_data_drives
        VNetName        = $cfg.Azure.VNet.Name
        SubnetName      = $cfg.Azure.VNet.Subnet.Name
    }
    Write-Verbose -Message ("[{0}] - Calling New-AzureVirtualMachine - {1}" -f $(Get-Date), (Write-HashTableOutput -ht $dc_opts))
    New-AzureVirtualMachine @dc_opts
    Wait-ForVMReadyState -CloudService $cfg.Azure.CloudService -VMName $cfg.Azure.ActiveDirectory.VM.ComputerName

    #Upgrade to Domain Controller
    Write-Verbose -Message ("[{0}] - Upgrading {1} to a domain controller" -f $(Get-Date), $cfg.Azure.ActiveDirectory.VM.ComputerName)
    $dc_promo_opts = @{
        ComputerName  = $cfg.Azure.ActiveDirectory.VM.ComputerName
        CloudService  = $cfg.Azure.CloudService
        user          = $cfg.Azure.ActiveDirectory.Domain.DomainAdminUser
        Password      = $cfg.Azure.ActiveDirectory.Domain.DomainAdminPassword
        ScriptPath    = $cfg.Azure.ActiveDirectory.ADCreateScript
        Arguments     = "E:", $cfg.Azure.ActiveDirectory.Domain.Name, $cfg.Azure.ActiveDirectory.Domain.NetBIOS, $cfg.Azure.ActiveDirectory.Domain.DomainAdminPassword
    }
    Write-Verbose -Message ("[{0}] - Calling Configuring VM with PowerShell Remoting - {1}" -f $(Get-Date), (Write-HashTableOutput -ht $dc_promo_opts))
    Invoke-AzurePSRemoting @dc_promo_opts
   
    Restart-AzureVM -ServiceName $cfg.Azure.CloudService -Name $cfg.Azure.ActiveDirectory.VM.ComputerName
    Wait-ForVMReadyState -CloudService $cfg.Azure.CloudService -VMName $cfg.Azure.ActiveDirectory.VM.ComputerName

    #Install a Domain Certificate Authority 
    if( $cfg.Azure.ActiveDirectory.CertificateAuthority.Enabled -eq $true ) {
        Write-Verbose -Message ("[{0}] - Installing Certificate Authority on {1}" -f $(Get-Date), $cfg.Azure.ActiveDirectory.VM.ComputerName)
        $cert_opts = @{
            ComputerName  = $cfg.Azure.ActiveDirectory.VM.ComputerName
            CloudService  = $cfg.Azure.CloudService
            user          = $cfg.Azure.ActiveDirectory.Domain.DomainAdminUser
            Password      = $cfg.Azure.ActiveDirectory.Domain.DomainAdminPassword
            ScriptPath    = $cfg.Azure.ActiveDirectory.CertificateAuthority.Script
            Arguments     = "E:", $cfg.Azure.ActiveDirectory.Domain.Name
        }
        Invoke-AzurePSRemoting @cert_opts
    }
}

#Create Azure VM for DSC
if( $cfg.Azure.DesireStateConfiguration.Enabled -eq $true ) {
    $dsc_drives = @(@{DriveSize=$cfg.Azure.DesireStateConfiguration.VM.DriveSize;DriveLabel=$cfg.Azure.DesireStateConfiguration.VM.DriveLabel})

    $dsc_opts = @{
        Name            = $cfg.Azure.DesireStateConfiguration.VM.ComputerName
        Subscription    = $cfg.Azure.SubScription
        StorageAccount  = $cfg.Azure.BlobStorage
        CloudService    = $cfg.Azure.CloudService
        Size            = $cfg.Azure.DesireStateConfiguration.VM.VMSize
        OperatingSystem = $cfg.Azure.DesireStateConfiguration.VM.OS 
        AdminUser       = $cfg.Azure.DesireStateConfiguration.VM.LocalAdminUser 
		AdminPassword   = $cfg.Azure.DesireStateConfiguration.VM.LocalAdminPassword
        AffinityGroup   = $cfg.Azure.AffinityGroup 
        DataDrives      = $dsc_drives
		DomainUser      = $cfg.Azure.ActiveDirectory.Domain.DomainAdminUser
		DomainPassword  = $cfg.Azure.ActiveDirectory.Domain.DomainAdminPassword
		Domain          = $cfg.Azure.ActiveDirectory.Domain.Name
        VNetName        = $cfg.Azure.VNet.Name
    }
    Write-Verbose -Message ("[{0}] - Calling New-AzureVirtualMachine - {1}" -f $(Get-Date), (Write-HashTableOutput -ht $dsc_opts))
    New-AzureVirtualMachine @dsc_opts

    Write-Verbose -Message ("[{0}] - Creating DNS Record for DSC Resource}" -f $(Get-Date))
    Invoke-Command -ConnectionUri $dc_uri -Credential $dc_creds -ScriptBlock {
        param( [string] $name, [string] $alias, [string] $zone) 
        Add-DnsServerResourceRecordCName -Name $name -HostNameAlias ("{0}.{1}" -f $alias, $zone) -ZoneName $zone
    } -ArgumentList $cfg.Azure.DesireStateConfiguration.DSC.DNS, $cfg.Azure.DesireStateConfiguration.VM.ComputerName, $cfg.Azure.ActiveDirectory.Domain.Name
    
    $publish_opts = @{
        ComputerName = $cfg.Azure.DesireStateConfiguration.VM.ComputerName
        CloudService = $cfg.Azure.CloudService 
        ModulePath   = $cfg.Azure.DesireStateConfiguration.PullServiceModule.Path 
        ScriptPath   = $cfg.Azure.DesireStateConfiguration.DSC.ConfigurationScript
    }
    Publish-AzureDSCScript @publish_opts
}

foreach( $machine in $cfg.Azure.MemberServers.Server ) {
    
    $opts = @{
        Name             = $machine.ComputerName
        Subscription     = $cfg.Azure.SubScription
        StorageAccount   = $cfg.Azure.BlobStorage
        CloudService     = $cfg.Azure.CloudService
        Size             = $machine.VMSize
        OperatingSystem  = $machine.OS 
        AdminUser        = $machine.LocalAdminUser 
		AdminPassword    = $machine.LocalAdminPassword
        AffinityGroup    = $cfg.Azure.AffinityGroup 
        DataDrives       = Convert-XMLToHashTable -xml $machine.Drives | Select -Expand Values
        EndPoints        = Convert-XMLToHashTable -xml $machine.Endpoints | Select -Expand Values
        VNetName         = $cfg.Azure.VNet.Name
    }

    if( $machine.JoinDomain -eq $true ) {
        $opts.Add("DomainUser", $cfg.Azure.ActiveDirectory.Domain.DomainAdminUser)
    	$opts.Add("DomainPassword", $cfg.Azure.ActiveDirectory.Domain.DomainAdminPassword)
		$opts.Add("Domain", $cfg.Azure.ActiveDirectory.Domain.Name)
    }
    Write-Verbose -Message ("[{0}] - Calling New-AzureVirtualMachine - {1}" -f $(Get-Date), (Write-HashTableOutput -ht $opts))
    New-AzureVirtualMachine @opts

    if( $machine.ScriptExtension.Required -eq $true ) {
        if( $machine.ScriptExtension.Type -eq "AzureDSC" ) {
            $publish_opts = @{
                ComputerName = $machine.ComputerName
                CloudService = $cfg.Azure.CloudService 
                ModulePath   = [string]::Empty
                ScriptPath   = $machine.ScriptExtension.Path
            }
            Write-Verbose -Message ("[{0}] - Calling Configuring VM with Azure DSC - {1}" -f $(Get-Date), (Write-HashTableOutput -ht $publish_opts))
            Publish-AzureDSCScript @publish_opts
        }
        elseif( $machine.ScriptExtension.Type -eq "DomainDSC" ) {
            $publish_opts = @{
                ComputerName  = $machine.ComputerName
                CloudService  = $cfg.Azure.CloudService
                DSCServer     = $cfg.Azure.DesireStateConfiguration.DSC.DNS
                user          = $machine.LocalAdminUser
                Password      = $machine.LocalAdminPassword
                ScriptPath    = $machine.ScriptExtension.Path
                Guid          = $machine.Guid  
            }
            Write-Verbose -Message ("[{0}] - Calling Configuring VM with Domain DSC - {1}" -f $(Get-Date), (Write-HashTableOutput -ht $publish_opts))
            Install-DSCDomainClient @publish_opts
        }
        elseif( $machine.ScriptExtension.Type -eq "Remoting" ) {
            $publish_opts = @{
                ComputerName  = $machine.ComputerName
                CloudService  = $cfg.Azure.CloudService
                user          = $machine.LocalAdminUser
                Password      = $machine.LocalAdminPassword
                ScriptPath    = $machine.ScriptExtension.Path
            }
            Write-Verbose -Message ("[{0}] - Calling Configuring VM with PowerShell Remoting - {1}" -f $(Get-Date), (Write-HashTableOutput -ht $publish_opts))
            Invoke-AzurePSRemoting @publish_opts
        }
    }
}

Stop-Transcript