[CmdletBinding(SupportsShouldProcess=$true)]
param ( 
	[Parameter(Mandatory=$true)]	
    [string[]] $computers,
    [switch] $upload
)

. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Azure_Functions.ps1")
. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

if( $sharepoint ) {
	$global:url =  "http://teamadmin.gt.com/sites/ApplicationOperations/"
	$global:list = "Servers"
}
else { 
	$global:url =  "http://teamadmin.gt.com/sites/ApplicationOperations/applicationsupport/"
	$global:list = "AppServers"
}

foreach( $computer in $computers ) { 

    $vm = Get-AzureVM -ServiceName $computer 
    $os = $vm | Get-AzureOSDisk 
    $disks = $vm | Get-AzureDataDisk | Select DiskName, MediaLink, LogicalDiskSizeInGB 

    $os_label = Get-AzureVMImage | Where { $_.ImageName -eq $os.SourceImageName  } | Select -ExpandProperty Label
    $service = Get-AzureService | Where { $_.Label -imatch  $computer }

    $notes = @()
    $notes += "Affinity Group = " + $service.AffinityGroup
    $notes += "Date Created = " + $service.DateCreated
    $notes += "Url = " + $service.Url

	$audit = New-Object PSObject -Property @{
        SystemName = $vm.Name
        IPAddresses = $vm.IpAddress
        Model = $vm.InstanceSize
        OperatingSystem = $os_label
        Drives = $disks 
        SerialNumber = ($os.OS + " - " + $os.SourceImageName )
        Notes = $notes
    }	
	
	if( $upload ) {
		Write-Verbose "[ $(Get-Date) ] - Upload was passed on command line. Will upload results to $global:url ($global:list)  . . . "
		WriteTo-SPListViaWebService -url $global:url -list $global:list -Item $(Convert-ObjectToHash $audit) -TitleField SystemName 
	}
	else {
		return $audit
	}
}