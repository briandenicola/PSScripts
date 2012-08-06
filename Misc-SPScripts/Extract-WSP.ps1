param (
	[string] $solution = $(throw "An solution file is required!"),
	[string] $path = $(throw "An path to save the file is required!")
)

. ..\Libraries\SharePoint_Functions.ps1
. ..\Libraries\Standard_Functions.ps1

$solutionFile = Get-SPFarm | Select -Expand Solutions | Where { $_.Name -eq $solution }
$solutionFile.SolutionFile.SaveAs( $path + "\\" + $solution )