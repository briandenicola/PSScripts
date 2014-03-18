[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[Parameter(Mandatory=$true)]
	[ValidateSet("development", "test", "uat", "production")]
	[string] $env,

	[string] $farm = "2010",

    [ValidateSet("windows", "sql", "profiles", "search", "services", "iis", "logs", "security", "solutions", "health")]
	[string[]] $operations = @("windows", "sql", "profiles", "search", "services", "iis", "security", "solutions", "health")
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
. (Join-Path $PWD.Path "Modules\Check-Functions.ps1")
. (Join-Path $PWD.Path "Modules\Misc-ScriptBlocks.ps1")
. (Join-Path $PWD.Path "Modules\Search-ScriptBlocks.ps1")
. (Join-Path $PWD.Path "Modules\UserProfile-ScriptBlocks.ps1")
. (Join-Path $PWD.Path "Modules\Security-ScriptBlocks.ps1")
. (Join-Path $PWD.Path "Modules\ServiceApplication-ScriptBlocks.ps1")

Set-Variable -Name options -Value @(
    @{Name="windows"; Function="Check-Windows"},
    @{Name="sql"; Function="Check-SQL"},
    @{Name="profiles"; Function="Check-UserProfiles"},
    @{Name="search"; Function="Check-Search"},
    @{Name="services"; Function="Check-Services"},
    @{Name="iis"; Function="Check-IIS"},
    @{Name="security"; Function="Check-Security"},
    @{Name="solutions"; Function="Check-solutions"},
    @{Name="logs"; Function="Check-ULSLogs"},
    @{Name="health"; Function="Check-HealthRule"}
)

Set-Variable -Name log_file -Value (Join-Path $PWD.PATH ( Join-Path "logs" ("{0}-{1}-environmental-validation-{2}.log" -f $env,$farm,$(Get-Date).ToString("yyyyMMddmmhhss"))) ) -Option AllScope
Set-Variable -Name url -Value "http://teamadmin.gt.com/sites/ApplicationOperations/"

log -txt "Getting SharePoint and SQL servers for $env environment"
Set-Variable -Name systems -Value (Get-Servers-To-Process -farm $farm -env $env) -Option AllScope
Set-Variable -Name server_session -Value (New-PSSession -Computer $systems.Servers -Authentication CredSSP -Credential (Get-Creds)) -Option AllScope
Set-Variable -Name ca_session -Value (New-PSSession -ComputerName $systems.CAServer -Authentication Credssp -Credential (Get-Creds)) -Option AllScope

Write-Host ("Logging Output to {0} . . . " -f $log_file) -ForegroundColor Green

foreach( $operation in $operations ) {
    $option = $options | Where { $_.Name -eq $operation }
    Write-Verbose -Message ( "Calling {0} to check on {1} Configuration . . ." -f $option.Function, $option.Name)
    &$option.Function
}

Get-PSSession | Remove-PSSession 