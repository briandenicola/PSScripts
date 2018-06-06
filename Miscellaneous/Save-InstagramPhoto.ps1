param(
    [Parameter(Mandatory=$true)]
    [string] $Url,

    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_ -PathType 'Container'})] 
    [string] $Path
)

$response = Invoke-WebRequest $url
$html = $response.ParsedHtml

$FullPath = Join-Path -Path $Path -ChildPath ("{0}.png" -f (Get-Random) )
$meta = $html.all | Where-Object NodeName -eq "META"  | Select-Object -ExpandProperty Outerhtml | Where-Object { $_ -imatch "property=`"og:image`"" }

Invoke-WebRequest $meta.Split(" ")[1].Split("=")[1].Trim("`"")  -Outfile $FullPath
