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
    [Parameter(ParameterSetName="Application",Mandatory=$true)][string] $app
)

Import-Module (Join-Path $PWD.Path "Modules\cache.psm1")
Import-Module (Join-Path $ENV:SCRIPTS_HOME "\Libraries\Credentials.psm1")

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $PWD.Path "Modules\Deploy_Functions.ps1")

$global:Version = New-Object System.Version "3.0.0"

if( (Get-Creds) -eq $nul ) { Set-Creds } 
$global:Cred = Get-Creds
$cfgFile = [xml]( Get-Content $cfg )

function Do-Component 
{
    param (
        [string] $url,
        [switch] $operation
    )

    $url = $url -replace ("http://|https://")
    $cfg = $cfgFile.configs.config | Where { $_.Url -eq $url }

	if( $cfg -eq $nul ) {
		throw "Could not find an entry for the URL in the XML configuration"
	}
	
	$deployment_map = Get-DeploymentMapCache -url $url 
	if( $deployment_map -eq $nul -or $force -eq $true )	{
		$deployment_map = Get-DeploymentMap -url $url -config $cfg
		Set-DeploymentMapCache -map $deployment_map -url $url
	}

	if( ($deployment_map | Select -First 1 Source).Source -eq $nul ) {	
		throw  "Could not find any deployment mappings for the url"
	}
		
	switch($operation)
	{
		backup 		{ Backup-Config $deployment_map }
		validate	{ Validate-Config $deployment_map }
		deploy		{ Deploy-Config $deployment_map }
	}
}

try { 
    switch ($PsCmdlet.ParameterSetName)
    { 
        "Application" { 
            $app_components = $cfgFile.configs.apps.app | where { $_.Name -eq $app } | Select -Expand Components
            foreach( $component in $components ) { 
                Do-Component -url $url -operation $operation
            } 
        }
        
        "Component" { 
            Do-Component -url $url -operation $operation
        }
    }


}
catch [Exception] {
	Write-Error ("Exception has occured with the following message - " + $_.Exception.ToString())
}