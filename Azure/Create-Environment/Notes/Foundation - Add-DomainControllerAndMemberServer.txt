<#
.Synopsis
   Add a domain cotroller and a member server to a cloud service.
.DESCRIPTION
   This script demonstrates how to add a VM and script it to become a domain controller for a new forest, and add a member 
   server to the domain, by adding them on the same VNet. A new VNet is created for the deployment, if a VNet site 
   with the same name exists, the script does not continue.
.EXAMPLE
    Using all of the required parameters

   .\Add-DomainControllerAndMemberServer.ps1 -ServiceName AService -Location "West US" -DomainControllerName dc `
        -MemberServerName mem -DomainName "contoso" -TopLevelDomain "com" -VNetName "dcvnet"

    Using all of the parameters including the optional VNet details and VM sizes

    .\Add-DomainControllerAndMemberServer.ps1 -ServiceName AService -Location "West US" -DomainControllerName dc -DCVMSize "Medium" `
        -MemberServerName mem -MemberVMSize "Medium" -DomainName "contoso" -TopLevelDomain "com" -VNetName "dcvnet" `
        -VNetAddressPrefix "10.0.0.0/16" -SubnetName "Subnet-10" -SubnetAddressPrefix "10.0.10.0/24"

.INPUTS
   None
.OUTPUTS
   None
#>
Param
(
    # Service name to deploy to
    [Parameter(Mandatory=$true)]
    [String]
    $ServiceName,

    # Location of the service
    [Parameter(Mandatory=$true)]
    [String]
    $Location,

    # Name of the DC
    [Parameter(Mandatory=$true)]
    [String]
    $DomainControllerName,    

    # VM Size for the DC
    [Parameter(Mandatory=$false)]
    [ValidateSet("ExtraSmall","Small","Medium","Large","ExtraLarge","A6","A7")]
    [String]
    $DCVMSize = "Small",    

    # Name of the member server
    [Parameter(Mandatory=$true)]
    [String]
    $MemberServerName,

    # VM Size for the member server
    [Parameter(Mandatory=$false)]
    [ValidateSet("ExtraSmall","Small","Medium","Large","ExtraLarge","A6","A7")]
    [String]
    $MemberVMSize = "Small",    

    # Domain name for the forest
    [Parameter(Mandatory=$true)]
    [String]
    $DomainName,

    # Top level domain for the forest
    [Parameter(Mandatory=$true)]
    [String]
    $TopLevelDomain,

    # Name of the VNet to be used
    [Parameter(Mandatory=$true)]
    [String]
    $VNetName,

     #VNet address prefix for the VNet. For the sake of examples in this scripts, the smallest address space possible for Azure is default
    [Parameter(Mandatory=$false)]
    [String]
    $VNetAddressPrefix = "10.0.0.0/16", 

    # Name of the subnet to be used
    [Parameter(Mandatory=$false)]
    [String]
    $SubnetName = "Subnet-10",

    # Addres space for the Subnet
    [Parameter(Mandatory=$false)]
    [String]
    $SubnetAddressPrefix = "10.0.0.0/24"
)

# The script has been tested on Powershell 3.0
Set-StrictMode -Version 3

# Following modifies the Write-Verbose behavior to turn the messages on globally for this session
$VerbosePreference = "Continue"

# Check if Windows Azure Powershell is avaiable
if ((Get-Module -ListAvailable Azure) -eq $null)
{
    throw "Windows Azure Powershell not found! Please install from http://www.windowsazure.com/en-us/downloads/#cmd-line-tools"
}

<#
.SYNOPSIS
    Adds a new affinity group if it does not exist.
.DESCRIPTION
   Looks up the current subscription's (as set by Set-AzureSubscription cmdlet) affinity groups and creates a new
   affinity group if it does not exist.
.EXAMPLE
   New-AzureAffinityGroupIfNotExists -AffinityGroupNme newAffinityGroup -Location "West US"
.INPUTS
   None
.OUTPUTS
   None
#>
function New-AzureAffinityGroupIfNotExists
{
    param
    (
        # Name of the affinity group
        [Parameter(Mandatory = $true)]
        [String]
        $AffinityGroupName,
        
        # Location where the affinity group will be pointing to
        [Parameter(Mandatory = $true)]
        [String]
        $Location)
    
    $affinityGroup = Get-AzureAffinityGroup -Name $AffinityGroupName -ErrorAction SilentlyContinue
    if ($affinityGroup -eq $null)
    {
        New-AzureAffinityGroup -Name $AffinityGroupName -Location $Location -Label $AffinityGroupName `
        -ErrorVariable lastError -ErrorAction SilentlyContinue | Out-Null
        if (!($?))
        {
            throw "Cannot create the affinity group $AffinityGroupName on $Location"
        }
        Write-Verbose "Created affinity group $AffinityGroupName"
    }
    else
    {
        if ($affinityGroup.Location -ne $Location)
        {
            Write-Warning "Affinity group with name $AffinityGroupName already exists but in location `
            $affinityGroup.Location, not in $Location"
        }
    }
}

