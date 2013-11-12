param(
    [string] $guid
)

$mof = Join-Path "." ($guid + ".mof") 

if( !(Test-path $mof) ) {
    throw "Coudl not find $mof . . "
}

$checksum = "{0}.mof.checksum" -f $guid
$hash = Get-FileHash $mof

[System.IO.File]::AppendAllText( $checksum, $hash.Hash)