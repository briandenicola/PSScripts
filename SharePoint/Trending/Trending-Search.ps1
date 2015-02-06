[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [switch] $upload
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Variables.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")

$search_service_app =  Get-SPServiceApplication | where { $_.TypeName -eq "Search Service Application" } 

$content_source = $search_service_app | Get-SPEnterpriseSearchCrawlContentSource
$dbs = Get-SPDatabase | Where { $_.Name -imatch "Search" } | Select Name, @{Name="Size";Expression={$_.DiskSizeRequired/1MB}}

$history = new-Object Microsoft.Office.Server.Search.Administration.CrawlHistory $search_service_app
$average = $history.GetNDayAvgStats( $content_source, 1, 7 )

$search_info = New-Object PSObject -Property @{
    TimeStamp = $(Get-Date)
    CurrentCrawlStatus = $content_source.CrawlState
    CurrentCrawlSuccessCount = $content_source.SuccessCount
    CurrentCrawlErrorCount = $content_source.ErrorCount
    CurrentCrawlStartTime = $content_source.CrawlStarted
    CurrentCrawlEndTime = $content_source.CrawlCompleted
    CrawlDBSize = $dbs | Where { $_.Name -imatch "Crawl" } | Select -Expand Size
    PrimaryPropertyDBSize = $dbs | Where { $_.Name -imatch "^SearchPropertyDB$" } | Select -Expand Size
    SecondaryPropertyDBSize = $dbs | Where { $_.Name -imatch "SearchPropertyDB_Secondary" } | Select -Expand Size
    SevenDayAverageCrawlTime = $average.DurationAvg
    SevenDayAverageCrawlCount = $average.TotalCrawls
}

if( $upload ) {
    WriteTo-SPListViaWebService -url $global:SharePoint_url -list $global:SharePoint_search_list -Item (Convert-ObjectToHash $search_info) -TitleField TimeStamp
}
else {
    return $search_info
}    