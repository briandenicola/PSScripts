param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [string]
    $CodePath
)

$linesPerLanuage = @{}

$excludedPathNames = @(
    "node_modules",
    "golang.org",
    "github.com",
    "bin",
    "obj",
    "netstandard2.0",
    "lib",
    "gopkg.in",
    "packages"
)

$excludedFileNames = @(
    "package.json"
    "package-lock.json"
)

$includedFileTypes = @(
    "*.go",
    "*.cs",
    "*.ps1",
    "*.psm1",
    "*.json",
    "*.js",
    "*.ts",
    "*.md", 
    "*.tf"
)


function Get-SourceCodeFiles
{
    param(
        [string] $Path
    )

    $returnFiles = @()
    $allFiles = Get-ChildItem -Path $Path -Include $includedFileTypes -Exclude $excludedFileNames -Recurse 

    foreach( $file in $allFiles ) {
        $include = $true
        foreach( $excludedPath in $excludedPathNames ) {
            if( $file.FullName -imatch $excludedPath ) {
                $include = $false 
                break
            }
        }
        if($include){
            $returnFiles += $file
        }
    }

    return $returnFiles
}
function Get-TotalLinesPerFile
{
    param(
        [string] $FileName
    )
    return (Get-Content -Path $FileName | Measure-Object -Line).Lines
}

$files = Get-SourceCodeFiles -Path $CodePath
foreach($file in $files) {
    $linesPerLanuage[$file.Extension] += Get-TotalLinesPerFile -FileName $file.FullName 
}

return ($linesPerLanuage.GetEnumerator() | Sort-Object -Property Value -Descending)