#require -version 3.0
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)]
    [string] $admin_account,

    [Parameter(Mandatory=$true)]
    [string[]] $users,

    [string] $global_license = "gtus365:ENTERPRISEPACK"
)
Add-PSSnapin Quest.* -ErrorAction Stop

Import-Module (Join-Path $PWD.Path "Office365_Credentials.psm1")
Import-Module MSOnline -DisableNameChecking -ErrorAction Stop
Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking -ErrorAction Stop

Connect-MsolService -Credential (Get-Office365Creds -account $admin_account)

foreach( $user in $users ) {
    $user_upn = Get-QADUser -Name "$user*" | Select -ExpandProperty UserPrincipalName

    if( $user_upn ) {
        $user_licenses = @(Get-MsolUser -UserPrincipalName $user_upn | 
                                Select -ExpandProperty Licenses |
                                Select -ExpandProperty ServiceStatus | 
                                Where { $_.ProvisioningStatus -eq "Success" } |
                                Select -ExpandProperty ServicePlan | 
                                Select -Expand ServiceName
                                )
        Write-Host ("[{0}] - User {1} has licenses - {2} - granted in Office 365 . . ." -f $(Get-Date), $user, [string]::join(",", $user_licenses) )
    }
    else {
        Write-Error ("[{0}] - Could not find {1} . . ." -f $(Get-Date), $user)
    }
}

