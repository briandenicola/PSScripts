param (
    [string[]] $computers
)

Invoke-Command -ComputerName $computers -ScriptBlock { 
    Get-WmiObject -Class Win32_Volume | 
        Where { $_.DriveType -eq 3 -and $_.Name -notmatch 'Volume' } | 
        Select @{Name="Computer";Expression={$ENV:ComputerName}}, Name, @{Name="Capacity";Expression={[Math]::Round(($_.Capacity/1mb), 4)}}, @{Name="FreeSpace";Expression={ [Math]::Round(($_.FreeSpace/1mb), 4) }}
} | Select Computer, Name, Capacity, FreeSpace 