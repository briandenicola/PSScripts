param (
	[Parameter(Mandatory=$true)]
	[ValidateSet("standalone","services","internal","external")]
	[string] 
	$farmType,

	[Parameter(Mandatory=$true)]
	[ValidateSet("development","qa","production","uat", "dr")]
	[string] 
	$environment,
	
	[string] $config = ".\config\spfarm-config.xml"
)
Add-PSSnapin Microsoft.SharePoint.PowerShell –erroraction SilentlyContinue

function Config-FarmAdministrators() 
{
	
	$web =  Get-SPWeb ("http://" + $env:COMPUTERNAME + ":10000")

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
	$cfg.SharePoint.managedaccounts.account | % { 
		$cred = Get-Credential $_.username
		New-SPManagedAccount $cred -verbose
	}
}

function Config-Logging() 
{
	$sharepoint_servers | % { 
		$path = $cfg.SharePoint.Logging.Path.Replace( "d:\", "\\" + $_ + "\d$\" )
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

function Config-Usage() 
{
	$sharepoint_servers | % { 
		$path = $cfg.SharePoint.Usage.Path.Replace( "d:\", "\\" + $_ + "\d$\" )
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
	$sharePoint_service_apppool = New-SPServiceApplicationPool -name "AppPool - SharePoint Web Service Application" -account $cfg.SharePoint.Secure.AppPoolAccount
	$secure_store = New-SPSecureStoreServiceApplication -Name "Secure Store Service" -ApplicationPool $sharePoint_service_apppool -DatabaseName "Secure_Store_Service_DB" -AuditingEnabled:$true -AuditLogMaxSize 30 -Sharing:$false -PartitionMode:$true 
	$proxy = New-SPSecureStoreServiceApplicationProxy -Name "Secure Store Service Proxy" -ServiceApplication $secure_store -DefaultProxyGroup 
	Update-SPSecureStoreMasterKey -ServiceApplicationProxy $proxy -Passphrase $cfg.SharePoint.Secure.Passphrase
}

function Config-InitialPublishing([String[]] $servers)
{
	if( $farmType -eq "standalone" )
	{
		return
	}
	
	if ( -not ( Test-Path "D:\Certs" ) )
	{
		mkdir D:\Certs
	}
	
	if( $farmType -eq "services" )
	{
		$rootCert = (Get-SPCertificateAuthority).RootCertificate
		$rootCert.Export("Cert") | Set-Content "D:\Certs\ServicesFarmRoot.cer" -Encoding byte

	}
	else
	{
		$rootCert = (Get-SPCertificateAuthority).RootCertificate
		$rootCert.Export("Cert") | Set-Content D:\Certs\$farmType-Root.cer -Encoding byte
		
		$stsCert = (Get-SPSecurityTokenServiceConfig).LocalLoginProvider.SigningCertificate
		$stsCert.Export("Cert") | Set-Content D:\Certs\$farmType-STS.cer -Encoding byte
		$id = (Get-SPFarm).id 
		$id.Guid | out-file -encoding ascii D:\Certs\$farmType-Id.txt
	
		#$alias = Read-Host "Please enter the database server alias for the $environment Services SharePoint farm - " 
		#$instance = Read-Host "Please enter the database server instance for the $environment Services SharePoint farm - " 
		#$port = Read-Host "Please enter the database server instance port for the $environment Services SharePoint farm - " 
		
		 $cfg.SharePoint.Databases.Database | % { 
			$alias = $_.name
			$port = $_.port
			$instance = $_.instance
			Write-Host "Going to create a SQL Alias - $alias - that points to $instance on port $port"
			$servers | % { 	D:\Scripts\Database\create_sql_alias.bat $alias $instance $port $_ }
		}
	}
}

function Deploy-PDF( [String[]] $servers )
{
	if( $farmType -eq "services" ) {
		return
	}
	
	mkdir D:\Deploy\BlueBeam
	copy \\ent-nas-fs01.us.gt.com\app-ops\SharePoint-2010\CodeUpdates\GT.US.ECM.BlueBeam.wsp  D:\Deploy\BlueBeam
	cd d:\Scripts\DeploySharePointSolutions
	d:\scripts\DeploySharePointSolutions\deploy_sharepoint_solutions.ps1 -deploy d:\Deploy\BlueBeam

	$doc_xml = [xml] ( gc "$ENV:COMMONPROGRAMFILES\Microsoft Shared\web server extensions\14\TEMPLATE\XML\DOCICON.XML" )

	$e = $doc_xml.CreateElement("Mapping")
	$e.SetAttribute("key", "pdf")
	$e.SetAttribute("value", "icpdf.gif")
	$e.SetAttribute("EditText", "Bluebeam PDF Revu" )
	$e.SetAttribute("OpenControl", "Revu.Launcher" )
	
	$doc_xml.DocIcons.ByExtension.AppendChild($e)
	$doc_xml.Save( "D:\Deploy\DOCICON.XML" )
	
	$pdf_icon = "D:\Deploy\icpdf.gif"
	$pdf_url = "http://www.bluebeam.com/web07/us/support/articles/images/icpdf.gif"
	
	$wc = New-Object System.Net.WebClient
	$wc.DownloadFile( $pdf_url, $pdf_icon )

	$servers | % {
		copy $pdf_icon "\\$_\c$\Program Files\Common Files\Microsoft Shared\Web Server Extensions\14\TEMPLATE\IMAGES\." -Verbose
		move "\\$_\c$\Program Files\Common Files\Microsoft Shared\Web Server Extensions\14\TEMPLATE\XML\DOCICON.XML" "\\$_\c$\Program Files\Common Files\Microsoft Shared\Web Server Extensions\14\TEMPLATE\XML\DOCICON.XML.org" -Verbose
		copy "D:\Deploy\DOCICON.XML" "\\$_\c$\Program Files\Common Files\Microsoft Shared\Web Server Extensions\14\TEMPLATE\XML\DOCICON.XML"
	}
}

$FixTaxonomyBug = {
	$TaxonomyPickerControl = "$env:CommonProgramFiles\Microsoft Shared\Web Server Extensions\14\TEMPLATE\CONTROLTEMPLATES\TaxonomyPicker.ascx" 
	Copy-Item $TaxonomyPickerControl $TaxonomyPickerControl".org" -Verbose 
	$NewTaxonomyPickerControl = (Get-Content $TaxonomyPickerControl) -replace '&#44;', "," 
	Set-Content -Path $TaxonomyPickerControl -Value $NewTaxonomyPickerControl -Verbose 
}

$sb = {
	Start-Service sptimerv4 
	copy \\ent-nas-fs01.us.gt.com\app-ops\SharePoint-2010\SharePoint2010AdministrationToolkit.exe D:\Deploy -Verbose
	D:\Deploy\SharePoint2010AdministrationToolkit.exe /quiet /norestart 
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

	$sharepoint_servers = @()
	Enable-WSManCredSSP -role client -delegate * -Force
	Get-SPServer | where { $_.Role -ne "Invalid" } | % { $sharepoint_servers += $_.Address } 
	
	$cred = Get-Credential -Credential ($ENV:USERDOMAIN + "\" + $ENV:USERNAME)
	
	Write-Host "--------------------------------------------"
	Write-Host "Deploy Admin Tools"
	Invoke-Command -ComputerName $sharepoint_servers -ScriptBlock $sb -Authentication Credssp -Credential $cred
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
	Config-Logging
	Write-Host "--------------------------------------------"
	
	Write-Host "--------------------------------------------"
	Write-Host "Configure Usage"
	Config-Usage
	Write-Host "--------------------------------------------"
	
	Write-Host "--------------------------------------------"
	Write-Host "Configure Initial Cert Exchange"
	Config-InitialPublishing -servers $sharepoint_servers
	Write-Host "--------------------------------------------"

	Write-Host "--------------------------------------------"
	Write-Host "Configure Blue Beam"
	Deploy-PDF -servers $sharepoint_servers
	Write-Host "--------------------------------------------"
	
	Stop-Transcript
}
$cfg = [xml] (gc $config)
main
