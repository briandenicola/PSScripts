#requires -version 3.0
[CmdletBinding(SupportsShouldProcess=$true)]
param ( 
    [ValidateScript({Test-Path $_})]
	[Parameter(Mandatory=$true)] [string] $Config,
    [ValidateRange(0,100)]
    [Parameter(Mandatory=$false)][int]    $StartStep = 0
)

#Load Libraries
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")

. (Join-Path $PWD.Path "Modules\Standard-Variables.ps1")
. (Join-Path $PWD.Path "Modules\Deploy-Functions.ps1")
. (Join-Path $PWD.Path "Modules\Log-Functions.ps1")
. (Join-Path $PWD.Path "Modules\Miscellaneous-Functions.ps1")

Import-Module (Join-Path $ENV:SCRIPTS_HOME "Libraries\Credentials.psm1")

try
{
    $cfg = [xml] ( Get-Content $config )

    Set-Variable -Name app -Value $cfg.Deployment.Parameters.App -Option AllScope
    Set-Variable -Name environment -Value $cfg.Deployment.Parameters.Environment -Option AllScope   
    
    if(![bool]$WhatIfPreference.IsPresent) {
        try{Stop-Transcript|Out-Null} catch {}
        Start-Transcript -Append -Path $global:log_file
    }

    if($StartStep -eq 0 ) { 
        Log-Step -step "Automated with $($MyInvocation.InvocationName) from $ENV:COMPUTERNAME . . ." -nobullet
        Log-Step -step ("<strong>{0} {1} Steps Taken include - <ol>" -f $app, $environment) -nobullet
    }
    else {
		$StartStep -= 1
        Get-LoggedSteps
    }

    $steps = @($cfg.Deployment.steps.step)
    foreach( $step in $steps[$StartStep .. $steps.Length]) {
        if( $step.Source ) { $step.Source = (Join-Path $cfg.Deployment.Parameters.MasterDeployLocation $step.Source).ToString() }
        &$step.ScriptBlock -config $step
    } 

    Log-Step -step "</ol><hr/>" -nobullet
    Record-Deployment -code_number $cfg.Deployment.Parameters.Build -code_version $cfg.Deployment.Parameters.Version -environment $cfg.Deployment.Parameters
}
catch {
    Flush-LogSteps
    Write-Error ("An exception occurred - {0}" -f $_.Exception.ToString() )   
    Write-Error ("State has been written to {0}" -f (Get-EmergencyLogFile) )
}
finally {
    Set-Location -Path $app_home 
    if(![bool]$WhatIfPreference.IsPresent) { Stop-Transcript }
}