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

Set-Variable -Name items -Value @()
Set-Variable -Name CheckedInComment -Value "This file was checked in by the SharePoint Administrator"

function Get-SPDocLibraries
{
    param(
         [object] $site 
    ) 
	return ( $site.Lists | where { $_.BaseTemplate -eq "DocumentLibrary" } )
}

function Get-CheckedOutFiles
{
    param(
        [object] $list
    )

    return $list.CheckedOutFiles

}

function main() 
{
	$site = Get-SPSite -url $url
	
	Write-Verbose ("[" + $(Get-Date) + "] - Working on " +  $site.RootWeb.Url.ToString() + " . . .")
	foreach( $list in (Get-SPDocLibraries -site $site.RootWeb ) ){
        $items += Get-CheckedOutFiles -list $list
    }

	if( $recurse ) {
		foreach( $web in ($site.AllWebs | Where { $_ -inotmatch $site.RootWeb } ) ) { 
			Write-Verbose ("[" + $(Get-Date) + "] - Working on " + $web.Url.ToString() + " . . .")
			foreach( $list in (Get-SPDocLibraries -site $web ) ){
                $items += Get-CheckedOutFiles -list $list
            }
		}
	}

    if( ! [string]::IsNullOrEmpty($items[1]) ) {
	    $items | Select LeafName, DirName, CheckedOutByName, TimeLastModified | Export-Csv $output -encoding ASCII -NoTypeInformation
    } else {
        Write-Host "[ $(Get-Date) ] - No checked out files found in $url . . ."
    }

}
main