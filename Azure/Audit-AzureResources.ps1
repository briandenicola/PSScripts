<#
.SYNOPSIS 
    This script will query an Azure subscription and report back the resources with particular focus on Public IP Addresses 

.DESCRIPTION

.EXAMPLE
    Audit-AzureResources.ps1 -CSV c:\temp\azure.csv

.NOTES
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,   

    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
#>

[CmdletBinding()]
param(
    [string] $CSVPath
)

Set-StrictMode -Version 5
Import-Module -Name Azure_Functions -Force

class AzureResource {
    [string] $Name              = [string]::Empty
    [string] $Id                = [string]::Empty
    [string] $Subscription      = [string]::Empty
    [string] $Group             = [string]::Empty
    [string] $Location          = [string]::Empty
    [string] $Type              = [string]::Empty
    [string] $PrivateIPAddress  = [string]::Empty
    [string] $PublicIPAddress   = [string]::Empty
    [string] $PublicUrls        = [string]::Empty
    [string] $ParentResourceId  = [string]::Empty
    [string] $Tags              = [string]::Empty
    [string] $CreatedBy         = [string]::Empty
    [DateTime] $CreationTime    = (Get-Date -Date '01/01/1970')
}

function Get-IPAddress {
    param  ([string] $url)
    if( $url -match "^(http|https)://(.*)" ) { $url = $matches[2].TrimEnd("/") }
    return (Resolve-DnsName -Name $url -DnsOnly -Type A | Select-Object -ExpandProperty IP4Address -ErrorAction SilentlyContinue)
}

try { 
    $resources = Get-AzureRmResource 
}
catch { 
    Write-Verbose -Message ("[{0}] - Logging into Azure" -f $(Get-Date))
    Login-AzureRmAccount 
    $resources = Get-AzureRmResource
}

