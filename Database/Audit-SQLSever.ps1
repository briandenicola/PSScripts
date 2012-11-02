[CmdletBinding(SupportsShouldProcess=$true)]
param ( 
	[Parameter(Mandatory=$true)]	
    [string] $computer,
    [string] $cluster_name = [String]::Empty,
	[switch] $upload,
	[switch] $sharepoint
)

. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Standard_Variables.ps1")
. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
Import-Module sqlps -EA Stop -DisableNameChecking

if( $sharepoint ) {
	$url =  $global:SharePoint_url
	$list = $global:SharePoint_sql_server_list 
	$view = $global:SharePoint_sql_server_all_items_view
}
else { 
	$url =  $global:AppOps_url
	$list = $global:AppOps_sql_server_list 
	$view = $global:AppOps_sql_server_all_items_view
}

function Get-SPFormattedServers ( [String[]] $computers )
{
	$sp_formatted_data = [String]::Empty
	
	$sp_server_list = Get-SPListViaWebService -url $url  -list $list -view $view
	foreach( $computer in $computers ) {
		$id = $sp_server_list | where { $_.SystemName -eq $computer } | Select -ExpandProperty ID
		$sp_formatted_data += "#{0};#{1};" -f $id, $computer
	}
	
	Write-Verbose $sp_formatted_data
	
	return $sp_formatted_data.TrimStart("#").TrimEnd(";").ToUpper()
}

function Audit-Server
{
	param ( 
		[string] $server,
		[object] $audit
	)
	
	Write-Verbose "[ $(Get-Date) ] - Auditing server - $server  . . . "
	
	$computer = Get-WmiObject Win32_ComputerSystem -ComputerName $server
	$os = Get-WmiObject Win32_OperatingSystem -ComputerName $server
	$bios = Get-WmiObject Win32_BIOS -ComputerName $server
	$nics = Get-WmiObject Win32_NetworkAdapterConfiguration -ComputerName $server
	$cpu = Get-WmiObject Win32_Processor -ComputerName $server | select -first 1 -expand MaxClockSpeed
	$disks = Get-WmiObject Win32_LogicalDisk -ComputerName $server
	
	$audit | add-member -type NoteProperty -name Domain -Value $computer.Domain		
	$audit | add-member -type NoteProperty -name Model -Value ($computer.Manufacturer + " " + $computer.Model.TrimEnd())
	$audit | add-member -type NoteProperty -name Processor -Value ($computer.NumberOfProcessors.toString() + " x " + ($cpu/1024).toString("#####.#") + " GHz")
	$audit | add-member -type NoteProperty -name Memory -Value ($computer.TotalPhysicalMemory/1gb).tostring("#####.#")
	$audit | add-member -type NoteProperty -name SerialNumber -Value ($bios.SerialNumber.TrimEnd())
	$audit | add-member -type NoteProperty -name OperatingSystem -Value ($os.Caption + " - " + $os.ServicePackMajorVersion.ToString() + "." + $os.ServicePackMinorVersion.ToString())

	return $audit
}

function Get-SQLServerVersion
{
	param (
		[string] $ver
	)
	
	Write-Verbose "[ $(Get-Date) ] - Getting SQL Server version  . . . "
	
	if( $ver -match "11.00" ) { return "SQL Server 2012" }
	if( $ver -match "10.50" ) { return "SQL Server 2008/R2" }
	if( $ver -match "10.00" ) { return "SQL Server 2008" }
	if( $ver -match "9.00" ) { return "SQL Server 2005" }
	if( $ver -match "8.00" ) { return "SQL Server 2000" }
	
	return "Unknown Version"
}

function Get-SQLRunningInstances 
{
	param (
		[string] $computer
	)
	
	Write-Verbose "[ $(Get-Date) ] - Getting SQL Server instances  . . . "
	
	$instances = @(Get-Service -ComputerName $computer | Where { $_.Status -eq "Running" -and $_.Name -match "MSSQL"} | Select -Expand Name)
	
	for( $i=0; $i -lt $instances.Count; $i++ ) { 
		if( $instances[$i] -ne "MSSQLSERVER" ) { $instances[$i] = $instances[$i].Split("$")[1] }
	}
	
	return $instances
}

