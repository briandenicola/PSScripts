[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $true, ParameterSetName = 'Directory')]
    [string] $Year
)

$PhotosPath = "D:\Pictures\2020s"
$VideoPath = "D:\Videos\Home Movies\2020s"

$SourcePath = Join-Path -Path $PhotosPath -ChildPath $Year
$DestinationPath = Join-Path -Path $VideoPath -ChildPath $Year

$videos = Get-ChildItem -Path $SourcePath -Include @("*.mov","*.mp4") -Recurse
foreach( $Video in $videos ) {
    $RootPath = $video.Directory.Name
    $VideoFullPath = (Join-Path -Path $DestinationPath -ChildPath $RootPath)
    if( -not (Test-Path -Path $VideoFullPath) ) { New-Item -Path $VideoFullPath -ItemType Directory }
    Move-Item -Path $video.FullName -Destination (Join-Path -Path $VideoFullPath -ChildPath $Video.Name) -Verbose -Force
}