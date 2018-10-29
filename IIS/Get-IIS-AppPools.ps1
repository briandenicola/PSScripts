param (
    [Parameter(Mandatory = $true)]
    [string[]] $computers,
    [string] $name
)

$sb = { 
    param(
        [string] $name = [string]::empty
    )

    Set-Variable -Name ErrorActionPreference -Value "SilentlyContinue"

    . ( Join-Path $ENV:SCRIPTS_HOME "libraries\IIS_Functions.ps1")
    
    if ( $name -eq [string]::empty ) {
        $pools = Get-ChildItem IIS:\AppPools
    }
    else {
        $pools = Get-ChildItem IIS:\AppPools | where { $_.Name -eq $name } 
    }

    $app_pools = @()
    foreach ( $app_pool in $pools ) {
        $name = $app_pool.Name
        $state = $app_pool.State

        $obj = New-Object PSObject -Property @{
            Computer        = $ENV:COMPUTERNAME
            AppPoolName     = $name
            State           = $state
            User            = if ( [string]::IsNullOrEmpty($app_pool.processModel.UserName) ) { $app_pool.processModel.identityType } else { $app_pool.processModel.UserName }
            Version         = $app_pool.ManagedRuntimeVersion
            ProcessId       = 0
            Threads         = 0
            Handles         = 0
            MemoryInGB      = 0
            CreationDate    = $(Get-Date -Date "1/1/1970")
            Sites           = [string]::join( ";" , @(Get-Website | Where { $_.ApplicationPool -eq $app_pool.Name } | Select -Expand Name) )
            WebApplications = [string]::join( ";" , @(Get-WebApplication | 
                        Where { $_.ApplicationPool -eq $app_pool.Name } | 
                        Select @{N = "Path"; E = {$_.GetParentElement().Item("Name") + $_.Path }} | 
                        Select -ExpandProperty Path) 
            )
        }
        
        $worker_process = $app_pool.workerProcesses.Collection | Select -First 1
        if ( $worker_process.state -eq "Running" ) {
            $process = Get-Process -id $worker_process.processId
               
            $obj.ProcessId = $process.Id
            $obj.Threads = $process.Threads.Count
            $obj.Handles = $process.HandleCount
            $obj.MemoryInGB = [math]::round( $process.WorkingSet64 / 1gb, 2)
            $obj.CreationDate = $process.StartTime
        }  
        $app_pools += $obj
    }
    return $app_pools
}

Invoke-Command -ComputerName $computers -ScriptBlock $sb -ArgumentList $name