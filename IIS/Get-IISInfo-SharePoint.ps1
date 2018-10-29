[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $true)]
    [String] $central_admin,

    [Parameter(Mandatory = $true)]
    [String] $url,

    [switch] $upload,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Test", "Uat", "Production", "Development")]
    [string] $environment = "Production",

    [Parameter(Mandatory = $true)]
    [ValidateSet("2010-External", "2010-Internal", "2010-Services", "2013-Archive")]
    [string] $farm = "2010-External"
)

. ( Join-Path $PWD.Path ".\Modules\Query-IIS-Helper-Functions.ps1" )

Import-Module (Join-Path $ENV:SCRIPTS_HOME "Libraries\Credentials.psm1")

Set-Variable -Name list_url -Value "" -Option Constant
Set-Variable -Name web_servers -Value @{ Name = "Servers"; View = "{}" } -Option Constant
Set-Variable -Name sql_servers -Value @{ Name = "SQL Servers"; View = "{}" } -Option Constant
Set-Variable -Name list_websites -Value "WebApplications" -option Constant
Set-Variable -Name iis_audit_sb -Value ( Get-ScriptBlock ".\Modules\Query-SharePoint-For-IIS-Settings-ScriptBlock.ps1")

$audit_results = @(Invoke-Command -ComputerName $central_admin -ScriptBlock $iis_audit_sb -Credential (Get-Creds) -Authentication Credssp -ArgumentList $url, $environment, $farm )
    
if ( $upload ) {
    $results = $audit_results | Select * -ExcludeProperty PSComputerName, RunSpaceId, PSShowComputerName
    Upload-Results -results $results  -sql $sql_servers -list_url $list_url -web $web_servers
}
else {
    return $audit_results
}