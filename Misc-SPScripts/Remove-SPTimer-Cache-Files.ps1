[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[Parameter(Mandatory=$true)]
	[ValidateSet("development", "test", "uat", "production")]
	[string] $env,
	[string] $farm = "2010-"
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

$get_farm_id = {
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
    return( $id = Get-SPDatabase | Where { $_.Type -eq "Configuration Database" } | Select -ExpandProperty Id | Select -ExpandProperty Guid )
}

$remove_cache_files = {
	param(
		[string] $id
	)
	
	if( [string]::IsNullOrEmpty($id) ){
		throw "id can not be null . . "
	}
	
    $cache_dir = Join-Path 'c:\ProgramData\Microsoft\SharePoint\Config' $id

    Stop-Service -Name sptimerv4 -Force -Verbose

    Set-Location $cache_dir
    Move-Item (Join-Path $cache_dir 'cache.ini') (Join-Path $cache_dir ('cache.ini' + $(Get-Date).ToString("yyyyMMddhhmmss") ) )
    Remove-Item * -Exclude "*ini*"  
	
    1 | Out-File -Encoding ascii (Join-Path $cache_dir 'cache.ini')

    Start-Service -Name sptimerv4 -Verbose
}

$ca = Get-SharePointCentralAdmins | where { $_.Farm -match $farm -and $_.Environment -eq $env } | select -ExpandProperty Systemname
$id = Invoke-Command -ComputerName $ca -ScriptBlock $get_farm_id -Authentication CredSSP -Credential (Get-Creds)

if( [string]::IsNullOrEmpty($id) ) {
	throw "id can not be null . . "
}

$servers = Get-SharePointServersWS | where { $_.Farm -match $farm -and $_.Environment -eq $env } | select -ExpandProperty Systemname
$server_session = New-PSSession -Computer $servers -Authentication CredSSP -Credential (Get-Creds) 

Invoke-Command -Session $server_session -ScriptBlock $remove_cache_files -ArgumentList $id