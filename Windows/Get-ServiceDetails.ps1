function  Get-MemoryInMb {
    param (
        [int] $Size
    )
    return [math]::Round( $Size / 1mb, 2 )
}

$processes = Get-WmiObject Win32_process | 
    Group-Object -Property Processid -AsHashTable -AsString

$query = "select Name,DisplayName,ProcessId,State from Win32_Service where State = 'Running'"

$all_services = Get-WmiObject -Query $query

$services = foreach ( $service in $all_services ) {
    New-Object PSObject -Property @{
        Name        = $service.Name
        DisplayName = $service.DisplayName
        User        = $processes[$service.ProcessId.ToString()].GetOwner().user
        CommandLine = $processes[$service.ProcessId.ToString()].CommandLine
        PID         = $processes[$service.ProcessId.ToString()].ProcessId
        Memory      = Get-MemoryInMb -Size $processes[$service.ProcessId.ToString()].WorkingSetSize
    }   
}

return $services