<#
.Synopsis
   Create an empty VNet configuration file.
.DESCRIPTION
   Create an empty VNet configuration file.
.EXAMPLE
    Add-AzureVnetConfigurationFile -Path c:\temp\vnet.xml
.INPUTS
   None
.OUTPUTS
   None
#>
function Add-AzureVnetConfigurationFile
{
    param ([String] $Path)
    
    $configFileContent = [Xml] "<?xml version=""1.0"" encoding=""utf-8""?>
    <NetworkConfiguration xmlns:xsd=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xmlns=""http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration"">
              <VirtualNetworkConfiguration>
                <Dns />
                <VirtualNetworkSites/>
              </VirtualNetworkConfiguration>
            </NetworkConfiguration>"
    
    $configFileContent.Save($Path)
}

<#
.SYNOPSIS
   Sets the provided values in the VNet file of a subscription's VNet file 
.DESCRIPTION
   It sets the VNetName and AffinityGroup of a given subscription's VNEt configuration file.
.EXAMPLE
    Set-VNetFileValues -FilePath c:\temp\servvnet.xml -VNet testvnet -AffinityGroupName affinityGroup1
.INPUTS
   None
.OUTPUTS
   None
#>
function Set-VNetFileValues
{
    [CmdletBinding()]
    param (
        
        # The path to the exported VNet file
        [String]$FilePath, 
        
        # Name of the new VNet site
        [String]$VNet, 
        
        # The affinity group the new Vnet site will be associated with
        [String]$AffinityGroupName, 
        
        # Address prefix for the Vnet.
        [String]$VNetAddressPrefix, 
        
        # The name of the subnet to be added to the Vnet
        [String] $SubnetName, 
        
        # Addres space for the Subnet
        [String] $SubnetAddressPrefix)
    
    [Xml]$xml = New-Object XML
    $xml.Load($FilePath)
    
    $vnetSiteNodes = $xml.GetElementsByTagName("VirtualNetworkSite")
    
    $foundVirtualNetworkSite = $null
    if ($vnetSiteNodes -ne $null)
    {
        $foundVirtualNetworkSite = $vnetSiteNodes | Where-Object { $_.name -eq $VNet }
    }

    if ($foundVirtualNetworkSite -ne $null)
    {
        $foundVirtualNetworkSite.AffinityGroup = $AffinityGroupName
    }
    else
    {
        $virtualNetworkSites = $xml.NetworkConfiguration.VirtualNetworkConfiguration.GetElementsByTagName("VirtualNetworkSites")
        if ($null -ne $virtualNetworkSites)
        {
            
            $virtualNetworkElement = $xml.CreateElement("VirtualNetworkSite", "http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration")
            
            $vNetSiteNameAttribute = $xml.CreateAttribute("name")
            $vNetSiteNameAttribute.InnerText = $VNet
            $virtualNetworkElement.Attributes.Append($vNetSiteNameAttribute) | Out-Null
            
            $affinityGroupAttribute = $xml.CreateAttribute("AffinityGroup")
            $affinityGroupAttribute.InnerText = $AffinityGroupName
            $virtualNetworkElement.Attributes.Append($affinityGroupAttribute) | Out-Null
            
            $addressSpaceElement = $xml.CreateElement("AddressSpace", "http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration")            
            $addressPrefixElement = $xml.CreateElement("AddressPrefix", "http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration")
            $addressPrefixElement.InnerText = $VNetAddressPrefix
            $addressSpaceElement.AppendChild($addressPrefixElement) | Out-Null
            $virtualNetworkElement.AppendChild($addressSpaceElement) | Out-Null
            
            $subnetsElement = $xml.CreateElement("Subnets", "http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration")
            $subnetElement = $xml.CreateElement("Subnet", "http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration")
            $subnetNameAttribute = $xml.CreateAttribute("name")
            $subnetNameAttribute.InnerText = $SubnetName
            $subnetElement.Attributes.Append($subnetNameAttribute) | Out-Null
            $subnetAddressPrefixElement = $xml.CreateElement("AddressPrefix", "http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration")
            $subnetAddressPrefixElement.InnerText = $SubnetAddressPrefix
            $subnetElement.AppendChild($subnetAddressPrefixElement) | Out-Null
            $subnetsElement.AppendChild($subnetElement) | Out-Null
            $virtualNetworkElement.AppendChild($subnetsElement) | Out-Null
            
            $virtualNetworkSites.AppendChild($virtualNetworkElement) | Out-Null
        }
        else
        {
            throw "Can't find 'VirtualNetworkSite' tag"
        }
    }
    
    $xml.Save($filePath)
}

