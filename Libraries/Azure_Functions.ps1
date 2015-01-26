Push-Location $PWD.Path
#Get-ChildItem 'C:\Program Files (x86)\Microsoft SDKs\Windows Azure\PowerShell\Azure\*.psd1' | ForEach-Object {Import-Module $_}
Import-Module Azure
Import-Module MSOnline -DisableNameChecking
Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking
Pop-Location

Set-Variable -Name global:subscription -Value $ENV:AZURE_SUBSCRIPTION -Option AllScope, Constant #-ErrorAction SilentlyContinue
Set-Variable -Name global:publishing_file -Value $ENV:AZURE_PUBLISH_FILE -Option AllScope, Constant #-ErrorAction SilentlyContinue

Import-AzurePublishSettingsFile $global:publishing_file
Set-AzureSubscription -SubscriptionName $global:subscription
Select-AzureSubscription -SubscriptionName $global:subscription

function Install-WinRmCertificate
{
    param{
        [string] $service, 
        [string] $vm_name
    }
    
    Set-Variable -Name cert_store -Value (New-Object System.Security.Cryptography.X509Certificates.X509Store "Root", "LocalMachine")
        
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

function Upload-FileToAzure {
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
