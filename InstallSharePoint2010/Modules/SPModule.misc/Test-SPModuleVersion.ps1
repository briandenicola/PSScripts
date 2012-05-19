function Test-SPModuleVersion
{
    if ($MyInvocation.HistoryId -gt -1)
    {
    $ModuleName = "SPModule.misc"
    $PathToVersion = "http://download.microsoft.com/download/A/8/F/A8FB4651-86D6-440E-9F41-8F638E1FDDDE/Version.txt"

    $currentversion = [float](Get-Module -ListAvailable |?{$_.Name -eq $ModuleName} | select version -first 1 | %{ "$($_.Version.Major).$($_.Version.Minor)" } )
    Write-Progress "Checking for Updates" -Status "Please wait..." -PercentComplete 10
	
    $clnt = new-object System.Net.WebClient
    $url = $PathToVersion
    $file = "$env:temp\SPModuleVersionTest.txt"
    try
    {
        $clnt.DownloadFile($url,$file)
        if(Test-Path $file)
        {
            $version = [float](Get-Content $file)
            if($currentversion -lt $version)
            {
                Write-Host -ForegroundColor Yellow -BackgroundColor Black "IMPORTANT: Running version $currentversion. A newer version of this Module is available ($version)"
            }
            elseif($currentversion -gt $version)
            {
                Write-Host -ForegroundColor Yellow -BackgroundColor Black "IMPORTANT: Running a pre-release version of this Module ($currentversion versus $version)"
            }
            else
            {
                Write-Host -ForegroundColor Green -BackgroundColor Black "Running latest version of this Module ($version)"
            }
        }
    }
    catch
    {
        Write-Host -ForegroundColor Red -BackgroundColor Black "IMPORTANT: Failed to complete the check for a newer Module version..."
        Write-Host -ForegroundColor Red -BackgroundColor Black "IMPORTANT: Verify you can browse to http://download.microsoft.com manually..."
    }
}
}

Test-SPModuleVersion