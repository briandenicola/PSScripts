param(
	[string] $computer = $(throw "Must supply computer name")
)

. ..\libraries\Standard_functions.ps1

if( Ping $computer )
{
	"Working on " + $computer + " . . ."
	Get-WmiObject -computerName $computer -Class win32_quickfixengineering | where-Object {$_.description -like "*Update*"} | Sort-Object hotfixID | Format-Table hotfixId, description 

}
