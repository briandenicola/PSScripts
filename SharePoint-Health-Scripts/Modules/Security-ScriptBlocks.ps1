Set-Variable -Name check_server_admins -Value ( [ScriptBlock] {
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")

    return ( New-Object PSObject -Property @{
        Computer = $env:COMPUTERNAME
        Users = Get-LocalAdmins -computer .
    })
})

Set-Variable -Name check_managed_accounts -Value ( [ScriptBlock]  {
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
    Get-SPManagedAccount | Select UserName
})

Set-Variable -Name check_trusted_certs_store -Value ( [ScriptBlock]  {
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
    Get-SPTrustedRootAuthority | Select Certificate, Name | Format-List
    Get-SPTrustedServiceTokenIssuer | Select Name, SigningCertificate | Format-list
})

Set-Variable -Name check_farm_administrators -Value ( [ScriptBlock] { 
      . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
    $web = Get-SPWeb ("http://{0}:10000" -f $env:COMPUTERNAME)
    $web.Groups["Farm Administrators"] | Select -ExpandProperty Users
})