$myAzureResoures = @()
foreach( $resource in $resources ) {
    $myResource = [AzureResource]::New()

    $myResource.Name     = $resource.Name
    $myResource.Id       = $resource.ResourceId
    $myResource.Group    = $resource.ResourceGroupName
    $myResource.Type     = $resource.ResourceType
    $myResource.Location = $resource.Location
    $myResource.Subscription = $resource.SubscriptionId
    
    $log = (Get-AzureRmLog -ResourceId $resource.ResourceId -Status Succeeded | Where-Object SubStatus -eq "Created") | Select-Object -First 1
    if( $log ) {
        $myResource.CreationTime = $log.EventTimestamp
        $myResource.CreatedBy = $log.Caller
    }
    
    if( $resource.ResourceType -eq "Microsoft.Web/sites" ) {
        Write-Verbose -Message ("[{0}] - Getting Website Info. . ." -f $(Get-Date))
        $myResource.Type += ("/{0}" -f $resource.Kind)
        $web = Get-AzureRmWebApp -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
        $myResource.PublicUrls = [string]::join( "||", $web.EnabledHostNames) 
        $myResource.PublicIPAddress = Get-IpAddress -Url $web.DefaultHostName
    }
    elseif( $resource.ResourceType -eq "Microsoft.Compute/virtualMachines" ) {
        Write-Verbose -Message ("[{0}] - Getting Virtual Machine Info. . ." -f $(Get-Date))
        $vm = Get-AzureRMVM -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name 
        $myResource.Type += ("/{0}/{1}" -f $vm.StorageProfile.ImageReference.Sku, $vm.HardwareProfile.VmSize)
        $ips = Get-AzureRMVMIpAddress -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name 
        $myResource.PublicIPAddress = $ips | Select-Object -ExpandProperty PublicIpAddress
        $myResource.PrivateIPAddress = $ips | Select-Object -ExpandProperty PrivateIpAddress
    }
    elseif( $resource.ResourceType -eq "Microsoft.Sql/servers/databases" ) {
        Write-Verbose -Message ("[{0}] - Getting Azure SQL Databases Info. . ." -f $(Get-Date))
        $server, $name = $resource.Name.Split("/")
        $db = Get-AzureRmSqlDatabase -ResourceGroupName $resource.ResourceGroupName -ServerName $server -DatabaseName $name
        $myResource.CreationTime = $db.CreationDate
        $myResource.Type += ("/{0}/{1}" -f $db.CurrentServiceObjectiveName, $db.Edition)
    }
    elseif( $resource.ResourceType -eq "Microsoft.DocumentDb/databaseAccounts" ) {
        Write-Verbose -Message ("[{0}] - Getting Document DB Info. . ." -f $(Get-Date))
        $myResource.Type += ("/{0}" -f $resource.Kind)
        $myResource.PublicUrls = ("{0}.documents.azure.com" -f $resource.Name)
        $myResource.PublicIPAddress = Get-IpAddress -Url $myResource.PublicUrls
    }
    elseif( $resource.ResourceType -eq "Microsoft.Sql/servers" ) {
        Write-Verbose -Message ("[{0}] - Getting Azure SQL Info. . ." -f $(Get-Date))
        $myResource.PublicUrls = ("{0}.database.windows.net" -f $resource.Name)
        $myResource.PublicIPAddress = Get-IpAddress -Url $myResource.PublicUrls
    }
    elseif( $resource.ResourceType -eq "Microsoft.Storage/storageAccounts" ) {
        Write-Verbose -Message ("[{0}] - Getting Storage Account Info. . ." -f $(Get-Date))
        $storage =  Get-AzureRmStorageAccount -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
        $myResource.Type += ("/{0}/{1}" -f $storage.Sku.Tier, $storage.Sku.Name)
        $myResource.PublicUrls = $storage.PrimaryEndpoints.Blob
        $myResource.PublicIPAddress = Get-IpAddress -Url $myResource.PublicUrls
        $myResource.CreationTime = $storage.CreationTime
    }
    elseif( $resource.ResourceType -eq "Microsoft.KeyVault/vaults") {
        Write-Verbose -Message ("[{0}] - Getting Key Vault Info. . ." -f $(Get-Date))
        $vault = Get-AzureRmKeyVault -VaultName $resource.ResourceName -ResourceGroupName $resource.ResourceGroupName
        $myResource.PublicUrls = $vault.VaultUri
        $myResource.PublicIPAddress = Get-IpAddress -Url $myResource.PublicUrls
    }
    elseif( $resource.ResourceType -eq "Microsoft.Storage/PublicIPAddress" ) {
        Write-Verbose -Message ("[{0}] - Getting Public IP Addresses. . ." -f $(Get-Date))
        $ip = Get-AzureRmPublicIpAddress -ResourceName $resource.ResourceName -ResourceGroupName $resource.ResourceGroupName -ErrorAction SilentlyContinue 
        $myResource.PublicIPAddress = $ip.IpAddress
        $myResource.ParentResourceId =  $ip | Select-Object -ExpandProperty IpConfiguration | Select-Object -ExpandProperty Id
    }
    elseif( $resource.ResourceType -eq "Microsoft.Network/TrafficManager" ) {
        Write-Verbose -Message ("[{0}] - Getting Traffic Manager Info. . ." -f $(Get-Date))
        $myResource.PublicUrls = ("{0}.trafficmanager.net" -f $resource.Name)
        $myResource.PublicIPAddress = "multiple"
    }
    elseif( $resource.ResourceType -eq "Microsoft.ClassicCompute/domainNames" ) {
        Write-Verbose -Message ("[{0}] - Getting Cloud Services Info. . ." -f $(Get-Date))
        $myResource.PublicUrls = ("{0}.cloudapp.net" -f $resource.Name)
        $myResource.PublicIPAddress = Get-IpAddress -Url $myResource.PublicUrls
    }
    elseif( $resource.ResourceType -eq "microsoft.cdn/profiles" ) {
        Write-Verbose -Message ("[{0}] - Getting CDN Profile Info. . ." -f $(Get-Date))
         $myResource.Type += ("/{0}" -f $resource.Sku.Name)
    }
    elseif( $resource.ResourceType -eq "microsoft.cdn/profiles/endpoints" ) {
        Write-Verbose -Message ("[{0}] - Getting CDN Endpoint Info. . ." -f $(Get-Date))
        $myResource.PublicUrls = ("{0}.azureedge.net" -f $resource.Name.Split("/")[1])
        $myResource.PublicIPAddress = "multiple"
        $resource.ResourceId -imatch "^(.*)/endpoints/(.*)$" | Out-Null
        $myResource.ParentResourceId = $matches[1]
    }
    
    try{
        Write-Verbose -Message ("[{0}] - Getting Tags for Resource. . ." -f $(Get-Date))
        $tags = @()
        $resource.Tags.Keys | ForEach-Object { $tags += ("{0}={1}" -f $_ , $resource.Tags[$_]) }
        $myResource.Tags = [string]::Join( "|", $tags )
    }
    catch {}

    $myAzureResoures += $myResource
}

if( !([string]::IsNullOrEmpty($CSVPath)) ) {
     $myAzureResoures | Export-Csv -Encoding ASCII -NoTypeInformation -Path $CSVPath
}
else {
    return $myAzureResoures
}