<#
.SYNOPSIS
   Creates a Virtual Network Site if it does not exist and sets the subnet details.
.DESCRIPTION
   Creates the VNet site if it does not exist. It first downloads the neetwork configuration for the subscription.
   If there is no network configuration, it creates an empty one first using the Add-AzureVnetConfigurationFile helper
   function, then updates the network file with the provided Vnet settings also by adding the subnet.
.EXAMPLE
   New-VNetSite -VNetName testVnet -SubnetName mongoSubnet -AffinityGroupName mongoAffinity
#>
function New-VNetSite
{
    [CmdletBinding()]
    param
    (
        
        # Name of the Vnet site
        [Parameter(Mandatory = $true)]
        [String]
        $VNetName,
        
        # Name of the subnet
        [Parameter(Mandatory = $true)]
        [String]
        $SubnetName,
        
        # THe affinity group the vnet will be associated with
        [Parameter(Mandatory = $true)]
        [String]
        $AffinityGroupName,
        
        # Address prefix for the Vnet. 
        [String]$VNetAddressPrefix, 
        
        # Addres space for the Subnet
        [String] $SubnetAddressPrefix)
    
    $vNetFilePath = "$env:temp\$AffinityGroupName" + "vnet.xml"
    Get-AzureVNetConfig -ExportToFile $vNetFilePath | Out-Null
    if (!(Test-Path $vNetFilePath))
    {
        Add-AzureVnetConfigurationFile -Path $vNetFilePath
    }
    
    Set-VNetFileValues -FilePath $vNetFilePath -VNet $VNetName -SubnetName $SubnetName -AffinityGroup $AffinityGroupName -VNetAddressPrefix $VNetAddressPrefix -SubnetAddressPrefix $SubnetAddressPrefix
    Set-AzureVNetConfig -ConfigurationPath $vNetFilePath -ErrorAction SilentlyContinue -ErrorVariable errorVariable | Out-Null
    if (!($?))
    {
        throw "Cannot set the vnet configuration for the subscription, please see the file $vNetFilePath. Error detail is: $errorVariable"
    }
    Write-Verbose "Modified and saved the VNET Configuration for the subscription"
    
    Remove-Item $vNetFilePath
}

