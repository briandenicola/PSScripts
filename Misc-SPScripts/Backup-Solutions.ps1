param (
    [Parameter(Mandatory=$true)][string] $Path,
	[Parameter(Mandatory=$false)][string] $SolutionName
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")

$solutions = Get-SPFarm | Select -Expand Solutions
if( -not( [string]::IsNullOrEmpty($SolutionName) ) ) { 
    $solutions = @( $solutions | Where { $_.Name -eq $SolutionName } )
}

foreach( $solution in $solutions ) {
    $full_name = Join-Path -Path $path -ChildPath $solution.Name
    $solution.SolutionFile.SaveAs( $full_name )
}