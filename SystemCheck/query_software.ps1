## Params
param (
	[string] $system = $(throw "Must supply computer name")
)

get-wmiobject -class "Win32_Product" -namespace "root\CIMV2" -computername $system | Select Name, Caption, Description, InstallState, Vendor, Version