<#
.SYNOPSIS
   Modifies the virtual network configuration xml file to include a DNS service reference.
.DESCRIPTION
   This a small utility that programmatically modifies the vnet configuration file to add a DNS server
   then adds the DNS server's reference to the specified VNet site.
.EXAMPLE
    Add-AzureDnsServerConfiguration -Name "contoso" -IpAddress "10.0.0.4" -VNetName "dcvnet"
.INPUTS
   None
.OUTPUTS
   None
#>


function Add-AzureDnsServerConfiguration
{
   param
    (
        [String]
        $Name,

        [String]
        $IpAddress,

        [String]
        $VNetName
    )

    $vNet = Get-AzureVNetSite -VNetName $VNetName -ErrorAction SilentlyContinue
    if ($vNet -eq $null)
    {
        throw "VNetSite $VNetName does not exist. Cannot add DNS server reference."
    }

    $vnetFilePath = "$env:temp\$AffinityGroupName" + "vnet.xml"
    Get-AzureVNetConfig -ExportToFile $vnetFilePath | Out-Null
    if (!(Test-Path $vNetFilePath))
    {
        throw "Cannot retrieve the vnet configuration file."
    }

    [Xml]$xml = New-Object XML
    $xml.Load($vnetFilePath)

    $dns = $xml.NetworkConfiguration.VirtualNetworkConfiguration.Dns
    if ($dns -eq $null)
    {
        $dns = $xml.CreateElement("Dns", "http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration")
        $xml.NetworkConfiguration.VirtualNetworkConfiguration.AppendChild($dns) | Out-Null
    }

    # Dns node is returned as an empy element, and in Powershell 3.0 the empty elements are returned as a string with dot notation
    # use Select-Xml instead to bring it in.
    # When using the default namespace in Select-Xml cmdlet, an arbitrary namespace name is used (because there is no name
    # after xmlns:)
    $namespace = @{network="http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration"}
    $dnsNode = select-xml -xml $xml -XPath "//network:Dns" -Namespace $namespace
    $dnsElement = $null

    # In case the returning node is empty, let's create it
    if ($dnsNode -eq $null)
    {
        $dnsElement = $xml.CreateElement("Dns", "http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration")
        $xml.NetworkConfiguration.VirtualNetworkConfiguration.AppendChild($dnsElement)
    }
    else
    {
        $dnsElement = $dnsNode.Node
    }

    $dnsServersNode = select-xml -xml $xml -XPath "//network:DnsServers" -Namespace $namespace
    $dnsServersElement = $null

    if ($dnsServersNode -eq $null)
    {
        $dnsServersElement = $xml.CreateElement("DnsServers", "http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration")
        $dnsElement.AppendChild($dnsServersElement) | Out-Null
    }
    else
    {
        $dnsServersElement = $dnsServersNode.Node
    }

    $dnsServersElements = $xml.GetElementsByTagName("DnsServer")
    $dnsServerElement = $dnsServersElements | Where-Object {$_.name -eq $Name}
    if ($dnsServerElement -ne $null)
    {
        $dnsServerElement.IpAddress = $IpAddress
    }
    else
    {
        $dnsServerElement = $xml.CreateElement("DnsServer", "http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration")
        $nameAttribute = $xml.CreateAttribute("name")
        $nameAttribute.InnerText = $Name
        $dnsServerElement.Attributes.Append($nameAttribute) | Out-Null
        $ipAddressAttribute = $xml.CreateAttribute("IPAddress")
        $ipAddressAttribute.InnerText = $IpAddress
        $dnsServerElement.Attributes.Append($ipAddressAttribute) | Out-Null
        $dnsServersElement.AppendChild($dnsServerElement) | Out-Null
    }

    # Now set the DnsReference for the network site
    $xpathQuery = "//network:VirtualNetworkSite[@name = '" + $VNetName + "']"
    $foundVirtualNetworkSite = select-xml -xml $xml -XPath $xpathQuery -Namespace $namespace 

    if ($foundVirtualNetworkSite -eq $null)
    {
        throw "Cannot find the VNet $VNetName"
    }

    $dnsServersRefElementNode = $foundVirtualNetworkSite.Node.GetElementsByTagName("DnsServersRef")

    $dnsServersRefElement = $null
    if ($dnsServersRefElementNode.Count -eq 0)
    {
        $dnsServersRefElement = $xml.CreateElement("DnsServersRef", "http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration")
        $foundVirtualNetworkSite.Node.AppendChild($dnsServersRefElement) | Out-Null
    }
    else
    {
        $dnsServersRefElement = $foundVirtualNetworkSite.DnsServersRef
    }
    
    $xpathQuery = "/DnsServerRef[@name = '" + $Name + "']"
    $dnsServerRef = $dnsServersRefElement.SelectNodes($xpathQuery)
    $dnsServerRefElement = $null

    if($dnsServerRef.Count -eq 0)
    {
        $dnsServerRefElement = $xml.CreateElement("DnsServerRef", "http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration")        
        $dnsServerRefNameAttribute = $xml.CreateAttribute("name")
        $dnsServerRefElement.Attributes.Append($dnsServerRefNameAttribute) | Out-Null
        $dnsServersRefElement.AppendChild($dnsServerRefElement) | Out-Null
    }

    if ($dnsServerRefElement -eq $null)
    {
        throw "No DnsServerRef element is found"
    }    

    $dnsServerRefElement.name = $name

    $xml.Save($vnetFilePath)
    Set-AzureVNetConfig -ConfigurationPath $vnetFilePath
}

