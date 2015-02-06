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

function Get-DisabledPlans
{
    param(
        [string] $desired_licenses
    )
    Set-Variable -Name license_options -Value @("RMS_S_ENTERPRISE","OFFICESUBSCRIPTION","MCOSTANDARD","EXCHANGE_S_ENTERPRISE","SHAREPOINTWAC","SHAREPOINTENTERPRISE")
    return ($license_options | where { $_ -notin $licenses })
}

Add-PSSnapin Quest -ErrorAction SilentlyContinue
if(!(Get-Module -Name Office365)) { Import-Module (Join-Path $PWD.Path "Office365.psm1") }
Connect-MsolService -Credential (Get-Office365Creds -account $admin_account)

foreach( $user_upn in $users_upn ) {
    $user = Get-MsolUser -UserPrincipalName $user_upn

    if( $user.isLicensed -eq $true ) {
        $user_licenses = @( $user | Select -ExpandProperty Licenses | Select -ExpandProperty ServiceStatus | Where { $_.ProvisioningStatus -eq "Success" } |
                            Select -ExpandProperty ServicePlan | Select -Expand ServiceName )

        $licenses_to_disable = Get-DisabledPlans -desired_licenses ($user_licenses + $licenses)
        $opts = @{
            LicenseOptions = $null
        }
    }
    else {
        Set-MsolUser -UserPrincipalName $user_upn -UsageLocation $gtus365_location
        $licenses_to_disable = Get-DisabledPlans -desired_licenses $licenses
        $opts = @{
            AddLicenses = $global_license 
            LicenseOptions = $null
        }
    }


    Write-Host ("[{0}] - Granting {1} the {2} license.`n *** Once the licenses haven been granted it may take a minute or two replicate *** " -f $(Get-Date), $user_upn, [string]::join( ",", $licenses))
    $opts.LicenseOptions = New-MsolLicenseOptions -AccountSkuId $global_license -DisabledPlans $licenses_to_disable
    Set-MsolUserLicense -UserPrincipalName $user_upn @opts
}

Get-Office365UserLicense -users_upn $users_upn -admin_account $admin_account