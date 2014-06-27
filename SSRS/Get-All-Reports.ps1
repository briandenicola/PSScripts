[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [Parameter(Mandatory=$true)]
    [string] $report_server_url,

     [ValidateScript({Test-Path $_ -PathType 'Container'})] 
    [string] $report_storage_location = "D:\Temp"
)

$report_server_url = $report_server_url -replace "http?://", [string]::empty 

$report_server_uri = "http://{0}/ReportServer/ReportService2005.asmx" -f $report_server_url
$Proxy = New-WebServiceProxy -Uri $report_server_uri -Namespace SSRS.ReportingService2005 -UseDefaultCredential
 
$now = Get-Date -format "yyyyMMddhhmmss"
$storage  = (Join-Path $report_storage_location ("{0}-{1}" -f $report_server_url,$now ))
New-Item -Path $storage -ItemType Directory | Out-Null

$reports = $Proxy.ListChildren("/", $true) | Where-Object {$_.type -eq "Report"} | Select Type, Path, ID, Name 
foreach($report in $reports)
{
    $sub_folder = Split-Path $report.Path
    $report_name = Split-Path $report.Path -Leaf

    $sub_folder_path = Join-Path $storage  $sub_folder
    if(!(Test-Path $sub_folder_path)) {
        New-Item -Path $sub_folder_path -ItemType Directory | Out-Null
    }
 
    Write-Verbose "Downloading $($report.Name) to $sub_folder_path"
    $rdl = New-Object System.Xml.XmlDocument
    $definition = [byte[]] $Proxy.GetReportDefinition($report.Path)
 
    [System.IO.MemoryStream] $memStream = New-Object System.IO.MemoryStream(@(,$definition))
    $rdl.Load($memStream)
 
    $report_local_path = Join-Path $sub_folder_path ("{0}.rdl" -f $report.Name)
    $rdl.Save( $report_local_path)
}