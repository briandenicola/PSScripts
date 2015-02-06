param (
	[string] $filter = ".*",
	[string] $csv 
)

Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
. ..\Libraries\Standard_Functions.ps1

$solutions = @()
Get-SPFarm | Select -Expand Solutions | Where { $_.Name -match $filter  } | ForEach-Object { 
	Write-Host "Working on" $_.Name
	$_.SolutionFile.SaveAs( "C:\Windows\Temp\" + $_.Name )
	$solutions += (New-Object PSObject -Property @{
		Name = $_.Name
		Hash = (get-hash1 ( "C:\Windows\Temp\" + $_.Name ))
	})
	
	Remove-Item ( "C:\Windows\Temp\" + $_.Name ) -Force
}

if( [string]::IsNullOrEmpty($csv) )
{
	$solutions
}
else
{
	$solutions | Export-Csv -Encoding ascii $csv
}