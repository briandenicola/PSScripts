#require -version 3.0
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)]
    [string] $admin_account,

    [Parameter(Mandatory=$true)]
    [string[]] $users,

    [Parameter(Mandatory=$true)]
    [string] $license
)

Import-Module (Join-Path $PWD.Path "Office365_Credentials.psm1")
Import-Module Quest -ErrorAction Stop
Import-Module MSOnline -DisableNameChecking -ErrorAction Stop
Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking -ErrorAction Stop

Set-Variable -Name location -Value "US" -Option Constant
Set-Variable -Name global_license -Value "" -Option Constant

Connect-SPOService -url $admin_site -Credential (Get-Office365Creds -account $admin_account)

foreach( $user in $user ) {
    $user_upn = Get-QADUser $user | Select -ExpandProperty UPN
    $user_license = Get-MsolUser -UserPrincipalName $user_upn | Select -ExpandProperty License

    if( $user_license -ne $global_license -ne $user_license -ne $license ) {
        Write-Host ("[{0}] - Granting {1} the {2} license . . ." -f $(Get-Date), $user, $license)
        Set-MsolUser -UserPrincipalName $user_upn -UsageLocation $location
        Set-MsolUserLicense -UserPrincipalName $user -AddLicenses $license -Verbose
    }
    else {
        Write-Host ("[{0}] - {1} already has the {2} license granted to them . . ." -f $(Get-Date), $user, $license)
    }
}
