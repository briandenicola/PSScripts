[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)][string] $ComputerName
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")

if ( Test-Connection -Count 1 -ComputerName $ComputerName ) {
    Write-Verbose -Message ("Working on {0} ..." -f $ComputerName)
    Get-WmiObject -computerName $ComputerName -Class win32_quickfixengineering | where-Object {$_.description -like "*Update*"} | Sort-Object hotfixID | Format-Table hotfixId, description 
}
