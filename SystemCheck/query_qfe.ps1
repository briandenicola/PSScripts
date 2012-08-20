param(
	[string] $computer = $(throw "Must supply computer name")
)

. ..\libraries\Standard_functions.ps1

Get-WmiObject -computerName $computer -Class win32_quickfixengineering | where { -not [String]::IsNullorEmpty($_.Description) } | Sort HotfixId

