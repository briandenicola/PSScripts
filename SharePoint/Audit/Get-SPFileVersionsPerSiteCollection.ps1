[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [parameter(mandatory=$true)]
	[string] $url,
    [parameter(mandatory=$true)]
    [string] $output,
	[switch] $recurse
)

. (Join-Path $ENV:SCRIPTS_HOME "\Libraries\Standard_functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "\Libraries\SharePoint_functions.ps1")

$global:out = @()
$global:name = $nul
$global:op = $nul
$global:value = $nul
$global:filter = $nul

function Get-SPDocLibraries
{
    param(
         [object] $site 
    ) 
	return ( $site.Lists | where { $_.BaseTemplate -eq "DocumentLibrary" } )
}

function Get-SPFiles
{
    param(
        [object] $list
    )

    foreach( $item in $list.Items ) {
		$global:out += $item.Versions | Select @{N="Name";E={$item.Name}},  @{N="Folder";E={$item.File.ParentFolder}},  @{N="Url";E={$item.File.ServerRelativeUrl}}, @{N="Version";E={$_.VersionLabel}}, Created, @{N="Created By";E={$_.CreatedBy.LookUpValue}}
    }

}

function main() 
{
	$site = Get-SPSite -url $url
	
	Write-Verbose ("[" + $(Get-Date) + "] - Working on " +  $site.RootWeb.Url.ToString() + " . . .")
	foreach( $list in (Get-SPDocLibraries -site $site.RootWeb ) ){
        Get-SPFiles -list $list
    }

	if( $recurse ) {
		foreach( $web in ($site.AllWebs | Where { $_ -inotmatch $site.RootWeb } ) ) { 
			Write-Verbose ("[" + $(Get-Date) + "] - Working on " + $web.Url.ToString() + " . . .")
			foreach( $list in (Get-SPDocLibraries -site $web ) ){
                Get-SPFiles -list $list
            }
		}
	}

	$global:out | Export-Csv $output -encoding ASCII 
}
main