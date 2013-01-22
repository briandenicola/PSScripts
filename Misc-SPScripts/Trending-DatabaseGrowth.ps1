[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [switch] $upload
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Variables.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")

$ca_admins = Get-SharePointCentralAdmins | Where { $_.Farm -imatch "2010" -and $_.Environment -eq "Production" }

$password = "01000000d08c9ddf0115d1118c7a00c04fc297eb01000000bf38d433df735244bbb3b2d43f2cfde40000000002000000000003660000c000000010000000a0c800b70093081ea6792691e73ac74e0000000004800000a00000001000000060aacaee216b125f55435db5a2e29751180000007d17cdb3802a5bfd9f4e491d2efd51aaa590b0f52321a4ec14000000116b58122333bea88d6f90452c349aa5a3c995c8"
$cred =  New-Object System.Management.Automation.PSCredential ( ($ENV:userdomain + "\" + $env:USERNAME) , (ConvertTo-SecureString $password))

$sb = { 
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")

    return ( Get-SPDatabase | Where { $_.Type -eq "Content Database" } | Select Name, Server, @{Name="Size";Expression={$_.DiskSizeRequired/1mb}}, @{Name="Sites";Expression={$_.CurrentSiteCount}} )

}

$dbs = Invoke-Command -ComputerName ($ca_admins | Select -ExpandProperty SystemName ) -Credential $cred -Authentication Credssp -ScriptBlock $sb |
    Select Name, Server, Size, Sites

if( $upload ) {
    foreach( $db in $dbs ) {
        $db | Add-Member -MemberType NoteProperty -Name TimeStamp -Value $(Get-Date).ToString("MM/dd/yyyy")
        WriteTo-SPListViaWebService -url $global:SharePoint_url -list $global:SharePoint_db_list -Item (Convert-ObjectToHash $db) -TitleField TimeStamp
    }
}
else {
    return $dbs
} 
