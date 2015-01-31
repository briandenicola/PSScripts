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

#Get Configuration 
$cfg = [xml]( Get-Content -Path $config ) 

#Varibles
Set-Variable -Name Modules -Value "$ENV:ProgramFiles\WindowsPowerShell\Modules" -Option Constant
Set-Variable -Name DSCMap  -Value (Join-Path -Path $PWD.Path -ChildPath ("DSC\Computer-To-Guid-Map.csv"))
Set-Variable -Name log     -Value (Join-Path -Path $PWD.Path -ChildPath ("Logs\Azure-IaaS-Setup-for-{0}.{1}.log" -f $cfg.Azure.SubScription, $(Get-Date).ToString("yyyyMMddhhmmss")))
Set-Variable -Name domain_script_block   -Value (Get-ScriptBlock -file $cfg.Azure.ActiveDirectory.ADCreateScript)
Set-Variable -Name certauth_script_block -Value (Get-ScriptBlock -file $cfg.Azure.ActiveDirectory.CertificateAuthority.Script)

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
    Name = $cfg.Azure.VNet.Name
    SubnetName = $cfg.Azure.VNet.Subnet.Name
    AffinityGroup = $cfg.Azure.AffinityGroup
    NetworkAddress = $cfg.Azure.VNet.AddressPrefix
    SubnetAddress = $cfg.Azure.VNet.Subnet.AddressPrefix
    DNSName  = $cfg.Azure.VNet.DNSServer.Name
    DNSIP = $cfg.Azure.VNet.DNSServer.IpAddress
}
Write-Verbose -Message ("[{0}] - Calling New-AzureVirtualNetwork - {1}" -f $(Get-Date), (Write-HashTableOutput -ht $opts_network))
New-AzureVirtualNetwork @opts_network

#Upload Script Extensions
$opts_uploads = @{
    StorageName = $cfg.Azure.BlobStorage 
    ContainerName = $cfg.Azure.ScriptExtension.ContainerName
    Subscription = $cfg.Azure.Subscription
    FilePaths = @($cfg.Azure.ScriptExtension.Script | Select -Expand FilePath)
}
Write-Verbose -Message ("[{0}] - Calling Publish-AzureExtensionScriptstoStorage - {1}" -f $(Get-Date), (Write-HashTableOutput -ht $opts_uploads))
Publish-AzureExtensionScriptstoStorage @opts_uploads

