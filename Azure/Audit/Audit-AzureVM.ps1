[CmdletBinding(SupportsShouldProcess=$true)]
param ( 
	[Parameter(Mandatory=$true)]	
    [string[]] $computers,
    [Parameter(Mandatory=$true)]	
    [string] $service,

    [string] $subscription = [string]::empty,

    [switch] $upload
)

. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Azure_Functions.ps1")
. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

Set-Variable -Name global:url -Value [string]::Empty
Set-Variable -Name global:list -Value "Servers"
Set-Variable -Name audit -Value @()

if( $subscription -ne [string]::Empty ) {
    Select-AzureSubscription -SubscriptionName $subscription
}

foreach( $computer in $computers ) { 

    $vm = Get-AzureVM -ServiceName $service -Name $computer 
    $os = $vm | Get-AzureOSDisk 
    $disks = $vm | Get-AzureDataDisk | Select DiskName, MediaLink, LogicalDiskSizeInGB 

    $os_label = Get-AzureVMImage | Where { $_.ImageName -eq $os.SourceImageName  } | Select -ExpandProperty Label
    $azure_service = Get-AzureService -ServiceName $service 
    $notes = "Affinity Group = {0}.Date Created = {1}. Url = {2}" -f $azure_service.AffinityGroup, $azure_service.DateCreated, $azure_service.Url 
    
	$azure_vm = New-Object PSObject -Property @{
        SystemName = $vm.Name
        IPAddresses = $vm.IpAddress
        Model = $vm.InstanceSize
        OperatingSystem = $os_label
        Drives = $disks 
        SerialNumber = ("{0}_{1} " -f $os.Os, $os.SourceImageName )
        Notes = $notes
    }
	
	if( $upload ) {
		Write-Verbose "[ $(Get-Date) ] - Upload was passed on command line. Will upload results to $global:url ($global:list)  . . . "
		WriteTo-SPListViaWebService -url $global:url -list $global:list -Item $(Convert-ObjectToHash $audit) -TitleField SystemName 
	}
	else {
		$audit += $azure_vm
	}
}

return $audit