Set-Variable -Name o365_subscription_name -Value "" -Option Constant
Set-Variable -Name o365_location -Value "US" -Option Constant
Set-Variable -Name o365_admin_url -Value ("https://{0}-admin.sharepoint.com" -f $o365_subscription_name) -Option Constant
Set-Variable -Name o365_office365_url -Value ("https://{0}.sharepoint.com/sites/" -f $o365_subscription_name) -Option Constant

Import-Module MSOnline -DisableNameChecking -ErrorAction Stop
Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking -ErrorAction Stop

function Set-Office365Creds 
{
    param ([string] $account )
	$SCRIPT:offic365_creds = Get-Credential $account
}

function Get-Office365Creds 
{
    param ( [string] $account )
	if( $SCRIPT:offic365_creds -eq $nul ) { Set-Office365Creds -account $account }
	return $SCRIPT:offic365_creds
}

function Get-Office365UserLicense 
{
    param(
        [Parameter(Mandatory=$true)]
        [string] $admin_account,

        [Parameter(Mandatory=$true)]
        [string[]] $users_upn,

        [string] $global_license = ("{0}:ENTERPRISEPACK" -f $o365_subscription_name)
    )

    Add-PSSnapin Quest -ErrorAction SilentlyContinue
    Connect-MsolService -Credential (Get-Office365Creds -account $admin_account)

    $rights = @()
    foreach( $user_upn in $users_upn ) {  
        $rights += (Get-MsolUser -UserPrincipalName $user_upn | 
            Select -ExpandProperty Licenses |
            Select -ExpandProperty ServiceStatus | 
            Select @{N="User";E={$user_upn}},@{N="Service";E={$_.ServicePlan.ServiceName}}, @{N="License";E={$_.ProvisioningStatus}} )
    }

    return $rights

}

function Get-GTSPOnlineSites 
{
    Connect-SPOService -url $admin_site -Credential (Get-Office365Creds -account $admin_account)
    Get-SPOSite
}
 
Export-ModuleMember -Function Set-Office365Creds, Get-Office365Creds, Get-GTSPOnlineSites, Get-Office365UserLicense -Variable o365_location, o365_office365_url, o365_admin_url