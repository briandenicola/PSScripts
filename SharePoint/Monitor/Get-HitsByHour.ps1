[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [Parameter(Mandatory=$true)] [string] $url,
    [Parameter(Mandatory=$true)] [string] $start_date,
    [Parameter(Mandatory=$true)] [string] $end_date,
    [Parameter(Mandatory=$true)] [string] $result
)

$wc = New-Object System.Net.Webclient
$wc.UseDefaultCredentials = $true

$site = "http://example.com/sites/AppOps/IISLogs/Hits-By-Hour/Hits-By-Hour_{0}-u_ex{1}.csv"

Set-Content -Value "Hour,Hits,s-ip" -Path $result -Encoding Ascii

$current_date = Get-Date $start_date
$stop_date = Get-Date $end_date
while( $current_date -lt $stop_date ) {

    try {
        $formatted_date = (Get-Date $current_date).ToString("yyMMdd")
        $complete_url = $site -f $url, $formatted_date
    
        $tmp_file =  Join-Path $env:TEMP "$formatted_date.csv"

        Write-Verbose "[ $(Get-Date) ] - Downloading $complete_url to $tmp_file"
        $wc.DownloadFile( $complete_url, $tmp_file)

        Write-Verbose "[ $(Get-Date) ] - Merging $tmp_file with $result file"
        Get-Content $tmp_file | Where { $_ -inotmatch "Hits" } | Out-File -Encoding ascii -Append -FilePath $result

        Write-Verbose "[ $(Get-Date) ] - Removing $tmp_file"
        Remove-Item $tmp_file -Force
    }
    catch {
        Write-Error "Error occurred while downloading $complete_url"
    }

    $current_date = $current_date.AddDays(1)
}
Invoke-Expression $result