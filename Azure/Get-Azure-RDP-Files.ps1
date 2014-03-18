param (
    [string] $service
)

. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Azure_Functions.ps1")

foreach( $vm in (Get-AzureVM -ServiceName $service) ) {
   $rdp = Join-Path $PWD.Path ($vm.Name + '.rdp') 
   Get-AzureRemoteDesktopFile -ServiceName $service -Name $vm.Name -LocalPath $rdp
}
