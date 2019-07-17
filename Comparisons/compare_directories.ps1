param (
	[Parameter(Mandatory=$True)]
	[Alias('src')]
	[string] $SourceDirectory,
	
	[Parameter(Mandatory=$True)]
	[Alias('dst')]
	[string] $DifferenceDirectory
)
	
function Get-DirHash {
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $True)]
        [ValidateScript( {Test-Path $_})]
        [string] $Directory = $PWD.Path 
    )

    begin {
        $ErrorActionPreference = "silentlycontinue"
        $hashes = @()
    }
    process {
        $hashes = Get-ChildItem -Recurse -Path $Directory | 
            Where-Object { $_.PsIsContainer -eq $false } | 
            Select-Object Name, DirectoryName, @{Name = "SHA1 Hash"; Expression = {Get-Hash1 $_.FullName -algorithm "sha1"}}
    }
    end {
        return $hashes 
    }
}

$source_hashes = Get-DirHash -Directory $SourceDirectory 
$difference_hashes = Get-DirHash -Directory $DifferenceDirectory
Compare-Object  -ReferenceObject $source_hashes -DifferenceObject $difference_hashes  -Property "Name","SHA1 Hash" -IncludeEqual