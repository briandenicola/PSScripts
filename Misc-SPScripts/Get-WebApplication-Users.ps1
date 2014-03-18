#requires -version 2
[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [Parameter(Mandatory=$true)][string] $url,
    [Parameter(Mandatory=$true)][string] $file
)

Set-StrictMode -Version 2.0

. (Join-Path $env:SCRIPTS_HOME "Libraries\Standard_functions.ps1" )
. (Join-Path $env:SCRIPTS_HOME "Libraries\SharePoint2010_functions.ps1" )

$results = @()
Write-Verbose ("[" + $(Get-Date) + "] - Working on $url ...")

$web_application = Get-SPWebApplication $url

foreach( $site in $web_application.Sites ) { 
    foreach( $web in $site.AllWebs ) { 
        Write-Verbose ("[" + $(Get-Date) + "] - Working on Web - $web . . .")
        $groups = $web.Groups | Select @{N="Url";E={$site.url}},  @{N="Site";E={$web.ServerRelativeUrl}}, @{N="Type";E={"Group"}}, Name, Users, Roles

        if( $groups -ne $null ) {
            foreach( $group in $groups ) {
                Write-Verbose ("[" + $(Get-Date) + "] - Working on Group - " + $group.Name + " . . .")
                if( $group.Users.Count -ne 0 ) {
                    $group.Users =  [string]::join( ";", ($group.Users | Select -Expand DisplayName))
                } 
                else { 
                    $group.Users = [string]::Empty
                }
                if( $group.Roles.Count -ne 0 ) {
                    $group.Roles =  [string]::join( ";", ($group.Roles | Select -Expand Name))
                } 
                else { 
                    $group.Roles = [string]::Empty
                }
                $results += $group
            }
        }

        $users = $web.Users | Select @{N="Url";E={$site.url}}, @{N="Site";E={$web.ServerRelativeUrl}}, @{N="Type";E={"Direct User Access"}}, Name, Roles
        if( $users -ne $null ) {
            foreach( $user in $users ) {
                Write-Verbose ("[" + $(Get-Date) + "] - Working on User - " + $user.Name + " . . .")
                if( $user.Roles.Count -ne 0 ) {
                    $user.Roles =  [string]::join( ";", ($user.Roles | Select -Expand Name))
                } 
                else { 
                    $user.Roles = [string]::Empty
                }
                $results += $user
            }
        }
    }
}

Write-Verbose ("[" + $(Get-Date) + "] - Saving Results to $file")
$results | Export-Csv -Encoding ASCII -Path $file -ErrorAction SilentlyContinue -NoTypeInformation    