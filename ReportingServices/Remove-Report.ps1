<#
.SYNOPSIS
	Uninstalls an RDL file from SQL Reporting Server using Web Service

.DESCRIPTION
	Uninstalls an RDL file from SQL Reporting Server using Web Service

.NOTES
	File Name: Uninstall-SSRSRDL.ps1
	Author: Randy Aldrich Paulo
	Prerequisite: SSRS 2008, Powershell 2.0

.EXAMPLE
	Uninstall-SSRSRDL -webServiceUrl "http://[ServerName]/ReportServer/ReportService2005.asmx?WSDL" -path "MyReport"

.EXAMPLE
	Uninstall-SSRSRDL -webServiceUrl "http://[ServerName]/ReportServer/ReportService2005.asmx?WSDL" -path "Reports/Report1"

#>
function Uninstall-SSRSRDL
(
	[Parameter(Position=0,Mandatory=$true)]
	[Alias("url")]
	[string]$webServiceUrl,

	[Parameter(Position=1,Mandatory=$true)]
	[Alias("path")]
	[string]$reportPath
)

{
	#Create Proxy
	Write-Host "[Uninstall-SSRSRDL()] Creating Proxy, connecting to : $webServiceUrl"
	$ssrsProxy = New-WebServiceProxy -Uri $webServiceUrl -UseDefaultCredential
	
	#Set Report Folder
	if(!$reportPath.StartsWith("/")) { $reportPath = "/" + $reportPath }
	
	try
	{

		Write-Host "[Uninstall-SSRSRDL()] Deleting: $reportPath"			
		#Call Proxy to upload report
		$ssrsProxy.DeleteItem($reportPath)
		Write-Host "[Uninstall-SSRSRDL()] Delete Success." 
	}
	catch [System.Web.Services.Protocols.SoapException]
	{
		$msg = "[Uninstall-SSRSRDL()] Error while deleting report : '{0}', Message: '{1}'" -f $reportPath, $_.Exception.Detail.InnerText
		Write-Error $msg
	}
	
}


