param (
	[string] $src,
	[string] $dst
)	
. ..\Libraries\Standard_functions.ps1


Compare-Object $($src | get-DirHash) $($dst | get-DirHash) -property @("Name","SHA1 Hash") -includeEqual