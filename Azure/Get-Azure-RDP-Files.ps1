param (
    [string] $settings_file,
    [string] $service
)

Import-Module "C:\Program Files (x86)\Microsoft SDKs\Windows Azure\PowerShell\Azure\Azure.psd1"
Import-AzurePublishSettingsFile $settings_file

foreach( $vm in (Get-AzureVM -ServiceName $service) ) {
   $rdp = Join-Path $PWD.Path ($vm.Name + '.rdp') 
   Get-AzureRemoteDesktopFile -ServiceName $service -Name $vm.Name -LocalPath $rdp
}
