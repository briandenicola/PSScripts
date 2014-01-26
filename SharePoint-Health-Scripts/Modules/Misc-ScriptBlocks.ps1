Set-Variable -Name check_apppool_sb -Value ( [ScriptBlock]  { 
	Import-Module WebAdministration  -EA SilentlyContinue
	Get-ChildItem IIS:\AppPools |
        Where { $_.State -eq "Stopped" -and $_.name -ne "SharePoint Web Services Root" } | 
        Select @{Name="System";Expression={$Env:ComputerName}}, Name, State 
})

Set-Variable -Name check_url_sb -Value ( [ScriptBlock]  {
	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")

	$servers = Get-SPServer | where { $_.Address -match "SPW" } | Select -Expand Address
	$urls = Get-SPWebApplication | Select -Expand Url
	
	$urls_to_check = @()
	foreach( $url in $urls ) {
		$urls_to_check += (New-Object PSObject -Property @{
			url = $url
			servers = $servers
		})
	}
	
	return $urls_to_check
})

Set-Variable -Name check_uls_sb -Value ( [ScriptBlock]  {
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
	Get-SPLogEvent -MinimumLevel High -StartTime $(Get-Date).AddHours(-0.25) | 
        Select @{Name="Server";Expression={$ENV:ComputerName}},TimeStamp, Level, Message | fl
})

Set-Variable -Name check_solutions_sb -Value ( [ScriptBlock]  {
	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")

	$solutions = @()
	foreach( $solution in (Get-SPFarm | Select -Expand Solutions) )	{
        $solution_file = Join-Path $ENV:TEMP $solution.Name
		$solution.SolutionFile.SaveAs( $solution_file )
		$solutions += (New-Object PSObject -Property @{
			Server = $env:COMPUTERNAME
			Solution = $solution.Name
			Hash = (Get-Hash1 ( $ENV:TEMP + "\" + $solution.Name ))
		})
		Remove-Item ( $solution_file ) -Force
	}
	
	return $solutions
})

Set-Variable -Name check_failed_timer_jobs -Value ( [ScriptBlock] {
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
    $farm = Get-SPFarm
    $farm.TimerService.JobHistoryEntries | Where { $_.Status -eq "Failed" -and $_.EndTime -gt $(Get-Date).AddDays(-1) }
})

Set-Variable -Name check_db_size -Value ( [ScriptBlock] {
	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
	Get-SPDatabaseSize
})