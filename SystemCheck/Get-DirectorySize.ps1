param (
	[string[]] $computers,
	[string] $folder
)

$DirUtil = "d:\Utils\DirectorySize.exe"

$s = New-PSSession -Computer $computers

Invoke-Command -Session $s -Script { 
	param(
		$f
	)
	Write-Host " **** " $ENV:ComputerName " **** " -foreground green
	d:\Utils\DirectorySize.exe $f
} -Args $folder
