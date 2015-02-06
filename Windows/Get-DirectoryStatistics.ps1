param (
	[string] $directory
)

if ( -not ( Test-Path $directory ) ) {
	Write-Host $directory " does not exist"
	return
}

$DirectoryStatistics = @()

dir -Recurse $directory | where { $_.GetType().Name -eq "DirectoryInfo" }  | % {
	
	$LargeFiles = $nul
	$FullName = $_.FullName
	Write-Progress -Activity "Working on Directory" -Status "Working on $FullName"
	
	$Files = $_.GetFiles()
	
	$Count = $Files.Count
	$Measure = $Files | Measure-Object -Property Length -Maximum -Minimum -Sum
	
	$Large = $Files | Where { $_.Length -gt 52428800 }
	$LargeFileCount = $Large.Count
	$LargeMeasure = $Large | Measure-Object -Property Length -Maximum -Minimum -Sum -Average
	
	$stats = New-Object System.Object 
	$stats | add-member -type NoteProperty -name Directory -Value $FullName
	$stats | add-member -type NoteProperty -name FileCount -Value $Count
	$stats | add-member -type NoteProperty -name MaxFileSize -Value ($Measure.Maximum/1mb)
	$stats | add-member -type NoteProperty -name TotalSize -Value ($Measure.Sum/1mb)
	$stats | add-member -type NoteProperty -name LargeFileCount -Value $LargeFileCount
	$stats | add-member -type NoteProperty -name LargeFileAverageSize -Value ($LargeMeasure.Average/1mb)
	$stats | add-member -type NoteProperty -name LargeFIleTotalSize -Value ($LargeMeasure.Sum/1mb)
	
	
	$DirectoryStatistics += $stats
}

$DirectoryStatistics