function Get-SupportedOS 
{
	param (
		[string] $ver
	)
	
	return ( [System.Convert]::ToDecimal( $ver.Split(" ")[0] ) -ge 6.1 )
}

function Get-SQLClusterNodes 
{
	param ( 
		[string] $name
	)
	
	Write-Verbose "[ $(Get-Date) ] - Getting SQL Server Cluster Nodes  . . . "
	
	$sp_server_list = Get-SPListViaWebService -url $url  -list $list
		
    $cluster = Get-Cluster -name $name -EA Stop  
    $nodes = $cluster | Get-ClusterNode | Select -Expand Name

	foreach( $node in $nodes ) 
	{
		if( ($sp_server_list | where { $_.SystemName -eq $node }) -eq $null ) {
			Write-Verbose "[ $(Get-Date) ] - $node was not found in SharePoint Server List. Going to Audit and Upload  . . . "
			$audit = Audit-Server -server $node -Audit ( New-Object PSObject -Property @{SystemName = $node;Role="Database Node"} )
			WriteTo-SPListViaWebService -url $url -list $list -Item $(Convert-ObjectToHash $_) -TitleField SystemName 
		}
	}
	
	return ( Get-SPFormattedServers $nodes )
}

function main
{
	if( $cluster_name -ne [String]::Empty ) {
		Import-Module FailoverClusters -EA SilentlyContinue
		if( $? -eq $true ) { $cluster_module_loaded = $true } else { $cluster_module_loaded = $false }
	}
	
	foreach( $instance in (Get-SQLRunningInstances -computer $computer) ) 
	{ 
		Write-Verbose "[ $(Get-Date) ] - Working on instance - $instance on $computer  . . . "
		try 
		{		
			if( $instance -eq "MSSQLSERVER" ) {
				$sql = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -Argument $computer
			} 
			else {
				$sql = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -Argument ($computer + "\" + $instance)
			}
			$wmi = new-object "Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer" $computer
			
			$properties = $sql | Select Edition, OSVersion,IsClustered, VersionString, ServiceAccount	
			$properties | Add-Member -type NoteProperty -name SystemName -Value $computer
			$properties | Add-Member -type NoteProperty -name Instance -Value $instance 
			$properties | Add-Member -type NoteProperty -Name SQLVersion -Value (Get-SQLServerVersion $properties.VersionString)
			$properties | Add-Member -type NoteProperty -name IPAddresses -Value ( nslookup $computer )
			$properties | Add-Member -type NoteProperty -name Port -Value ( $wmi.ServerInstances | Where { $_.Name -eq $instance } | Select -Expand ServerProtocols | Where { $_.DisplayName -eq "TCP/IP"} ).IpAddresses["IPAll"].IPAddressProperties["TcpPort"].Value
			$properties | Add-Member -type NoteProperty -name Databases -Value	( [String]::join(";", ($sql.Databases | Select -Expand Name)) )
		
			if( $properties.IsClustered -eq $false ) { 
				Write-Verbose "[ $(Get-Date) ] - SQL Server is stand aloned so going to audit server  . . . "
				$properties | Add-Member -type NoteProperty -name Role -Value "Standalone Database Server" 
				$properties = Audit-Server -server $computer -audit $properties
			}
			else {
				Write-Verbose "[ $(Get-Date) ] - SQL Server is clustered so going to determine cluster nodes  . . . "
				$properties | Add-Member -type NoteProperty -name Role -Value "Database Cluster"
				if ( $cluster_module_loaded = $true -and ( Get-SupportedOS -ver $properties.OSVersion ) ) {
					$properties | Add-Member -type NoteProperty -name Nodes -Value ( Get-SQLClusterNodes -name $cluster_name )
				}
			}
			
			if( $upload ) {
				Write-Verbose "[ $(Get-Date) ] - Upload was passed on command line. Will upload results to $url ($list)  . . . "
				WriteTo-SPListViaWebService -url $url -list $list -Item $(Convert-ObjectToHash $properties) -TitleField SystemName 
			}
			else {
				return $properties
			}
		} 
		catch [System.Exception] {
			Write-Error ("The Audit failed on $computer ($instance) - " +  $_.Exception.ToString() )
		}
	}
}
main
