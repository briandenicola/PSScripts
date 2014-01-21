[CmdletBinding(SupportsShouldProcess=$true)]
param ( 
    [ValidateScript({Test-Path $_})]
	[Parameter(Mandatory=$true)][string] $config
)

#Load Libraries
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
. (Join-Path $PWD.Path "Modules\Deploy-Functions.v2.ps1")
. (Join-Path $PWD.Path "Modules\Log-Functions.ps1")

Import-Module (Join-Path $ENV:SCRIPTS_HOME "\Libraries\Credentials.psm1")

#Constants
Set-Variable -Name log_home -Value "D:\Logs" -Option Constant
Set-Variable -Name document_link  -Value "http://example.com/sites/AppOps/Lists/Tracker/DispForm.aspx?ID={0}"
Set-Variable -Name team_site -Value "http://example.com/sites/AppOps/" -Option Constant
Set-Variable -Name team_list -Value "Deployment Tracker" -Option Constant
Set-Variable -Name team_view -Value '{}' -Option Constant

try
{
    $cfg = [xml] ( Get-Content $cfg )
    Set-Variable -Name app -Value $cfg.Parameters.App -Option AllScope
    Set-Variable -Name environment -Value $cfg.Parameters.Environment -Option AllScope
    Set-Variable -Name log -Value (Join-Path $log_home ("Deploy-For-" + $app + "-From-" + $ENV:COMPUTERNAME + "-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".log"))

    Start-Transcript -Append -Path $log

    Log-Step -step "Automated with $($MyInvocation.InvocationName) from $ENV:COMPUTERNAME . . ." -nobullet
    Log-Step -step ("<strong>{0} {1} Steps Taken include - <ol>" -f $app, $environment) -nobullet

    foreach( $step in $cfg.steps.step ) {
        if( $step.Source ) { $step.Source = Join-Path $cfg.Parameters.MasterDeployLocation $step.Source }
        Invoke-Expression $step.ScriptBlock -config $step
    } 

    Log-Step -step "</ol><hr/>" -nobullet
    Record-Deployment -code_number $cfg.Parameters.BuildNumber -code_version $cfg.Parameters.VersionNumber
    Stop-Transcript
}
catch {
    Write-Error ("An exception occurred - {0}" -f $_.Exception.ToString() )

}