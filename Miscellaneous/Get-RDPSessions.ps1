param(
    [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
    [string[]] $computers
)
    
$users = @()
$filter = "name='explorer.exe'"

foreach ( $computer in $computers ) {
    foreach ( $process in (Get-WmiObject -ComputerName $computer -Class Win32_Process -Filter $filter ) ) {
        $users += (New-Object PSObject -Property @{
            Computer = $computer
            User     = $process.getOwner() | Select-Object -Expand User
        })                     
    }
}

return $users