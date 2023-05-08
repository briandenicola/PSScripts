[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [string] $Path,
    [string] $OutputPath,
    [string] $Filter = "*.jpg",
    [switch] $StatusOnly
)

$OneDriveLib = "D:\Utils\OneDriveLib.dll"

Import-Module -Name $OneDriveLib

$badFiles = @()
foreach ( $item in (Get-ChildItem -Path $Path -Recurse -Include $Filter) ) {
    Write-Verbose -Message ("Working on {0}" -f $item.FullName)
    $status = Get-ODStatus -ByPath $item.FullName
    if( $status -ne "UpToDate" ) {
        Write-Verbose -Message ("{0} is not corrected synced with a status of {1}" -f $item.FullName, $status)
        if($StatusOnly) {
            $badFiles += (New-Object -TypeName psobject -Property @{
                FullName = $item.FullName
                Status   = $status
            })
        } else {
            $Target = Join-Path -Path $item.Directory.FullName -ChildPath ("{0}-fixed{1}" -f $item.BaseName, $item.Extension )

            if($PSCmdlet.ShouldProcess($Target, "Fixing OneDrive File")){
                Copy-Item -Path $item.FullName -Destination $Target
                Move-Item -Path $item.FullName -Destination $OutputPath
            } else {
                Copy-Item -Path $item.FullName -Destination $Target -Verbose
                Move-Item -Path $item.FullName -Destination $OutputPath -Verbose
            } 
        }
    }
}

if($StatusOnly) {
    return $badFiles
}