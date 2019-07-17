param (
    [Parameter(Mandatory = $true, ParameterSetName = 'Directory')]
    [ValidateScript( {Test-Path $_ -PathType 'Container'})] 
    [string] $Path,

    [Parameter(Mandatory = $true, ParameterSetName = 'File')]
    [ValidateScript( {Test-Path $_ -PathType 'Leaf'})] 
    [string] $RDPFile
)

function Get-FullAddress {
    param  ( [string] $file )
    return ( Select-String -Pattern "full address"  -Path  $file | Select-Object -Expand Line -First 1 )
}

$rdp_settings = @"
    {0}
    prompt for credentials:i:1                    
    screen mode id:i:1                            
    desktopwidth:i:1280                           
    desktopheight:i:768                           
    redirectprinters:i:0                          
    redirectcomports:i:0                          
    redirectclipboard:i:1                         
    redirectposdevices:i:0                        
    drivestoredirect:s:*
"@

switch ($PsCmdlet.ParameterSetName) { 
    "Directory" { 
        Get-ChildItem -Path $path -Recurse -Include "*.rdp" -Depth 0 | ForEach-Object {
            Write-Verbose -Message ("Updating RDP file {0} to preferred settings . . ." -f $_.FullName)
            $address = Get-FullAddress -file $_.FullName
            Set-Content -Encoding Ascii -Value ( $rdp_settings -f $address) -Path $_.FullName
        }
    }
    "File" { 
        Write-Verbose -Message ("Updating RDP file {0} to preferred settings . . ." -f $RDPFile)
        $address = Get-FullAddress -file $RDPFile
        Set-Content -Encoding Ascii -Value ( $rdp_settings -f $address) -Path $RDPFile
    }
}
