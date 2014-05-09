#require -version 3.0
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)]
    [string] $admin_account,

    [Parameter(Mandatory=$true)]
    [string[]] $users_upn,

    [string] $global_license = "gtus365:ENTERPRISEPACK",
    [string[]] $licenses = @("SHAREPOINTWAC","SHAREPOINTENTERPRISE")
)

function CheckFor-ExistingLicenses 
{
    param(
        [string[]] $user_licenses
    )

    Set-Variable -Name licensed -Value $true

    foreach( $license in $licenses ) {
        if( $license -notin $user_licenses ) { $licensed = $false }
    }

    return $licensed
}

function Get-DisabledPlans
{
    param(
        [string] $desired_licenses
    )
    Set-Variable -Name license_options -Value @("RMS_S_ENTERPRISE","OFFICESUBSCRIPTION","MCOSTANDARD","EXCHANGE_S_ENTERPRISE","SHAREPOINTWAC","SHAREPOINTENTERPRISE")
    return ($license_options | where { $_ -notin $licenses })
}


Add-PSSnapin Quest.* -ErrorAction Stop

Import-Module (Join-Path $PWD.Path "Office365_Credentials.psm1")
Import-Module MSOnline -DisableNameChecking -ErrorAction Stop
Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking -ErrorAction Stop

Connect-MsolService -Credential (Get-Office365Creds -account $admin_account)

Set-Variable -Name location -Value "US" -Option Constant
Set-Variable -Name msolicense_options -Value ( New-MsolLicenseOptions -AccountSkuId $global_license -DisabledPlans (Get-DisabledPlans -desired_licenses $licenses) )

foreach( $user_upn in $users_upn ) {
    $user_licenses = @(Get-MsolUser -UserPrincipalName $user_upn | 
                            Select -ExpandProperty Licenses |
                            Select -ExpandProperty ServiceStatus | 
                            Where { $_.ProvisioningStatus -eq "Success" } |
                            Select -ExpandProperty ServicePlan | 
                            Select -Expand ServiceName
                            )

    if( !(CheckFor-ExistingLicenses -user_licenses $user_licenses) ) {       
        Write-Host ("[{0}] - Granting {1} the {2} license . . ." -f $(Get-Date), $user_upn, [string]::join( ",", $msolicense_options))
        Set-MsolUser -UserPrincipalName $user_upn -UsageLocation $location
        Set-MsolUserLicense -UserPrincipalName $user_upn  -AddLicenses $global_license -LicenseOptions $msolicense_options -Verbose
    }
    else {
        Write-Host ("[{0}] - {1} already has all licenses - {2} - granted to them . . ." -f $(Get-Date), $user_upn, [string]::join( ",", $user_licenses))
    }
}
