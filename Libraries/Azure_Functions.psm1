function Connect-ToAzureVMviaSSH
{
    param(
        [Parameter(Mandatory=$true)]
        [string] $ResourceGroupName,

        [Parameter(Mandatory=$true)]
        [string] $VMName,

        [Parameter(Mandatory=$true)]
        [string] $UserName,

        [switch] $UsePrivateIPAddress,

        [Parameter(ParameterSetName='PrivateKey', Mandatory=$false)]
        [string] $PrivateKeyPath = [string]::Empty,

        [Parameter(ParameterSetName='Password', Mandatory=$false)]
        [string] $Password = [string]::Empty
    )

    if( [string]::IsNullOrEmpty($ENV:PUTTY_PATH) -or !(Test-Path -Path $ENV:PUTTY_PATH)) {
        throw "The Path to putty.exe is not found. Is the environmental variable 'PUTTY_PATH' set?"
    } 

    $vm_ip = Get-AzureRMVMIpAddress -ResourceGroupName $ResourceGroupName -Name $VMName
    if($UsePrivateIPAddress) {
        $ip = $vm_ip | Select -ExpandProperty PrivateIpAddress
    }
    else {
        $ip = $vm_ip | Select -ExpandProperty PublicIpAddress
    }

    if($ip -eq $null) {
        throw ("Could not find any IP Address for Virtual Machine {0} in Resource Group {1} . . ." -f $VMName, $ResourceGroupName)
    }

    if( !([string]::IsNullOrEmpty($PrivateKeyPath)) -and (Test-Path -Path $PrivateKeyPath) ) {
        $private_key = $PrivateKeyPath
    }
    elseif( !([string]::IsNullOrEmpty($ENV:PUTTY_PRIVATE_KEY)) -and (Test-Path -Path $ENV:PUTTY_PRIVATE_KEY) ) {
        $private_key = $ENV:PUTTY_PRIVATE_KEY 
    }
    else {
        $private_key = [string]::Empty
    }

    if( [string]::IsNullOrEmpty($private_key) ) {
        &$ENV:PUTTY_PATH $UserName@$ip
    }
    else{
        &$ENV:PUTTY_PATH $UserName@$ip -i $private_key
    }
}

