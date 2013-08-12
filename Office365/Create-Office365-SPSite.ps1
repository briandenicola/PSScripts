[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)]
    [string] $admin_account,

    [Parameter(Mandatory=$true)]
    [string] $site_name,

    [Parameter(Mandatory=$true)]
    [string] $owner,

    [ValidateSet("STS#0", "DEV#0", "BLANKINTERNETCONTAINER#0")]
    [string] $template = "STS#0",

    [ValidateRange(1000,4000)]
    [int] $quota = 1000
)

Set-Variable -Name team_site -Value "http://teamadmin.gt.com/sites/ApplicationOperations/" -Option Constant
Set-Variable -Name admin_site -Value "https://gtus365-admin.sharepoint.com" -Option Constant
Set-Variable -Name office365_list -Value "Office365 Sites" -Option Constant
Set-Variable -Name office365_url -Value "https://gtus365.sharepoint.com/sites/" -Option Constant

Import-Module MSOnline -DisableNameChecking
Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking

Connect-SPOService -url $admin_site -Credential $admin_account

$url = $office365_url + $site_name
New-SPOSite -Url $url -Owner $owner -StorageQuota $quota -Template $template

Get-SPOSite

$site = @{
		Url = $url
        Owner = $owner
        Quota = $quota
        Template = $template
        Active = 1
}
WriteTo-SPListViaWebService -url $team_site -list $office365_list -Item $site -TitleField Url