#############################
#Work in Progress Code.  Just checking in for backup.
#############################
[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[Parameter(Mandatory=$true)]
    [ValidateSet("backup", "deploy", "validate")]
    [string] $operation,
	[string] $cfg = '.\config\deploy.xml',
	[switch] $force,

    [Parameter(ParameterSetName="Component",Mandatory=$true)][string] $url,

    [Parameter(ParameterSetName="Application",Mandatory=$true)][string] $app,
    [Parameter(ParameterSetName="Application",Mandatory=$true)][string] $environment
)

Import-Module (Join-Path $PWD.Path "Modules\DeploymentMap.psm1")
Import-Module (Join-Path $ENV:SCRIPTS_HOME "\Libraries\Credentials.psm1")

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $PWD.Path "Modules\ConfigIO_Functions.ps1")

Set-Variable -Name global:Version -Value (New-Object System.Version "3.0.2")
Set-Variable -Name global:LogFile -Value (Join-Path $PWD.Path ("logs\deployment-tracker-{0}.log" -f $(Get-Date).ToString("yyyyMMdd.hhmmss"))) -Option Constant

if( (Get-Creds) -eq $nul ) { Set-Creds } 
$global:Cred = Get-Creds
$cfgFile = [xml]( Get-Content $cfg )

switch ($PsCmdlet.ParameterSetName)
{ 
    "Application" { 
        $app_components = $cfgFile.configs.application | where { $_.Name -eq $app -and $_.Environment -eq $environment } | Select -Expand Component
        foreach( $component in $components ) { 
            Execute-ComponentCommand -url $url -operation $operation
        } 
    }
        
    "Component" { 
        Execute-ComponentCommand -url $url -operation $operation
    }
}
