#Some code and structured inspired from - http://autospinstaller.codeplex.com/
[CmdletBinding(SupportsShouldProcess=$true)]
param(	
	[string]
	$config = ".\config\master_setup.xml"
)

Add-PsSnapin Microsoft.SharePoint.PowerShell -EA SilentlyContinue

$sb = {
	$url = "http://download.adobe.com/pub/adobe/acrobat/win/9.x/PDFiFilter64installer.zip"
	$zip_file = Join-Path $ENV:TEMP "PDFiFilter64installer.zip"
	$msi_file = Join-Path $ENV:TEMP "PDFFilter64installer.msi"	
	
	Write-Host "[$ENV:ComputerName][$($(Get-Date).ToString())] - Downloading $url . . ."
	$wc = New-Object System.Net.WebClient
	$wc.DownloadFile($url, $zip_file)

	Write-Host "[$ENV:ComputerName][$($(Get-Date).ToString())] - Unzipping $zip_file  . . ."
	$shell = New-Object -ComObject Shell.Application
	$zip_namespace = $shell.Namespace($zip_file)
	$dest_namespace = $shell.Namespace($ENV:Temp)
	$dest_namespace.Copyhere($zip_namespace.items())

	Write-Host "[$ENV:ComputerName][$($(Get-Date).ToString())] - Starting silent install of $msi_file . . ."
	Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $msi_file /passive /norestart" -NoNewWindow -Wait
	
	Write-Host "[$ENV:Computer][$($(Get-Date).ToString())] - Setting Registry Values . . ."
	$reg_ifilter_extension  = New-Item -Path Registry::"HKLM\SOFTWARE\Microsoft\Office Server\14.0\Search\Setup\Filters\.pdf"
	$reg_ifilter_extension  | New-ItemProperty -Name Extension -PropertyType String -Value "pdf" | Out-Null
	$reg_ifilter_extension  | New-ItemProperty -Name FileTypeBucket -PropertyType DWord -Value 1 | Out-Null
	$reg_ifilter_extension  | New-ItemProperty -Name MimeTypes -PropertyType String -Value "application/pdf" | Out-Null
	
	$reg_ifilter_extension = New-Item -Path Registry::"HKLM\SOFTWARE\Microsoft\Office Server\14.0\Search\Setup\ContentIndexCommon\Filters\Extension\.pdf"
	$reg_ifilter_extension  | New-ItemProperty -Name "(default)" -PropertyType String -Value "{E8978DA6-047F-4E3D-9C78-CDBE46041603}" | Out-Null
	Get-ItemProperty Registry::"HKLM\SOFTWARE\Microsoft\Office Server\14.0\Search\Setup\ContentIndexCommon\Filters\Extension\.pdf"
	
	if( (Get-Service OSearch14).Status -eq "Running" )
	{
		Write-Host "[$ENV:ComputerName][$($(Get-Date).ToString())] - Restarting SharePoint Search Service . . ."
		Restart-Service OSearch14 -Verbose
	}

}

function main()
{
	$computers = @()
	$computers += $cfg.SharePoint.Farms.Farm | where { $_.Name -eq "Services"} | Select -Expand Server | ? { $_.Role -eq "Indexer" } | Select -Expand Name
	
	if( $computers.Length -gt 1 )
	{
		Write-Host "Found the following indexers in the services farm" + $computers
	}
	else
	{
		Write-Host "Could not find any indexers in configuration. Must exit"
		return -1
	}
	
	$creds = Get-Credential ($ENV:USERDOMAIN + "\" + $ENV:USERNAME)
	
	foreach( $search_app in $(Get-SPEnterpriseSearchServiceApplication) )
	{
		Write-Host "[$($(Get-Date).ToString())] - Going to set the PDF file extension for $($search_app.DisplayName) . . ."
		try
		{
			Get-SPEnterpriseSearchCrawlExtension -SearchApplication $search_app -Identity "pdf" -ErrorAction Stop | Out-Null
			Write-Host "[$($(Get-Date).ToString())] The PDF file extension for $($search_app.DisplayName) has already been set . . ."
		}
		catch
		{
			New-SPEnterpriseSearchCrawlExtension -SearchApplication $search_app -Name "pdf" 
			Write-Host "[$($(Get-Date).ToString())] - PDF file extension for $($search_app.DisplayName) is now set . . ."
		}
	}

	Invoke-Command -Credential $creds -Authentication Credssp -ScriptBlock $sb -ComputerName $computers
}
$cfg = [xml] (gc $config)
main