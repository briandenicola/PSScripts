param (
	[string[]] $computers,
	[string] $folder
)

$sb = { 
	param( [string] $root )
		
	Get-ChildItem $root | 
        Where { $_.PsIsContainer -eq $false } | 
        Measure-Object -Sum -Property Length | 
        Select-Object @{N="Computer";E={$ENV:ComputerName}},@{N="Folder";E={$root}},@{N="Size (mb)";E={[math]::round($_.Sum/1mb,2)}}

    Get-ChildItem $root |
         Where { $_.PsIsContainer -eq $true } | 
         ForEach { 
	        $folder = $_.FullName
            Get-ChildItem $folder -Recurse | 
                Measure-Object -Sum -Property Length | 
                Select-Object @{N="Computer";E={$ENV:ComputerName}},@{N="Folder";E={$folder}},@{N="Size (mb)";E={[math]::round($_.Sum/1mb,2)}} 
        }
	
}

function main
{
    $ses = New-PSSession -Computer $computers
    $job = Invoke-Command -Session $ses -ScriptBlock $sb -Args $folder -AsJob

    Get-Job $job.Id | Wait-Job | Out-Null 
    Receive-Job $job | Select Computer, Folder,'Size (mb)' | Format-Table -GroupBy Computer

    Get-PSSession | Remove-PSSession
}
main 