<#
.SYNOPSIS
  Returns the latest image for a given image family name filter.
.DESCRIPTION
  Will return the latest image based on a filter match on the ImageFamilyName and
  PublisedDate of the image.  The more specific the filter, the more control you have
  over the object returned.
.EXAMPLE
  The following example will return the latest SQL Server image.  It could be SQL Server
  2014, 2012 or 2008
    
    Get-LatestImage -ImageFamilyNameFilter "*SQL Server*"

  The following example will return the latest SQL Server 2014 image. This function will
  also only select the image from images published by Microsoft.  
   
    Get-LatestImage -ImageFamilyNameFilter "*SQL Server 2014*" -OnlyMicrosoftImages

  The following example will return $null because Microsoft doesn't publish Ubuntu images.
   
    Get-LatestImage -ImageFamilyNameFilter "*Ubuntu*" -OnlyMicrosoftImages
#>
function Get-LatestImage
{
    param
    (
        # A filter for selecting the image family.
        # For example, "Windows Server 2012*", "*2012 Datacenter*", "*SQL*, "Sharepoint*"
        [Parameter(Mandatory = $true)]
        [String]
        $ImageFamilyNameFilter,

        # A switch to indicate whether or not to select the latest image where the publisher is Microsoft.
        # If this switch is not specified, then images from all possible publishers are considered.
        [Parameter(Mandatory = $false)]
        [switch]
        $OnlyMicrosoftImages
    )

    # Get a list of all available images.
    $imageList = Get-AzureVMImage
    
    if ($OnlyMicrosoftImages.IsPresent)
    {
        $imageList = $imageList |
                         Where-Object { `
                             ($_.PublisherName -ilike "Microsoft*" -and `
                              $_.ImageFamily -ilike $ImageFamilyNameFilter ) }
    }
    else
    {
        $imageList = $imageList |
                         Where-Object { `
                             ($_.ImageFamily -ilike $ImageFamilyNameFilter ) } 
    }

    $imageList = $imageList | 
                     Sort-Object -Unique -Descending -Property ImageFamily |
                     Sort-Object -Descending -Property PublishedDate

    $imageList | Select-Object -First(1)
}

<#
.SYNOPSIS
   Installs a WinRm certificate to the local store.
.DESCRIPTION
   Gets the WinRM certificate from the Virtual Machine deployed to the specified cloud service, and 
   installs it on the Current User's personal store. The WinRm certificate is stored on the cloud service 
   that hosts the VM, and can be retrieved with Get-AzureCertificate cmdlet. The certificate is used for
   authenticating the service. 
.EXAMPLE
    Install-WinRmCertificate -ServiceName testservice -vmName testVm
.INPUTS
   None
.OUTPUTS
   None
#>
function Install-WinRmCertificate($ServiceName, $VMName)
{
    $vm = Get-AzureVM -ServiceName $ServiceName -Name $VMName
    # Find the thumbprint used for the WinRM access
    $winRmCertificateThumbprint = $vm.VM.DefaultWinRMCertificateThumbprint
    
    # Retrieve the certificate
    $winRmCertificate = Get-AzureCertificate -ServiceName $ServiceName -Thumbprint $winRmCertificateThumbprint -ThumbprintAlgorithm sha1
    
    $installedCert = Get-Item Cert:\CurrentUser\My\$winRmCertificateThumbprint -ErrorAction SilentlyContinue
    
    if ($installedCert -eq $null)
    {
        # Read in the certificate to a memory buffer to import it to a X509 certificate object.
        $certBytes = [System.Convert]::FromBase64String($winRmCertificate.Data)
        $x509Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate
        $x509Cert.Import($certBytes)
        
        # Add the X509 certificate to the store.
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store "Root", "LocalMachine"
        $store.Open("ReadWrite")
        $store.Add($x509Cert)
        $store.Close()
    }
}

# Check if the current subscription's storage account's location is the same as the Location parameter
$subscription = Get-AzureSubscription -Current
$currentStorageAccountLocation = (Get-AzureStorageAccount -StorageAccountName $subscription.CurrentStorageAccount).GeoPrimaryLocation

if ($Location -ne $currentStorageAccountLocation)
{
    throw "Selected location parameter value, ""$Location"" is not the same as the active (current) subscription's current storage account location `
        ($currentStorageAccountLocation). Either change the location parameter value, or select a different storage account for the `
        subscription."
}

# Test if the service name has already been taken
$existingService = Get-AzureService -ServiceName $ServiceName -ErrorAction SilentlyContinue
if ($existingService -ne $null)
{
    throw "A cloud service with name $ServiceName exists"
}

# Test if there are already VMs deployed with those names
$existingVm = Get-AzureVM -ServiceName $ServiceName -Name $DomainControllerName -ErrorAction SilentlyContinue
if ($existingVm -ne $null)
{
    throw "A VM with name $DomainControllerName exists on $ServiceName"
}

$existingVm = Get-AzureVM -ServiceName $ServiceName -Name $MemberServerName -ErrorAction SilentlyContinue
if ($existingVm -ne $null)
{
    throw "A VM with name $MemberServerName exists on $ServiceName"
}

# Create the affinity group
$affinityGroupName = $($VNetName + "aff").ToLower()
New-AzureAffinityGroupIfNotExists -AffinityGroupName $affinityGroupName -Location $Location

# Check the VNet site, and add it to the configuration if it does not exist.
$vNet = Get-AzureVNetSite -VNetName $VNetName -ErrorAction SilentlyContinue
if ($vNet -ne $null)
{
    throw "VNet site name $VNetName is taken. Please provide a different name."
}

New-VNetSite -VNetName $VNetName -VNetAddressPrefix $VNetAddressPrefix -SubnetName $subnetName -SubnetAddressPrefix $SubnetAddressPrefix -AffinityGroupName $affinityGroupName

$imageFamilyNameFilter = "Windows Server 2012 Datacenter"

$image = Get-LatestImage -ImageFamilyNameFilter $imageFamilyNameFilter -OnlyMicrosoftImages
if ($image -eq $null)
{
    throw "Unable to find an image for $imageFamilyNameFilter to provision Virtual Machine."
}

Write-Verbose "Prompt user for administrator credentials to use when provisioning the virtual machine(s)."
$credential = Get-Credential -Message "Please provide the administrator credentials for the virtual machines"

$domainControllerVm = New-AzureVMConfig -Name $DomainControllerName -InstanceSize $DCVMSize -ImageName $image.ImageName | 
                        Add-AzureProvisioningConfig -Windows -AdminUsername $credential.GetNetworkCredential().username `
                        -Password $credential.GetNetworkCredential().password | 
                        Set-AzureSubnet -SubnetNames $subnetName |
                        Add-AzureDataDisk -CreateNew -DiskSizeInGB 20 -DiskLabel 'DITDrive' -LUN 0 |
                        New-AzureVM -ServiceName $ServiceName -AffinityGroup $affinityGroupName -VNetName $VNetName -WaitForBoot

$domainControllerWinRMUri= Get-AzureWinRMUri -ServiceName $ServiceName -Name $DomainControllerName

Install-WinRmCertificate $ServiceName $DomainControllerName

$DomainFqdn = $DomainName + "." + $TopLevelDomain

$domainInstallScript = {
        param ([String] $DomainFqdn, [string] $DomainName, [System.Security.SecureString] $safeModePassword)
        initialize-disk 2 -PartitionStyle MBR 
        New-Partition -DiskNumber 2 -UseMaximumSize -IsActive -DriveLetter F | Format-Volume -FileSystem NTFS -NewFileSystemLabel "AD DS Data" -Force:$true -confirm:$false

        Import-Module ServerManager
        Install-WindowsFeature -Name AD-Domain-Services 
        Install-WindowsFeature RSAT-AD-Tools
        Import-Module ADDSDeployment
        Install-ADDSForest `
        -CreateDnsDelegation:$false `
        -DatabasePath "F:\NTDS" `
        -DomainMode "Win2012" `
        -DomainName $DomainFqdn `
        -DomainNetbiosName $DomainName `
        -InstallDns:$true `
        -LogPath "F:\NTDS" `
        -NoRebootOnCompletion:$false `
        -SysvolPath "F:\SYSVOL" `
        -Force:$true `
        -SafeModeAdministratorPassword $safeModePassword
}

Invoke-Command -ConnectionUri $domainControllerWinRMUri.ToString() -Credential $credential -ScriptBlock $domainInstallScript -ArgumentList @($DomainFqdn, $DomainName, $credential.Password)

do
{
    Start-Sleep -Seconds 30
    $vm = Get-AzureVM -ServiceName $ServiceName -Name $DomainControllerName    
}
until ($vm.InstanceStatus -eq "ReadyRole")

Add-AzureDnsServerConfiguration -Name $DomainName -IpAddress $vm.IpAddress -VNetName $VNetName

if ($vm -eq $null)
{
    throw "Cannot get the details of the DC VM"
}

$memberServerVm = New-AzureVMConfig -Name $MemberServerName -InstanceSize $MemberVMSize -ImageName $image.ImageName | 
                    Add-AzureProvisioningConfig -WindowsDomain  -JoinDomain $DomainFqdn `
                        -AdminUsername $credential.GetNetworkCredential().username -Password $credential.GetNetworkCredential().password `
                        -Domain $DomainName -DomainUserName $credential.GetNetworkCredential().username -DomainPassword $credential.GetNetworkCredential().password   |
                    Set-AzureSubnet -SubnetNames $subnetName |  
                    New-AzureVM -ServiceName $ServiceName  -WaitForBoot
