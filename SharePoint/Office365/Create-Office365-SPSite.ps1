[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)]
    [string] $admin_account,

    [Parameter(Mandatory=$true)]
    [string[]] $sites,

    [Parameter(Mandatory=$true)]
    [string] $owner,

    [ValidateSet("STS#0", "DEV#0", "BLANKINTERNETCONTAINER#0")]
    [string] $template = "STS#0",

    [ValidateRange(1000,4000)]
    [int] $quota = 1000
)

Import-Module (Join-Path $PWD.Path "Office365_Credentials.psm1")
Import-Module MSOnline -DisableNameChecking
Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking

Set-Variable -Name team_site -Value "" -Option Constant
Set-Variable -Name admin_site -Value "" -Option Constant
Set-Variable -Name office365_list -Value "Office365 Sites" -Option Constant

Connect-SPOService -url $admin_site -Credential (Get-Office365Creds -account $admin_account)

foreach( $site in $sites ) {
    $url = $o365_office365_url + $site
    New-SPOSite -Url $url -Owner $owner -StorageQuota $quota -Template $template

    if( $? -eq $true ) {
        $record = @{ Url = $url; Owner = $owner; Quota = $quota; Template = $template; Active = 1 }
        WriteTo-SPListViaWebService -url $team_site -list $office365_list -Item $record -TitleField Url
    }
    else {
       Write-Error "[$(Get-Date) ] - $url failed to create . . ." 
    }
}
Get-SPOSite