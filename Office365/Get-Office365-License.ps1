#require -version 3.0
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)]
    [string] $admin_account,

    [Parameter(Mandatory=$true)]
    [string[]] $users_upn,

    [string] $global_license = "gtus365:ENTERPRISEPACK"
)
Add-PSSnapin Quest.* -ErrorAction Stop

Import-Module (Join-Path $PWD.Path "Office365_Credentials.psm1")
Import-Module MSOnline -DisableNameChecking -ErrorAction Stop
Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking -ErrorAction Stop

Connect-MsolService -Credential (Get-Office365Creds -account $admin_account)

foreach( $user_upn in $users_upn ) {
    $user_licenses = @(Get-MsolUser -UserPrincipalName $user_upn | 
                            Select -ExpandProperty Licenses |
                            Select -ExpandProperty ServiceStatus | 
                            Where { $_.ProvisioningStatus -eq "Success" } |
                            Select -ExpandProperty ServicePlan | 
                            Select -Expand ServiceName
                            )
    Write-Host ("[{0}] - User {1} has licenses - {2} - granted in Office 365 . . ." -f $(Get-Date), $user_upn, [string]::join(",", $user_licenses) )
}