param (
    [string] $settings_file,
    [string] $name,
    [string] $location = 'East US'
)

Import-Module "C:\Program Files (x86)\Microsoft SDKs\Windows Azure\PowerShell\Azure\Azure.psd1"
Import-AzurePublishSettingsFile $settings_file

New-AzureStorageAccount -StorageAccountName $name -Location $location