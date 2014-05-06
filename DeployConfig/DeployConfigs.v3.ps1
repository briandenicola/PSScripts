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

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $PWD.Path "Modules\ConfigIO_Functions.ps1")

Set-Variable -Name global:Version -Value (New-Object System.Version "3.0.4")

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
