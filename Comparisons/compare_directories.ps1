param (
	[Parameter(Mandatory=$True]
	[Alias('src')]
	[string] $SourceDirectory,
	
	[Parameter(Mandatory=$True]
	[Alias('dst')]
	[string] $DifferenceDirectory
)
	
. (Join-Path -Path $ENV:SCRIPTS_HOME -ChildPath "libraries\standard_functions.ps1" )

$source_hashes = $SourceDirectory | Get-DirHash
$difference_hashes = $DifferenceDirectory | Get-DirHash

Compare-Object  -ReferenceObject $source_hashes -DifferenceObject $difference_hashes  -Property "Name","SHA1 Hash" -IncludeEqual