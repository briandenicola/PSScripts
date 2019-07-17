param (
    [Parameter(Mandatory = $True)] 
    [string] $Path
)

[byte[]]$byte = Get-Content -Encoding byte -ReadCount 4 -TotalCount 4 -Path $Path

$fileType = 'ASCII'
if ( $byte[0] -eq 0xef -and $byte[1] -eq 0xbb -and $byte[2] -eq 0xbf ) {
    $fileType = 'UTF8' 
} 
elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff) {
    $fileType = 'Unicode' 
}
elseif ($byte[0] -eq 0 -and $byte[1] -eq 0 -and $byte[2] -eq 0xfe -and $byte[3] -eq 0xff) {
    $fileType = 'UTF32' 
}
elseif ($byte[0] -eq 0x2b -and $byte[1] -eq 0x2f -and $byte[2] -eq 0x76) {
    $fileType = 'UTF7'
}

return $fileType