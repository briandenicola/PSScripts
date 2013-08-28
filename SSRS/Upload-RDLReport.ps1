<#
.SYNOPSIS
	Installs an RDL file to SQL Reporting Server using Web Service

.DESCRIPTION
	Installs an RDL file to SQL Reporting Server using Web Service

.NOTES
	File Name: Install-SSRSRDL.ps1
	Author: Randy Aldrich Paulo
	Prerequisite: SSRS 2008, Powershell 2.0
	
.PARAMETER reportName
	Name of report wherein the rdl file will be save as in Report Server.
	If this is not specified it will get the name from the file (rdl) exluding the file extension.

.PARAMETER force
	If force is specified it will create the report folder if not existing
	and overwrites the report if existing.

.EXAMPLE
	Install-SSRSRDL -webServiceUrl "http://[ServerName]/ReportServer/ReportService2005.asmx?WSDL" -rdlFile "C:\Report.rdl" -force

.EXAMPLE
	Install-SSRSRDL "http://[ServerName]/ReportServer/ReportService2005.asmx?WSDL" "C:\Report.rdl" -force

.EXAMPLE
	Install-SSRSRDL "http://[ServerName]/ReportServer/ReportService2005.asmx?WSDL" "C:\Report.rdl" -force -reportName "MyReport"

.EXAMPLE
	Install-SSRSRDL "http://[ServerName]/ReportServer/ReportService2005.asmx?WSDL" "C:\Report.rdl" -force -reportFolder "Reports" -reportName "MyReport"

#>
function Install-SSRSRDL
(
	[Parameter(Position=0,Mandatory=$true)]
	[Alias("url")]
	[string]$webServiceUrl,

	[ValidateScript({Test-Path $_})]
	[Parameter(Position=1,Mandatory=$true)]
	[Alias("rdl")]
	[string]$rdlFile,
	
	[Parameter(Position=2)]
	[Alias("folder")]
	[string]$reportFolder="",

	[Parameter(Position=3)]
	[Alias("name")]
	[string]$reportName="",
	
	[switch]$force
)
{
	$ErrorActionPreference="Stop"
	
	#Create Proxy
	Write-Host "[Install-SSRSRDL()] Creating Proxy, connecting to : $webServiceUrl"
	$ssrsProxy = New-WebServiceProxy -Uri $webServiceUrl -UseDefaultCredential
	$reportPath = "/"
	
	if($force)
	{
		#Check if folder is existing, create if not found
		try
		{
			$ssrsProxy.CreateFolder($reportFolder, $reportPath, $null)
			Write-Host "[Install-SSRSRDL()] Created new folder: $reportFolder"
		}
		catch [System.Web.Services.Protocols.SoapException]
		{
			if ($_.Exception.Detail.InnerText -match "[^rsItemAlreadyExists400]")
			{
				Write-Host "[Install-SSRSRDL()] Folder: $reportFolder already exists."
			}
			else
			{
				$msg = "[Install-SSRSRDL()] Error creating folder: $reportFolder. Msg: '{0}'" -f $_.Exception.Detail.InnerText
				Write-Error $msg
			}
		}
		
	}
	
	#Set reportname if blank, default will be the filename without extension
	if($reportName -eq "") { $reportName = [System.IO.Path]::GetFileNameWithoutExtension($rdlFile);}
	Write-Host "[Install-SSRSRDL()] Report name set to: $reportName"
	
	try
	{
		#Get Report content in bytes
		Write-Host "[Install-SSRSRDL()] Getting file content (byte) of : $rdlFile"			
		$byteArray = gc $rdlFile -encoding byte
		$msg = "[Install-SSRSRDL()] Total length: {0}" -f $byteArray.Length			
		Write-Host $msg

		$reportFolder = $reportPath + $reportFolder
		Write-Host "[Install-SSRSRDL()] Uploading to: $reportFolder"			
		
		#Call Proxy to upload report
		$warnings = $ssrsProxy.CreateReport($reportName,$reportFolder,$force,$byteArray,$null)
		if($warnings.Length -eq $null) { Write-Host "[Install-SSRSRDL()] Upload Success." }
		else { $warnings | % { Write-Warning "[Install-SSRSRDL()] Warning: $_" }}
	}
	catch [System.IO.IOException]
	{
		$msg = "[Install-SSRSRDL()] Error while reading rdl file : '{0}', Message: '{1}'" -f $rdlFile, $_.Exception.Message
		Write-Error msg
	}
	catch [System.Web.Services.Protocols.SoapException]
	{
		$msg = "[Install-SSRSRDL()] Error while uploading rdl file : '{0}', Message: '{1}'" -f $rdlFile, $_.Exception.Detail.InnerText
		Write-Error $msg
	}
	
}
