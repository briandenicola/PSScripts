#requires -version 3
Param (
    [ValidateScript({Test-Path $_})]
    [string] $file,
    [string] $blob = [string]::empty,
    [string] $settings = ".\gt-credentials.publishsettings"
)

. (Join-Path $ENV:SCRIPTS_HOME "libraries\Azure_Functions.ps1")

Import-AzurePublishSettingsFile $settings

Set-Variable -Name storage -Value "gtiishadoop" -Option Constant
Set-Variable -Name subscription -Value "Enterprise - Brian, Chris and Erik" -Option Constant
Set-Variable -Name container -Value "logs"

Select-AzureSubscription $subscription
$keys = Get-AzureStorageKey $storage | Select -ExpandProperty Primary 
$storage_context = New-AzureStorageContext -StorageAccountName $storage -StorageAccountKey $keys

if( $blob -eq [string]::Empty ) { 
    $blob = Get-Item $file | Select -ExpandProperty Name
}
      
Set-AzureStorageBlobContent -File $file -Container $container -Blob $blob -context $storage_context