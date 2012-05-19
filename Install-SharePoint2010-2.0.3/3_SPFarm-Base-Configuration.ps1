param (
	[Parameter(Mandatory=$true)]
	[ValidateSet("development","qa","production","uat", "dr")]
	[string] $environment,
	[string] $config = ".\config\master_setup.xml"
)

Add-PSSnapin Microsoft.SharePoint.PowerShell –EA SilentlyContinue

$global:farm_type = $null
$global:server_type = $null

function Get-FarmType
{
	#Determine Farm and Server Type
	#foreach( $farm in @("services", "external", "internal") )
	#{
	#	$cfg.SharePoint.Farms.$farm.Server | ? { $_.Name -eq $ENV:COMPUTERNAME  } | % { $global:farm_type = $farm; $global:server_type = $_.Role }
	#}
	$xpath = "/SharePoint/Farms/farm/server[@name='" + $ENV:COMPUTERNAME + "']"
	$global:farm_type = (Select-Xml -xpath $xpath  $cfg | Select @{Name="Farm";Expression={$_.Node.ParentNode.name}}).Farm
	
	if( $global:farm_type -ne $null )
	{
		Write-Host "Found $ENV:COMPUTERNAME in $global:farm_type Farm Configuration"
	}
	else
	{
		throw  "Could not find $ENV:COMPUTERNAME in configuration. Must exit"
	}
}

function Config-FarmAdministrators() 
{
	
	$web = Get-SPWeb ("http://" + $env:COMPUTERNAME + ":10000")

	$farm_admins = $web.SiteGroups["Farm Administrators"]
	
	$cfg.SharePoint.FarmAdministrators.add | % { 
		Write-Host "Adding "$_.group" to the Farm Administrators group . . ."
		$user = New-SPUser -UserAlias $_.group.ToLower() -Web $web
		$farm_admins.AddUser($user, [String]::Empty,[String]::Empty,[String]::Empty)
		
		Add-SPShellAdmin $_.group
	}
	
	$cfg.SharePoint.FarmAdministrators.remove | % { 
		$group = $_.group

		Write-Host "Removing "$_.group" to the Farm Administrators group . . ."
		$user = Get-SPUser -Web $web -Group "Farm Administrators" | Where { $_.Name.ToLower() -eq $group }

		$farm_admins.RemoveUser($user)
	}
	$web.Dispose()
	
	Get-SPShellAdmin
	
}

function Config-ManagedAccounts() 
{
	$cfg.SharePoint.managedaccounts.account | where { $_.farm -match $global:farm_type } | % { 
		$cred = Get-Credential $_.username
		New-SPManagedAccount $cred -verbose
	}
}

