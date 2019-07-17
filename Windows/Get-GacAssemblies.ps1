param(		
    [Parameter(Mandatory = $false)]
    [ValidateSet("v2.0", "v4.0")]
    [string] $TargetFramework = "v2.0|v4.0"
)

function Get-Architecture {
    param( [string] $Path )
    if ( $Path -imatch "_64"   ) { return "AMD64" }
    if ( $Path -imatch "_MSIL" ) { return "MSIL"  }
    return "x86"
}

$gac_locations = @(
    @{ "Path" = "C:\Windows\assembly"; "Version" = "v2.0" },
    @{ "Path" = "C:\Windows\Microsoft.NET\assembly"; "Version" = "v4.0" }
)

Set-Variable -Name assemblies -Value @()

foreach ( $location in ($gac_locations | Where-Object Version -imatch $TargetFramework) ) {
    $framework = $location.Version 
    foreach ( $assembly in (Get-ChildItem -Path $location.Path -Include "*.dll" -Recurse) ) {
        $public_key = $assembly.Directory.Name.Split("_") | Select-Object -Last 1
    
        $properties = [ordered] @{
            Name         = $assembly.BaseName
            Version      = $assembly.VersionInfo.ProductVersion
            PublicKey    = $public_key
            LastModified = $assembly.LastWriteTime
            Framework    = $framework
            Architecture = Get-Architecture -Path $assembly.FullName 
        }
    
        $assemblies += (New-Object PSObject -Property $properties)
    } 
}

return $assemblies