[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [parameter(mandatory=$true)]
	[string] $url,
    [parameter(mandatory=$true)]
    [string] $list,
    [string] $log = [string]::empty 
)

. (Join-Path $ENV:SCRIPTS_HOME "\Libraries\Standard_functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "\Libraries\SharePoint_functions.ps1")

Set-Variable -Name items -Value @()
Set-Variable -Name CheckedInComment -Value "This file was checked in by the SharePoint Administrator"

function Get-SPDocLibraries
{
    param([object] $site) 
	return ( $site.Lists | where { $_.BaseTemplate -eq "DocumentLibrary" -and $_.Title -eq $list } )
}

$results = @()
function main() 
{
	$web = Get-SPWeb -url $url

    Write-Host "[WARNING!!!] - This script will checkin all files in the list - $list in the site $url . . ."
    Read-Host -Prompt "Press Any Key to Continue or CTRL-C to exit"
	
	Write-Verbose ("[" + $(Get-Date) + "] - Working on " +  $site.RootWeb.Url.ToString() + " . . .")
	$list = Get-SPDocLibraries -site $web
    $checked_out_files = $list.CheckedOutFiles

    foreach( $item in $list.Items ) {
        if( $item.File.CheckOutStatus -ne "None" ) {

            $file = $checked_out_files | Where { $_.ListItemId -eq $item.id }
            $file.TakeOverCheckOut()

            $results += ( New-Object PSObject -Property @{ 
                Name = $item.Name
                Folder = $item.ParentFolder 
                CheckedOutBy = $file.CheckedOutByName
                CheckedOutDate = $file.TimeLastModified
                Id = $item.Id
            })
            Write-Verbose ("[" + $(Get-Date) + "] - Checking In - " + $item.Name )
            $item.File.CheckIn($CheckedInComment)
        }
    }

    if( $log -ne [string]::Empty ) {
        $results | Export-Csv -NoTypeInformation -Encoding ASCII $log
    }
}
main