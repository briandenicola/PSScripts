Push-Location $PWD.Path
Get-ChildItem 'C:\Program Files (x86)\Microsoft SDKs\Windows Azure\PowerShell\Azure\*.psd1' | ForEach-Object {Import-Module $_}
Import-Module MSOnline -DisableNameChecking
Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking
Pop-Location

Set-Variable -Name global:subscription -Value "" -Option AllScope, Constant 
Set-Variable -Name global:publishing_file -Value "" -Option AllScope, Constant 

Import-AzurePublishSettingsFile $global:publishing_file

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