function Get-AzureIPRange
{
    return (Invoke-RestMethod http://mscloudips.azurewebsites.net/Api/azureips/all )
}

function Set-AzureRMVnetDNSServer
{
    param( 
        [Parameter(Mandatory=$true)]
        [string] $ResourceGroupName,
        
        [Parameter(Mandatory=$true)]
        [string] $VnetName,
        
        [Parameter(ParameterSetName='Default', Mandatory=$true)]
        [switch] $AzureDNS,
        
        [Parameter(ParameterSetName='Custom', Mandatory=$true)]
        [ValidateScript({ $_ -imatch [IPAddress]$_ })]
        [string] $PrimaryDnsServerAddress,
        
        [Parameter(ParameterSetName='Custom', Mandatory=$false)]
        [ValidateScript({ $_ -imatch [IPAddress]$_ })]
        [string] $SecondaryDnsServerAddress = [string]::Empty
    )
    
    $vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VnetName
    
    if($AzureDNS) {
        $vnet.DhcpOptions = $null
    }
    else {
        $dns_servers = @($PrimaryDnsServerAddress)
       
        if($SecondaryDnsServerAddress -ne [string]::Empty) {
            if( $SecondaryDnsServerAddress -eq $PrimaryDnsServerAddress ) { throw "The Secondary DNS Server can not be the same as the Primary DNS Server . . ." }
            $dns_servers += $SecondaryDnsServerAddress
        }
        $dhcp_options = New-Object PSObject -Property @{
            DnsServers = $dns_servers
        }
        $vnet.DhcpOptions = $dhcp_options
    }
    
    Set-AzureRmVirtualNetwork -VirtualNetwork $vnet
}

function Get-AzureRMVMssIpAddress 
{
    param( 
        [Parameter(Mandatory=$true)]
        [string] $ResourceGroupName,
        [Parameter(Mandatory=$true)]
        [string] $VMSS
    )
    
    $vms = @()
    
    $vms_to_process = Get-AzureRmNetworkInterface -VirtualMachineScaleSetName $VMSS -ResourceGroupName $ResourceGroupName
    foreach( $vm in $vms_to_process  ){
        $index = $vm.VirtualMachine.Id.Split("/") | Select -Last 1
        $vmss_vm = Get-AzureRmVmssVM -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMSS -InstanceId $index
        $values = [ordered]@{
            Name = $vmss_vm.Name
            PrivateIpAddress = ( $vm.IpConfigurations | Select -First 1 | Select -Expand PrivateIpAddress )
        }
        $vms += (New-Object PSObject -Property $values)
    } 
    
    re  turn $vms 
}

function Get-AzureRMVMIpAddress 
{
    param( 
        [Parameter(Mandatory=$true)]
        [string] $ResourceGroupName,
        [String] $Name = [String]::Empty
    )
    
    $vms = @()
    $vms_to_process = Get-AzureRMVM -ResourceGroupName $ResourceGroupName | Where Name -imatch $Name
    foreach( $vm in $vms_to_process  ){
        $nic = Get-AzureRmNetworkInterface -Name ($vm.NetworkInterfaceIDs.Split("/") | Select -Last 1) -ResourceGroupName $ResourceGroupName
        $pip_name = $nic.IpConfigurations.PublicIpAddress.id.Split("/") | Select -Last 1
        
        $values = [ordered]@{
            Name = $vm.Name
            PrivateIpAddress = ($nic | Select @{N="IP";E={$_.IpConfigurations.PrivateIpAddress}}).Ip
            PublicIpAddress =  (Get-AzureRMPublicIpAddress -Name $pip_name -ResourceGroupName $ResourceGroupName | Select -Expand IpAddress)     
        }
        $vms += (New-Object PSObject -Property $values)
    } 
    
    return $vms 
}

function Install-WinRmCertificate
{
    param (
        [string] $service, 
        [string] $vm_name
    )
    
    Set-Variable -Name cert_store -Value (New-Object System.Security.Cryptography.X509Certificates.X509Store "My", "CurrentUser")
        
    $vm = Get-AzureVM -ServiceName $service -Name $vm_name 
    $winrm_cert = Get-AzureCertificate -ServiceName $service -Thumbprint ($vm.VM.DefaultWinRMCertificateThumbprint) -ThumbprintAlgorithm sha1
    
    $cert = Get-Item (Join-Path "cert:\CurrentUser\My\" $vm.VM.DefaultWinRMCertificateThumbprint) -ErrorAction SilentlyContinue
    
    if(!$cert) {
        $cert_base64 = [System.Convert]::FromBase64String($winrm_cert.Data)
        $x509_cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate
        $x509_cert.Import($cert_base64)
        
        $cert_store.Open("ReadWrite")
        $cert_store.Add($x509_cert)
        $cert_store.Close()
    }
}

function Send-FileToAzure {
    Param (
        [ValidateScript({Test-Path $_})][string] $file,
        [Parameter(Mandatory=$true)][string] $storage,
        [Parameter(Mandatory=$true)][string] $container,
        [string] $blob = [string]::empty
    )

    Select-AzureSubscription $global:subscription 

    $keys = Get-AzureStorageKey $storage | Select -ExpandProperty Primary 
    $storage_context = New-AzureStorageContext -StorageAccountName $storage -StorageAccountKey $keys

    if( $blob -eq [string]::Empty ) { 
        $blob = Get-Item $file | Select -ExpandProperty Name
    }
      
    Set-AzureStorageBlobContent -File $file -Container $container -Blob $blob -context $storage_context
} 

function Get-AzureRDPFiles {
    param (
        [string] $service
    )

    foreach( $vm in (Get-AzureVM -ServiceName $service) ) {
       $rdp = Join-Path $PWD.Path ($vm.Name + '.rdp') 
       Get-AzureRemoteDesktopFile -ServiceName $service -Name $vm.Name -LocalPath $rdp
    }
}

Export-ModuleMember -Function Get-AzureRDPFiles, Send-FileToAzure, Set-AzureRMVnetDNSServer, Get-AzureRMVMssIpAddress, Get-AzureRMVMIpAddress, Install-WinRmCertificate, Connect-ToAzureVMviaSSH, Get-AzureIPRange