#Create Azure VM for AD
if( $cfg.Azure.ActiveDirectory.Enabled -eq $true ) {
    $dc_data_drives = @(@{DriveSize=$cfg.Azure.ActiveDirectory.VM.DriveSize;DriveLabel=$cfg.Azure.ActiveDirectory.VM.DriveLabel})
    $dc_opts = @{
        Name = $cfg.Azure.ActiveDirectory.VM.ComputerName
        Subscription = $cfg.Azure.SubScription
        StorageAccount = $cfg.Azure.BlobStorage
        CloudService = $cfg.Azure.CloudService
        Size = $cfg.Azure.ActiveDirectory.VM.VMSize
        OperatingSystem = $cfg.Azure.ActiveDirectory.VM.OS 
        AdminPassword = $cfg.Azure.ActiveDirectory.Domain.DomainAdminPassword 
        AffinityGroup = $cfg.Azure.AffinityGroup 
        IpAddress = $cfg.Azure.ActiveDirectory.VM.IpAddress 
        DataDrives = $dc_data_drives
        VNetName = $cfg.Azure.VNet.Name
        SubnetName = $cfg.Azure.VNet.Subnet.Name
    }
    Write-Verbose -Message ("[{0}] - Calling New-AzureVirtualMachine - {1}" -f $(Get-Date), (Write-HashTableOutput -ht $dc_opts))
    New-AzureVirtualMachine @dc_opts
    Wait-ForVMReadyState -CloudService $cfg.Azure.CloudService -VMName $cfg.Azure.ActiveDirectory.VM.ComputerName

    #Upgrade to Domain Controller
    Write-Verbose -Message ("[{0}] - Upgrading {1} to a domain controller" -f $(Get-Date), $cfg.Azure.ActiveDirectory.VM.ComputerName)
    Install-WinRmCertificate -service $cfg.Azure.CloudService -vm_name $cfg.Azure.ActiveDirectory.VM.ComputerName
    $dc_uri = Get-AzureWinRMUri -ServiceName $cfg.Azure.CloudService -Name $cfg.Azure.ActiveDirectory.VM.ComputerName
    $dc_secpasswd = ConvertTo-SecureString -String $cfg.Azure.ActiveDirectory.Domain.DomainAdminPassword -AsPlainText -Force
    $dc_creds = New-Object System.Management.Automation.PSCredential ( $cfg.Azure.ActiveDirectory.Domain.DomainAdminUser, $dc_secpasswd )
        
    Invoke-Command -ConnectionUri $dc_uri -Credential $dc_creds -ScriptBlock $domain_script_block `
        -ArgumentList "E:", $cfg.Azure.ActiveDirectory.Domain.Name, $cfg.Azure.ActiveDirectory.Domain.NetBIOS, $cfg.Azure.ActiveDirectory.Domain.DomainAdminPassword
    
    Restart-AzureVM -ServiceName $cfg.Azure.CloudService -Name $cfg.Azure.ActiveDirectory.VM.ComputerName
    Wait-ForVMReadyState -CloudService $cfg.Azure.CloudService -VMName $cfg.Azure.ActiveDirectory.VM.ComputerName

    if( $cfg.Azure.ActiveDirectory.CertificateAuthorityScript.Enabled -eq $true ) {
        Write-Verbose -Message ("[{0}] - Installing Certificate Authority on {1}" -f $(Get-Date), $cfg.Azure.ActiveDirectory.VM.ComputerName)
        Invoke-Command -ConnectionUri $dc_uri -Credential $dc_creds -ScriptBlock $certauth_script_block -ArgumentList "E:", $cfg.Azure.ActiveDirectory.Domain.Name
    }
}

#Create Azure VM for DSC
if( $cfg.Azure.DesireStateConfiguration.Enabled -eq $true ) {
    $dsc_drives = @(@{DriveSize=$cfg.Azure.DesireStateConfiguration.VM.DriveSize;DriveLabel=$cfg.Azure.DesireStateConfiguration.VM.DriveLabel})

    $dsc_opts = @{
        Name = $cfg.Azure.DesireStateConfiguration.VM.ComputerName
        Subscription = $cfg.Azure.SubScription
        StorageAccount = $cfg.Azure.BlobStorage
        CloudService = $cfg.Azure.CloudService
        Size = $cfg.Azure.DesireStateConfiguration.VM.VMSize
        OperatingSystem = $cfg.Azure.DesireStateConfiguration.VM.OS 
        AdminUser = $cfg.Azure.DesireStateConfiguration.VM.LocalAdminUser 
		AdminPassword = $cfg.Azure.DesireStateConfiguration.VM.LocalAdminPassword
        AffinityGroup = $cfg.Azure.AffinityGroup 
        DataDrives = $dsc_drives
		DomainUser = $cfg.Azure.ActiveDirectory.Domain.DomainAdminUser
		DomainPassword = $cfg.Azure.ActiveDirectory.Domain.DomainAdminPassword
		Domain = $cfg.Azure.ActiveDirectory.Domain.Name
        VNetName = $cfg.Azure.VNet.Name
    }
    Write-Verbose -Message ("[{0}] - Calling New-AzureVirtualMachine - {1}" -f $(Get-Date), (Write-HashTableOutput -ht $dsc_opts))
    New-AzureVirtualMachine @dsc_opts

    Write-Verbose -Message ("[{0}] - Creating DNS Record for DSC Resource}" -f $(Get-Date))
    Invoke-Command -ConnectionUri $dc_uri -Credential $dc_creds -ScriptBlock {
        param( [string] $name, [string] $alias, [string] $zone) 
        Add-DnsServerResourceRecordCName -Name $name -HostNameAlias ("{0}.{1}" -f $alias, $zone) -ZoneName $zone
    } -ArgumentList $cfg.Azure.DesireStateConfiguration.DSC.DNS, $cfg.Azure.DesireStateConfiguration.VM.ComputerName, $cfg.Azure.ActiveDirectory.Domain.Name
    
    Write-Verbose -Message ("[{0}] - Publishing DSC Configuration {1} for {2}" -f $(Get-Date), $cfg.Azure.DesireStateConfiguration.DSC.ConfigurationScript, $cfg.Azure.DesireStateConfiguration.VM.ComputerName)
    Get-ChildItem -Path $cfg.Azure.DesireStateConfiguration.PullServiceModule.Path | 
        Foreach { Copy-Item $_.FullName -Destination $Modules -Recurse -ErrorAction SilentlyContinue }
    
    Publish-AzureVMDscConfiguration -ConfigurationPath $cfg.Azure.DesireStateConfiguration.DSC.ConfigurationScript

    $vm = Get-AzureVM -ServiceName $cfg.Azure.CloudService -Name $cfg.Azure.DesireStateConfiguration.VM.ComputerName
    $vm | Set-AzureVMDscExtension -ConfigurationArchive ("{0}.ps1.zip" -f $cfg.Azure.DesireStateConfiguration.DSC.ConfigurationName ) -ConfigurationName $cfg.Azure.DesireStateConfiguration.DSC.ConfigurationName | 
        Update-AzureVM

    Wait-ForVMReadyState -CloudService $cfg.Azure.CloudService -VMName $cfg.Azure.DesireStateConfiguration.VM.ComputerName
}

foreach( $machine in $cfg.Azure.MemberServers.Server ) {
    
    $opts = @{
        Name = $machine.ComputerName
        Subscription = $cfg.Azure.SubScription
        StorageAccount = $cfg.Azure.BlobStorage
        CloudService = $cfg.Azure.CloudService
        Size = $machine.VMSize
        OperatingSystem = $machine.OS 
        AdminUser = $machine.LocalAdminUser 
		AdminPassword = $machine.LocalAdminPassword
        AffinityGroup = $cfg.Azure.AffinityGroup 
        DataDrives = Convert-XMLToHashTable -xml $machine.Drives | Select -Expand Values
        EndPoints = Convert-XMLToHashTable -xml $machine.Endpoints | Select -Expand Values
        VNetName = $cfg.Azure.VNet.Name
    }

    if( $machine.JoinDomain -eq $true ) {
        $opts.Add("DomainUser", $cfg.Azure.ActiveDirectory.Domain.DomainAdminUser)
    	$opts.Add("DomainPassword", $cfg.Azure.ActiveDirectory.Domain.DomainAdminPassword)
		$opts.Add("Domain", $cfg.Azure.ActiveDirectory.Domain.Name)
    }
    Write-Verbose -Message ("[{0}] - Calling New-AzureVirtualMachine - {1}" -f $(Get-Date), (Write-HashTableOutput -ht $opts))
    New-AzureVirtualMachine @opts

    if( $machine.DSCEnabled -eq $true ) {
        $dsc =  $cfg.Azure.DesireStateConfiguration.DSC.DNS

        Install-WinRmCertificate -service $cfg.Azure.CloudService -vm_name $machine.ComputerName
        $uri = Get-AzureWinRMUri  -ServiceName $cfg.Azure.CloudService -Name $machine.ComputerName
        $secpasswd = ConvertTo-SecureString -String $cfg.Azure.ActiveDirectory.Domain.DomainAdminPassword -AsPlainText -Force
        $creds = New-Object System.Management.Automation.PSCredential ( $cfg.Azure.ActiveDirectory.Domain.DomainAdminUser, $secpasswd )

        if( [string]::IsNullOrEmpty($machine.Guid) ) {
            $guid = [GUID]::NewGuid() | Select -Expand Guid
        } 
        else {
            $guid = $machine.Guid
        }
    
        Write-Verbose -Message ("[{0}] - Configuring DSC for {1} using GUID - {2}" -f $(Get-Date), $machine.ComputerName, $guid)       
        Invoke-Command -ConnectionUri $uri -Credential $creds -ScriptBlock (Get-ScriptBlock -file $machine.ScriptExtension) -ArgumentList $dsc, $guid
        Wait-ForVMReadyState -CloudService $cfg.Azure.CloudService -VMName $machine.ComputerName

        Add-Content -Encoding Ascii -Path $DSCMap -Value ( "{0},{1}" -f $machine.ComputerName, $guid )
    }
}

Stop-Transcript