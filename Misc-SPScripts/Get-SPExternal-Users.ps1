[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [string[]] $urls,
    [string] $file
)

. (Join-Path $env:SCRIPTS_HOME "Libraries\Standard_functions.ps1" )
. (Join-Path $env:SCRIPTS_HOME "Libraries\SharePoint_functions.ps1" )

if( (Test-Path (Join-Path $env:SCRIPTS_HOME "Libraries\SharePoint2010_functions.ps1") ) ) {
    . (Join-Path $env:SCRIPTS_HOME "Libraries\SharePoint2010_functions.ps1" )
}

$results = @()
foreach( $url in $urls ) {
    Write-Verbose "[ $(Get-Date).ToString() ] - Working on $url ..."
    $site = Get-SPSite $url
    foreach( $web in $site.AllWebs ) { 
        Write-Verbose "[ $(Get-Date).ToString() ] - Working on $web . . ."
        Write-Verbose ("[ $(Get-Date).ToString() ] - Users: " + $web.AllUsers + " . . . ")
        $results += $web.AllUsers | Where { $_.LoginName -imatch "ext:" } | Select @{N="Url";E={$site.url}},  @{N="Site";E={$web.ServerRelativeUrl}},Name, Email, LoginName, Groups
    }
}

if( ! [string]::IsNullOrEmpty($file) ) {
    Write-Verbose "Saving Results to $file"
    $results | Export-Csv -Encoding ASCII -Path $file -ErrorAction SilentlyContinue
}
else {
    $results
}
    