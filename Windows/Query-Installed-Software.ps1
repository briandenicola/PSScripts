## Params
param (
	[string[]] $computers = $(throw "Must supply computer name")
)

$sb = { 
	$software_inventory = @()
	$uninstall_key = "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall" 

	$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $ENV:COMPUTERNAME)
	$regkey = $reg.OpenSubKey($uninstall_key) 
	$subkeys = $regkey.GetSubKeyNames() 

	foreach( $key in $subkeys) {

		$thisKey = $uninstall_key + "\\" + $key 
		$thisSubKey = $reg.OpenSubKey($thisKey) 

		if( [String]::IsNullOrEmpty( $thisSubKey.GetValue("DisplayName") ) ) { continue }
		
		$software_inventory += (New-Object PSObject -Property @{ 
			ComputerName = $ENV:COMPUTERNAME
			DisplayName = $($thisSubKey.GetValue("DisplayName"))
			DisplayVersion = $($thisSubKey.GetValue("DisplayVersion"))
			InstallLocation = $($thisSubKey.GetValue("InstallLocation"))
			Publisher = $($thisSubKey.GetValue("Publisher"))
		})
	}
	return $software_inventory
}

Invoke-Command -Computer $computers -ScriptBlock $sb | Select ComputerName, DisplayName, DisplayVersion, Publisher 