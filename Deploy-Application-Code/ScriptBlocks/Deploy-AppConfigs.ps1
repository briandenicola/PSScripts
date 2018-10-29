#require -version 3.0
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("backup", "deploy", "validate")]
    [string] $operation,
    [string] $cfg = (Join-Path -Path $app_home -ChildPath "Config\deploy_config.xml"),
    [switch] $force,

    [Parameter(ParameterSetName = "Component", Mandatory = $true)][string] $url,

    [Parameter(ParameterSetName = "Application", Mandatory = $true)][string] $app,
    [Parameter(ParameterSetName = "Application", Mandatory = $true)][string] $environment
)

Import-Module (Join-Path -Path $app_home -ChildPath "Modules\ConfigFile-DeploymentMap.psm1") -Force
. (Join-Path -Path $app_home -ChildPath "Modules\ConfigFile-Functions.ps1")

$cfgFile = [xml]( Get-Content $cfg )

switch ($PsCmdlet.ParameterSetName) { 
    "Application" { 
        $app_components = $cfgFile.configs.application | where { $_.Name -eq $app -and $_.Environment -eq $environment } | Select -Expand Component
        foreach ( $component in $app_components ) { 
            Log -text ("Executing {0} on {1} . . ." -f $operation, $component)
            Execute-ComponentCommand -url $component -operation $operation
            "=" * 50 
        } 
    }
        
    "Component" { 
        Log -text ("Executing {0} on {1} . . ." -f $operation, $url)
        Execute-ComponentCommand -url $url -operation $operation
    }
}

Get-PSSession | Remove-PSSession 