function Config-Logging([String[]] $servers) 
{
	foreach( $server in $servers )
	{
		$path = $cfg.SharePoint.Logging.Path.Replace( "d:\", ("\\" + $server + "\d$\") )
		if( -not ( Test-Path $path ) )
		{
			mkdir $path -verbose
		}
	}
	
	$LogConfig = @{
		LogMaxDiskSpaceUsageEnabled = $true
		ErrorReportingEnabled = $false
		EventLogFloodProtectionEnabled = $true
		LogCutInterval = $cfg.SharePoint.Logging.CutInterval
		LogDiskSpaceUsageGB = $cfg.SharePoint.Logging.MaxDiskSpace
		LogLocation = $cfg.SharePoint.Logging.Path
		DaysToKeepLogs = $cfg.SharePoint.Logging.DaysToKeep
	}
	Set-SPDiagnosticConfig @LogConfig -verbose
	
}

function Config-Usage([String[]] $servers) 
{
	foreach( $server in $servers )
	{
		$path = $cfg.SharePoint.Usage.Path.Replace( "d:\", "\\" + $server + "\d$\" )
		if( -not ( Test-Path $path ) )
		{
			mkdir $path -verbose
		}
	}
	
	$UsageConfig = @{
		UsageLogLocation = $cfg.SharePoint.Usage.Path
		UsageLogMaxSpaceGB = $cfg.SharePoint.Usage.MaxDiskSpace
		LoggingEnabled = $true
	}

	Set-SPUsageService @UsageConfig -Verbose

	$db_server = (Get-SPDatabase | where { $_.TypeName -eq "Configuration Database"} | Select @{Name="SystemName";Expression={$_.Server.Address}}).SystemName
	New-SPUsageApplication -Name "WSS_UsageApplication" -DatabaseServer $db_server -DatabaseName $cfg.SharePoint.Usage.Database
	$usage = Get-SPServiceApplicationProxy | Where { $_.TypeName -eq "Usage and Health Data Collection Proxy"}
	$usage.Provision()

	Write-Host "************************************************************************"  -foreground green
	Write-Host "Due to a limitation in the PowerShell API, in order complete the Health Usage Configuration" -foreground green
	Write-Host "Please go to - http://"$env:COMPUTERNAME":10000/_admin/LogUsage.aspx and "  -foreground green
	Write-Host "Select the check box next to `'Enable health data collection`'" -foreground green
	Write-Host "************************************************************************"  -foreground green
}

function Config-OutgoingEmail()
{
	$central_admin = Get-SPwebApplication -includecentraladministration | where {$_.IsAdministrationWebApplication}
 	$central_admin.UpdateMailSettings($cfg.SharePoint.Email.Outgoing.Server, $cfg.SharePoint.Email.Outgoing.Address, $cfg.SharePoint.Email.Outgoing.Address, 65001)
}

function Config-StateService()
{
	$serviceApp = New-SPStateServiceApplication -Name "State Service Application" 
	New-SPStateServiceDatabase -Name "SharePoint State Service" -ServiceApplication $serviceApp
	New-SPStateServiceApplicationProxy -Name "State Service Application Proxy" -ServiceApplication $serviceApp -DefaultProxyGroup
	Enable-SPSessionStateService -DefaultProvision
}

function Config-SecureStore()
{
	Get-SPServiceInstance | where { $_.TypeName -eq "Secure Store Service" -and $_.Server.Address.Contains("SPA") } | Start-SPServiceInstance
	$sharePoint_service_apppool = New-SPServiceApplicationPool -name "AppPool - SharePoint Web Service Application" -account $cfg.SharePoint.Secure.AppPoolAccount.Name
	$secure_store = New-SPSecureStoreServiceApplication -Name "Secure Store Service" -ApplicationPool $sharePoint_service_apppool -DatabaseName "Secure_Store_Service_DB" -AuditingEnabled:$true -AuditLogMaxSize 30 -Sharing:$false -PartitionMode:$true 
	$proxy = New-SPSecureStoreServiceApplicationProxy -Name "Secure Store Service Proxy" -ServiceApplication $secure_store -DefaultProxyGroup 
	Update-SPSecureStoreMasterKey -ServiceApplicationProxy $proxy -Passphrase $cfg.SharePoint.Secure.Passphrase
}

function Config-InitialPublishing
{
	$certs_home = "D:\Certs"

	if( $global:farm_type -eq "standalone" )
	{
		return
	}
	
	if ( -not ( Test-Path $certs_home) )
	{
		mkdir $certs_home
	}
	
	if( $global:farm_type -eq "services" )
	{
		$rootCert = (Get-SPCertificateAuthority).RootCertificate
		$rootCert.Export("Cert") | Set-Content "$certs_home\ServicesFarmRoot.cer" -Encoding byte

	}
	else
	{
		$rootCert = (Get-SPCertificateAuthority).RootCertificate
		$rootCert.Export("Cert") | Set-Content "$certs_home\$global:farm_type-Root.cer" -Encoding byte
		
		$stsCert = (Get-SPSecurityTokenServiceConfig).LocalLoginProvider.SigningCertificate
		$stsCert.Export("Cert") | Set-Content "$certs_home\$global:farm_type-STS.cer" -Encoding byte
		$id = (Get-SPFarm).id 
		$id.Guid | out-file -encoding ascii "$certs_home\$global:farm_type-Id.txt"		
	}
}

function Deploy-PDF( [String[]] $servers )
{
	if( $global:farm_type -eq "services" ) {
		return
	}
	
	$deploy_home = "D:\Deploy\BlueBeam"
	$pdf_icon = "$deploy_home\icpdf.gif"
	$pdf_url = "http://www.bluebeam.com/web07/us/support/articles/images/icpdf.gif"
	
	mkdir $deploy_home
	copy "$global:source\SharePoint2010-Utils-Scripts\GT.US.ECM.BlueBeam.wsp" $deploy_home
	cd  ( Join-Path $ENV:SCRIPTS_HOME "DeploySharePointSolutions")
	.\deploy_sharepoint_solutions.ps1 -deploy $deploy_home

	$doc_xml = [xml] ( gc "$ENV:COMMONPROGRAMFILES\Microsoft Shared\web server extensions\14\TEMPLATE\XML\DOCICON.XML" )

	$e = $doc_xml.CreateElement("Mapping")
	$e.SetAttribute("Key", "pdf")
	$e.SetAttribute("Value", "icpdf.gif")
	$e.SetAttribute("EditText", "Bluebeam PDF Revu" )
	$e.SetAttribute("OpenControl", "Revu.Launcher" )
	
	$doc_xml.DocIcons.ByExtension.AppendChild($e)
	$doc_xml.Save( "$deploy_home\DOCICON.XML" )
		
	$wc = New-Object System.Net.WebClient
	$wc.DownloadFile( $pdf_url, $pdf_icon )

	foreach( $server in $servers )
	{
		copy $pdf_icon "\\$server\c$\Program Files\Common Files\Microsoft Shared\Web Server Extensions\14\TEMPLATE\IMAGES\." -Verbose
		move "\\$server\c$\Program Files\Common Files\Microsoft Shared\Web Server Extensions\14\TEMPLATE\XML\DOCICON.XML" "\\$server\c$\Program Files\Common Files\Microsoft Shared\Web Server Extensions\14\TEMPLATE\XML\DOCICON.XML.org" -Verbose
		copy "$deploy_home\DOCICON.XML" "\\$server\c$\Program Files\Common Files\Microsoft Shared\Web Server Extensions\14\TEMPLATE\XML\DOCICON.XML"
	}
}

$FixTaxonomyBug = {
	$TaxonomyPickerControl = "$env:CommonProgramFiles\Microsoft Shared\Web Server Extensions\14\TEMPLATE\CONTROLTEMPLATES\TaxonomyPicker.ascx" 
	Copy-Item $TaxonomyPickerControl $TaxonomyPickerControl".org" -Verbose 
	$NewTaxonomyPickerControl = (Get-Content $TaxonomyPickerControl) -replace '&#44;', "," 
	Set-Content -Path $TaxonomyPickerControl -Value $NewTaxonomyPickerControl -Verbose 
}

$sb = {
	param (
		[string] $source
	)

	$deploy_home = "D:\Deploy"

	copy "$source\SharePoint2010AdministrationToolkit.exe" $deploy_home -Verbose
	&"$deploy_home\SharePoint2010AdministrationToolkit.exe" /quiet /norestart 
	Sleep 5
	
	if( -not (Test-Path "C:\Program Files\Microsoft\SharePoint 2010 Administration Toolkit\SPDIAG.exe") )
	{
		Write-Host "SharePoint2010AdministrationToolkit install failed on " $ENV:COMPUTERNAME
	}
	else
	{
		Write-Host "SharePoint2010AdministrationToolkit install succeeded on " $ENV:COMPUTERNAME
	}
}

function main()
{
	$log = "D:\Logs\Farm-Config-" + $ENV:COMPUTERNAME + "-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".log"
	&{Trap{continue};Start-Transcript -Append -Path $log}

	Get-FarmType
	
	Enable-WSManCredSSP -role client -delegate * -Force
	
	$sharepoint_servers = @()
	$sharepoint_servers += Get-SPServer | where { $_.Role -ne "Invalid" } | Select -Expand Address 
	
	$global:source = $cfg.SharePoint.Setup.master_file_location
			
	$cred = Get-Credential -Credential ($ENV:USERDOMAIN + "\" + $ENV:USERNAME)
	
	Write-Host "--------------------------------------------"
	Write-Host "Start SPTimer Service"
	Invoke-Command -ComputerName $sharepoint_servers -ScriptBlock { Start-Service SPTimerV4 } -Authentication Credssp -Credential $cred
	Write-Host "--------------------------------------------"
	
	Write-Host "--------------------------------------------"
	Write-Host "Deploy Admin Tools"
	Invoke-Command -ComputerName $sharepoint_servers -ScriptBlock $sb -Authentication Credssp -Credential $cred -ArgumentList $global:source
	Write-Host "--------------------------------------------"
	
	Write-Host "--------------------------------------------"
	Write-Host "Configure Fix Taxonomy Bug"
	Invoke-Command -ComputerName $sharepoint_servers -ScriptBlock $FixTaxonomyBug -Authentication Credssp -Credential $cred
	Write-Host "--------------------------------------------"
	
	Write-Host "--------------------------------------------"
	Write-Host "Configure Farm Admins"
	Config-FarmAdministrators
	Write-Host "--------------------------------------------"
	
	Write-Host "--------------------------------------------"
	Write-Host "Configure Outgoing Email"
	Config-OutgoingEmail
	Write-Host "--------------------------------------------"
	
	Write-Host "--------------------------------------------"
	Write-Host "Configure Managed Accounts"
	Config-ManagedAccounts
	Write-Host "--------------------------------------------"
	
	Write-Host "--------------------------------------------"
	Write-Host "Configure State Service"
	Config-StateService
	Write-Host "--------------------------------------------"
	
	Write-Host "--------------------------------------------"
	Write-Host "Configure Secure Store"
	Config-SecureStore
	Write-Host "--------------------------------------------"
	
	Write-Host "--------------------------------------------"
	Write-Host "Configure Logging"
	Config-Logging -servers $sharepoint_servers
	Write-Host "--------------------------------------------"
	
	Write-Host "--------------------------------------------"
	Write-Host "Configure Usage"
	Config-Usage -servers $sharepoint_servers
	Write-Host "--------------------------------------------"
	
	Write-Host "--------------------------------------------"
	Write-Host "Configure Initial Cert Exchange"
	Config-InitialPublishing 
	Write-Host "--------------------------------------------"

	Write-Host "--------------------------------------------"
	Write-Host "Configure Blue Beam"
	Deploy-PDF -servers $sharepoint_servers
	Write-Host "--------------------------------------------"
	
	Stop-Transcript
}
$cfg = [xml] (gc $config)
main
