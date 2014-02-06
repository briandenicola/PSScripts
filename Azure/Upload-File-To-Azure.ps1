#requires -version 3
Param (
    [ValidateScript({Test-Path $_})][string] $file,
    [Parameter(Mandatory=$true)][string] $storage,
    [Parameter(Mandatory=$true)][string] $container,
    [string] $blob = [string]::empty
)

. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Azure_Functions.ps1")

Select-AzureSubscription $global:subscription 

$keys = Get-AzureStorageKey $storage | Select -ExpandProperty Primary 
$storage_context = New-AzureStorageContext -StorageAccountName $storage -StorageAccountKey $keys

if( $blob -eq [string]::Empty ) { 
    $blob = Get-Item $file | Select -ExpandProperty Name
}
      
Set-AzureStorageBlobContent -File $file -Container $container -Blob $blob -context $storage_context