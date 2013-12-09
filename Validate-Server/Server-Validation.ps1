#requires -version 3.0
[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [ParaMeter(Mandatory=$true)]
    [string[]] $computers,
    [ParaMeter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [string] $cfg,
    [switch] $log
)

. ( Join-Path $env:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. ( Join-Path $PWD.Path "Modules\Test-Cases.ps1")

Import-Module ( Join-Path $env:SCRIPTS_HOME "Libraries\credentials.psm1")

if( (Get-PSDrive -PSProvider FileSystem | where { $_.Root -eq "D:\" }) ) { $drive = "D" } else { $drive = "C" }

Set-Variable -Name rules -Value ( Get-Content -Raw $cfg | ConvertFrom-Json )
Set-Variable -Name log_file -Value (Join-Path $PWD.Path ("OutPut\server-validation-{0}.csv" -f $(Get-Date).ToString("yyyyMMddhhmmss") ) )
Set-Variable -Name result -Value $true
$creds = $null

function main {

    foreach( $computer in $computers ) {
        Write-Host ("[{0}] - == Testing Computer - {1} ===" -f  $(Get-Date), $computer )

        #Mandatory Checks
        if( -not ( Check-ServerAccess -computer $computer ) ) {
            Write-Warning ("ACCESS DENIED to $computer. Can not continue rule validation for this sytem...")
            Continue
        }

        if( (Test-Remoting -computer $computer) ) {
            Create-PSRemoteSession -computer $computer
        }
        else {
            Write-Warning ("PowerShell Removing Test Failed to $computer. Can not continue rule validation for this sytem...")
            Continue
        }
        #End Mandatory Checks

        foreach( $rule in $rules ) {

            switch ($rule.TypeName) {
                WindowsFeature {  $result = Test-WindowsFeature -computer $computer -rule $rule }             
                CredSSP { $result = Test-CredSSP -computer $computer -rule $rule }
                Environment { $result = Test-EnvVariable -computer $computer -rule $rule }
                ScheduleTask { $result = Test-ScheduleTask -computer $computer -rule $rule }
                Path { $result = Test-FilePath -computer $computer -rule $rule  }
                GroupMembership { $result =Test-GroupMemberShip -computer $computer -rule $rule } 
                Share { $result = Test-Share -computer $computer -rule $rule } 
                Version { $result = Test-PSVersion -computer $computer -rule $rule }
            }

            if( !$result -and $rule.OnError -eq "Stop" ) { break }
                 
        }
        Delete-PSRemoteSession -computer $computer
    }
    Write-Results -log_file $log_file -log:$log 
}
main