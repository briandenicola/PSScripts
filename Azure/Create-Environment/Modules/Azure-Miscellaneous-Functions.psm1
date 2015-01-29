#require -module Azure

. (Join-Path -Path $env:SCRIPTS_HOME -ChildPath "Libraries\Standard_Functions.ps1")
Load-AzureModules

function Convert-XmlToHashTable
{
    param(
        [System.Xml.XmlElement] $xml
    )

    function __Get-Properties
    {
        return ($xml | Get-Member -MemberType Property | Select -ExpandProperty Name)
    }

    $ht = @{}
    
    foreach( $node in (__Get-Properties $xml.ChildNodes) ) {
        if( $xml.$node -is [string] ) {
            $ht[$node] = $xml.$node
        }
        elseif (  $xml.$node -is [System.Xml.XmlElement] ) {
            $ht[$node] =Convert-XmlToHashTable -xml $xml.$node
        }
        elseif (  $xml.$node -is [System.Object[]] ) {
            foreach( $sub_node in $xml.$node ) {
                $ht[$node] += @(Convert-XmlToHashTable -xml $sub_node)
            }
        }
    }
    
    return $ht
}

function Wait-ForVMReadyState 
{
    param(
        [string] $CloudService,
        [string] $VMName
    )

    $ready_state = "ReadyRole"
    $sleep_time = 30

    do {
        Start-Sleep -Seconds $sleep_time
        $vm = Get-AzureVM -ServiceName $CloudService -Name $VMName    
    } until ($vm.InstanceStatus -eq $ready_state)
}

function Get-LatestAzureVMImageName
{
    param (
        [Parameter(Mandatory = $true)][string] $image_family_name
    )

    $images = Get-AzureVMImage | Where { $_.ImageFamily -imatch $image_family_name }

    return ( $images | 
               Sort -Unique -Descending -Property ImageFamily |
               Sort -Descending -Property PublishedDate |
               Select -First 1 -ExpandProperty ImageName )
}

function Get-ScriptBlock( [string] $file )
{
	[ScriptBlock]::Create( (Get-Content $file -Raw))
}


#https://gallery.technet.microsoft.com/Deploy-a-domain-controller-2ab7d658
function Add-AzureVnetConfigurationFile
{
    param (
        [string] $Path
    )
    
    $configFileContent = [xml] "<?xml version=""1.0"" encoding=""utf-8""?>
    <NetworkConfiguration xmlns:xsd=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xmlns=""http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration"">
              <VirtualNetworkConfiguration>
                <Dns />
                <VirtualNetworkSites/>
              </VirtualNetworkConfiguration>
            </NetworkConfiguration>"
    
    $configFileContent.Save($Path)
}

#https://gallery.technet.microsoft.com/Deploy-a-domain-controller-2ab7d658
function Set-VNetFileValues
{
    [CmdletBinding()]
    param (
        [String] $FilePath, 
        [String] $VNet, 
        [String] $AffinityGroupName, 
        [String] $VNetAddressPrefix, 
        [String] $SubnetName, 
        [String] $SubnetAddressPrefix
    )
    
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

#https://gallery.technet.microsoft.com/Deploy-a-domain-controller-2ab7d658
function Add-AzureDnsServerConfiguration
{
   param (
        [String] $Name,
        [String] $IpAddress,
        [String] $VNetName
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

    $namespace = @{network="http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration"}
    $dnsNode = select-xml -xml $xml -XPath "//network:Dns" -Namespace $namespace
    $dnsElement = $null

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

Export-ModuleMember -Function Set-VNetFileValues, Get-LatestAzureVMImageName, Add-AzureDnsServerConfiguration,  Convert-XmlToHashTable