Import-Module WebAdministration
Add-PSSnapin WebFarmSnapin -ErrorAction SilentlyContinue

$ENV:PATH += ';C:\Program Files\IIS\Microsoft Web Deploy V2'

function Get-IISAppPoolDetails
{
    param(
        [string] $app_pool
    )

    if( !(Test-Path (Join-Path "IIS:\AppPools" $app_pool) ) ) {
        throw "Could not find " + $app_pool
        return -1
    }

    $details =  Get-ItemProperty -Path (Join-Path "IIS:\AppPools" $app_pool) | Select startMode, processModel, recycling,  autoStart, managedPipelineMode, managedRuntimeVersion , queueLength                                

    return (New-Object PSObject -Property @{
        UserName = $details.processModel.UserName
        IdleTimeOut = $details.processModel.IdleTimeOut
        LoadProfile = $details.processModel.SetProfileEnvironment
        PipelineMode = $details.managedPipelineMode
        DotNetVersion = $details.managedRuntimeVersion
        QueueLength = $details.queueLength
        AutoStart = $details.autoStart
        StartupMode = $details.startMode
        RecyleTime = $details.recycling.periodicRestart.time
        RecyleMemory = $details.recycling.periodicRestart.Memory
        RecyleRequests = $details.recycling.periodicRestart.Requests
    })
}

function Get-AppPool-Requests 
{
    param(
        [string] $appPool
    )
    Set-Location "IIS:\AppPools\$appPool\WorkerProcesses"
    $process = Get-ChildItem "IIS:\AppPools\$appPool\WorkerProcesses" | Select -ExpandProperty ProcessId
    $requests = (Get-Item $process).GetRequests(0).Collection | Select requestId, connectionId, url,verb, timeElapsed

    return $requests 
}

function Create-WebFarm
{
	param(
		[Parameter(Mandatory=$true)]
		[string] $name,
		
		[Parameter(Mandatory=$true)]
		[string] $primary,
		
		[Object] $creds,
		[string[]] $members
	)
		
	if( $creds -eq $null ) 
	{ 
		Write-Host "Please enter an administrator account on all servers in the farm"
		$creds = Get-Credential 
	}
	
	$servers = @()
	$servers += $members
	$servers += $primary
	
	$servers | % {
		$user = $creds.UserName.Split("\")[1] 
		if( -not ( Get-LocalAdmins -Computer $_ | ? { $_ -imatch $user } ) )
		{
			Write-Host "Adding $user to " $_
			Add-LocalAdmin -Computer $_ -Group $user
		}
	}
	
	New-WebFarm -WebFarm $name -Credentials $creds -Enabled -EnableProvisioning 
	New-Server -WebFarm $name -Address $primary -Enabled -IsPrimary
	Add-ServersToWebFarm -name $name -members $members
	
	return (Get-WebFarm -WebFarm $name)
}

function Add-ServersToWebFarm
{
	param(
		[Parameter(Mandatory=$true)]
		[string] $name,
		
		[Parameter(Mandatory=$true)]
		[string[]] $members
	)
	
	$members | % { New-Server -WebFarm $name -Address $_ -Enabled }
}

function Remove-ServersFromWebFarm
{
	param(
		[Parameter(Mandatory=$true)]
		[string] $name,
		
		[Parameter(Mandatory=$true)]
		[string[]] $members
	)
	
	$members | % { Remove-Server -WebFarm $name -Address $_ }
}

function Sync-WebFarm
{
	param(
		[Parameter(Mandatory=$true)]
		[string] $name,
	
		[ValidateSet("ProvisionPlatform", "ProvisionApplications")]
		[string] $op = "ProvisionApplications",
		
		[string] $server
	)
	
	$options = @{
		WebFarm = $name
		Name = $op
		SkipRestart = $true
		Force = $true
	}
	if( -not [string]::IsNullOrEmpty($server) ) { $options.Add("Address", $server) }
	
	Run-Operation @options
}

function Get-WebFarmServers
{
	param(
		[Parameter(Mandatory=$true)]
		[string] $name
	)
	
	$servers = Get-WebFarm -WebFarm $name | Select -Expand Servers | Select @{Name="Server";Expression={$_.Address}}
	
	return ($servers | Select -Expand Server)
}

function Get-WebFarmController
{
	param(
		[Parameter(Mandatory=$true)]
		[string] $name
	)
	
	$server = Get-WebFarm -WebFarm $name | Select -Expand PrimaryServer | Select @{Name="Server";Expression={$_.Address}}
	
	return ($server | Select -Expand Server)
}

function Get-WebFarmState
{
	param (
		[string] $name,
		[string] $server
	)
	
	$options = @{
		WebFarm = $name
	}
	if( -not [string]::IsNullOrEmpty($server) ) { $options.Add("Address", $server) }
	
	Write-Host $(Get-Date) "- Get Web Farm Information"
	Get-WebFarm -WebFarm $name
	
	Write-Host $(Get-Date) "- Get Web Farm Trace Messages"	
	Get-TraceMessage @options
	
	Write-Host $(Get-Date) "- Get Web Farm Active Operation"
	Get-ActiveOperation @options
	
	Write-Host $(Get-Date) "- Get Web Farm Server Requests"
	Get-ServerRequest @options
	
}

function Get-IISWebState
{
	param(
		[String[]] $computers
	)
	
	Invoke-Command -ComputerName $computers -ScriptBlock { 
		. (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")
		Get-WebSite | Select Name, @{Name="State";Expression={(Get-WebSiteState $_.Name).Value}}, @{Name="Computer";Expression={$ENV:ComputerName}} 
	} | Select Name, State, Computer
}

function Start-IISSite
{
	param(
		[String[]] $computers,
		[String] $site = "Default Web Site",
		[switch] $record,
		[switch] $sp
		
	)
	
	Get-IISWebState $computers
	$list = "Issues Tracker"
	if ($sp){
		$url = "http://teamadmin.gt.com/sites/ApplicationOperations/"
	}
	else {
		$url = "http://teamadmin.gt.com/sites/ApplicationOperations/ApplicationSupport/"
	}
	Write-Host "`nStarting $site . . . `n" -ForegroundColor blue
	
	Invoke-Command -ComputerName $computers -ScriptBlock { 
		param ( [string] $site )
		. (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")
		Start-WebSite -name $site
    	$obj = New-Object PSObject -Property @{
        	Title = "Stop IIS " + $_
            User = $ENV:USERNAME
		    Description = "Stopping IIS for CMS WFE" + $_
	    }
	} -ArgumentList $site
	
	Get-IISWebState $computers
}

function Stop-IISSite
{
	param(
		[String[]] $computers,
		[String] $site = "Default Web Site",
		[switch] $record,
		[switch] $sp
	)
	Get-IISWebState $computers
	$list = "Issues Tracker"
	if ($sp){
		$url = "http://teamadmin.gt.com/sites/ApplicationOperations/"
	}
	else
	{
		$url = "http://teamadmin.gt.com/sites/ApplicationOperations/ApplicationSupport/"
	}
	Write-Host "`nStoping $site . . . `n" -ForegroundColor blue
	Invoke-Command -ComputerName $computers -ScriptBlock { 
		param ( [string] $site )
		. (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")
		Stop-WebSite -name $site
		$obj = New-Object PSObject -Property @{
    	    Title = "Stop IIS " + $_
            User = $ENV:USERNAME
		    Description = "Stopping IIS for CMS WFE" + $_
	    }
	} -ArgumentList $site
	
	Get-IISWebState $computers
}


function Add-DefaultDoc
{
	param(
		[String[]] $computers,
		[string] $site,
		[string] $file,
		[int] $pos = 0
	)
	
	Invoke-Command -ComputerName $computers -ScriptBlock { 
		param(
			[string] $site,
			[string] $file,
			[int] $pos = 0
		)
		
		. (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")
		Add-WebConfiguration //defaultDocument/files "IIS:\sites\$site" -atIndex $pos -Value @{value=$file}
		Get-WebConfiguration //defaultDocument/files "IIS:\sites\$site" | Select -Expand Collection | Select @{Name="File";Expression={$_.Value}}
	} -ArgumentList $site, $file, $pos
}

function Create-IISWebSite
{
	param (
		[string] $site = $(throw 'A site name is required'),
		[string] $path = $(throw 'A physical path is required'),
		[string] $header = $(throw 'A host header must be supplied'),
		[int] $port = 80,
		[Object] $options = @{}
	)
	
	if( -not ( Test-Path $path) )
	{
		throw ( $path + " does not exist " )
	}

	New-WebSite -PhysicalPath $path -Name $site -Port $port  -HostHeader $header @options
}

function Create-IISWebApp
{
	param (
		[string] $site = $(throw 'A site name is required'),
		[string] $app = $(throw 'An application name is required'),
		[string] $path = $(throw 'A physical path is required'),
		[Object] $options = @{}
		
	)	
	New-WebApplication -physicalPath $path -Site $site -Name $app @options
}

function Create-IISVirtualDirectory
{
	param (
		[string] $site = $(throw 'A site name is required'),
		[string] $vdir = $(throw 'An vdir (virtual directory name) is required'),
		[string] $path = $(throw 'A physical path is required'),
		[Object] $options = @{}
	)
	
	New-WebVirtualDirectory -Site $site -Name $vdir -physicalPath $path @options
}

function Create-IISAppPool
{
	param (
		[string] $apppool = $(throw 'An AppPool name is required'),
		[string] $user,
		[string] $pass,
		
		[ValidateSet("v2.0", "v4.0")]
		[string] $version = "v2.0"
	)

	New-WebAppPool -Name $apppool

	if( -not [String]::IsNullOrEmpty($user)  ) 
	{
		if( -not [String]::IsNullOrEmpty($pass) ) 
		{
			Set-ItemProperty "IIS:\apppools\$apppool" -name processModel -value @{userName=$user;password=$pass;identitytype=3}
		}
		else 
		{
			throw ($pass + " can not be empty if the user variable is defined")
		}
	}

	if( -not [String]::IsNullOrEmpty($version) )
	{
		Set-ItemProperty "IIS:\AppPools\$apppool" -name managedRuntimeVersion $version
	}

}

function Create-IIS7AppPool
{
	param (
		[string] $apppool = $(throw 'An AppPool name is required'),
		[string] $user,
		[string] $pass,
		
		[ValidateSet("v2.0", "v4.0")]
		[string] $version = "v2.0"
	)
	$poolname = 'AppPools\'+$apppool
	New-Item $poolname
	if( -not [String]::IsNullOrEmpty($user)  ) 
	{
		if( -not [String]::IsNullOrEmpty($pass) ) 
		{
			Set-ItemProperty $poolname -name processModel -value @{userName=$user;password=$pass;identitytype=3}
		}
		else 
		{
			throw ($pass + " can not be empty if the user variable is defined")
		}
	}

	if( -not [String]::IsNullOrEmpty($version) )
	{
		Set-ItemProperty $poolname -name managedRuntimeVersion $version
	}

}

function Set-IISAppPoolforWebSite
{
	param (
		[string] $apppool = $(throw 'An AppPool name is required'),
		[string] $site = $(throw 'A site name is required'),
		[string] $vdir
	)
	if( [String]::IsNullOrEmpty($vdir) )
	{
		Set-ItemProperty "IIS:\sites\$site" -name applicationPool -value $apppool
	}
	else 
	{
		Set-ItemProperty "IIS:\sites\$site\$vdir" -name applicationPool -value $apppool
	}
}

function Set-SSLforWebApplication
{
	param (
		[string] $name,
		[string] $common_name,
		[Object] $options = @{}
	)
	
	Get-WebBinding $name
	
	$cert_thumprint = Get-ChildItem -path cert:\LocalMachine\My | Where { $_.Subject.Contains($common_name) } | Select -Expand Thumbprint
	New-WebBinding -Name $name -IP "*" -Port 443 -Protocol https @options
	cd IIS:\SslBindings
	Get-item cert:\LocalMachine\MY\$cert_thumprint | new-item 0.0.0.0!443

	Get-WebBinding $name
}


function Update-SSLforWebApplication
{
	param (
		[string] $name,
		[string] $common_name
	)
	
	Get-WebBinding $name
	
	$cert_thumprint = Get-ChildItem -path cert:\LocalMachine\My | Where { $_.Subject.Contains($common_name) } | Select -Expand Thumbprint
	cd IIS:\SslBindings
	Get-item cert:\LocalMachine\MY\$cert_thumprint | Set-item 0.0.0.0!443

	Get-WebBinding $name
}


function Set-IISLogging
{
	param (
		[string] $site = $(throw 'A site name is required'),
		[string] $path = $(throw 'A physical path is required')
	)
	
	Set-ItemProperty "IIS:\Sites\$site" -name LogFile.Directory -value $path
	Set-ItemProperty "IIS:\Sites\$site" -name LogFile.logFormat.name -value "W3C"	
	Set-ItemProperty "IIS:\Sites\$site" -name LogFile.logExtFileFlags -value 131023
}

$global:netfx = @{
	"1.1x86" = "C:\WINDOWS\Microsoft.NET\Framework\v1.1.4322\CONFIG\machine.config"; 
    "2.0x86" = "C:\WINDOWS\Microsoft.NET\Framework\v2.0.50727\CONFIG\machine.config";
	"4.0x86" = "C:\WINDOWS\Microsoft.NET\Framework\v4.0.30319\CONFIG\machine.config";
	"2.0x64" = "C:\WINDOWS\Microsoft.NET\Framework64\v2.0.50727\CONFIG\machine.config";
	"4.0x64" = "C:\WINDOWS\Microsoft.NET\Framework64\v4.0.30319\CONFIG\machine.config"
}

function Generate-MachineKey 
{
	param (
		[int] $keylen
	) 
	
	$buff = new-object "System.Byte[]" $keylen
	$rnd = new-object System.Security.Cryptography.RNGCryptoServiceProvider
	$rnd.GetBytes($buff)
	$result = [String]::Empty
	
	for( $i=0; $i -lt $keylen; $i++)
	{
		$result += [System.String]::Format("{0:X2}",$buff[$i])
	}
	
	return $result
}

function Set-MachineKey 
{
	param(
		[string] $version = "2.0x64",
		[string] $validationKey,
		[string] $decryptionKey,
		[string] $validation
	) 
	
    Write-Host "Setting machineKey for $version"
    $currentDate = (Get-Date).tostring("mmddyyyyhhmms") 
    $machineConfig = $netfx[$version]
        
    if( Test-Path $machineConfig )
	{
        $xml = [xml] ( Get-Content $machineConfig )
        $xml.Save( $machineConfig + "." + $currentDate )
        $root = $xml.get_DocumentElement()
        $system_web = $root.system.web

        if ( $system_web.machineKey -eq $nul )
		{ 
        	$machineKey = $xml.CreateElement("machineKey") 
        	$a = $system_web.AppendChild($machineKey)
        }
		
        $system_web.SelectSingleNode("machineKey").SetAttribute("validationKey","$validationKey")
        $system_web.SelectSingleNode("machineKey").SetAttribute("decryptionKey","$decryptionKey")
        $system_web.SelectSingleNode("machineKey").SetAttribute("validation","$validation")
       
		$xml.Save( $machineConfig )
    }
    else
	{
		Write-Host "$version is not installed on this machine" -Fore yellow 
	}
}

function Get-WebDataConnectionString {
	param ( 
		[string] $computer = ".",
		[string] $site
	)

	$connect_string = { 
		param ( [string] $site	)
		
		. (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")
	
        if( !(Test-Path "IIS:\Sites\$site" ) ) {
            throw "Could not find $site"
            return
        }

		$connection_strings = @()
        $configs = Get-WebConfiguration "IIS:\Sites\$site" -Recurse -Filter /connectionStrings/* | 
            Select PsPath, Name, ConnectionString  |
            Where { $_.ConnectionString -imatch "data source|server" }

		foreach( $config in $configs ) {
			
            if( [string]::IsNullOrEmpty($config) ) { continue }
		
			$connection_string = New-Object PSObject -Property @{
                Path = $config.PsPath -replace ("MACHINE/WEBROOT/APPHOST")
                Name = $config.Name
                Server = [string]::Empty
                Database = [string]::Empty
                UserId = [string]::Empty
                Password = [string]::Empty
            }

            $parameters = $config.ConnectionString.Split(";")
			foreach ( $parameter in $parameters ) {	 
                $key,$value = $parameter.Split("=")

                switch -Regex ($key) {
                    "Data Source|Server" {
                        $connection_string.Server = $value	
                    }
                    "Initial Catalog|AttachDBFilename" {
                        $connection_string.Database = $value	
                    }
                    "user id" {
                        $connection_string.UserId = $value	
                    }
                    "Integrated Security" {
                        $connection_string.UserId = "ApplicationPoolIdentity"	
                        $connection_string.Password = "*" * 5
                    }
                    "password" {
                        $connection_string.Password = $value	
                    }
                }

			}
			$connection_strings += $connection_string
		}
		return $connection_strings
	}
	
	return ( Invoke-Command -Computer $computer -Scriptblock $connect_string -ArgumentList $site )
	
}

function Get-MachineKey 
{
	param (
		[string] $version = "2.0x64"
	)
	
    Write-Host "Getting machineKey for $version"
    $machineConfig = $netfx[$version]
    
    if( Test-Path $machineConfig )
	{ 
        $machineConfig = $netfx.Get_Item( $version )
        $xml = [xml]( Get-Content $machineConfig )
        $root = $xml.get_DocumentElement()
        $system_web = $root.system.web

        if ($system_web.machineKey -eq $nul)
		{ 
        	Write-Host "machineKey is null for $version" -fore red
        }
        else 
		{
            Write-Host "Validation Key: $($system_web.SelectSingleNode("machineKey").GetAttribute("validationKey"))" -Fore green
    	    Write-Host "Decryption Key: $($system_web.SelectSingleNode("machineKey").GetAttribute("decryptionKey"))" -Fore green
            Write-Host "Validation: $($system_web.SelectSingleNode("machineKey").GetAttribute("validation"))" -Fore green
        }
    }
    else 
	{ 
		Write-Host "$version is not installed on this machine" -Fore yellow 
	}
}

function Set-AppPoolLogging
{
	param (
		[string[]] $Computers = $(throw 'A computer name is required')
	)
	foreach($computer in $Computers)
	{
		invoke-command -computer $computer -script { cscript d:\inetpub\adminscripts\adsutil.vbs Set w3svc/AppPools/LogEventOnRecycle 255}
	}
}
function Get-AppPoolLogging
{
	param (
		[string[]] $Computers = $(throw 'A computer name is required')
	)
	foreach($computer in $Computers)
	{
	invoke-command -computer $computer -script { cscript d:\inetpub\adminscripts\adsutil.vbs Get w3svc/AppPools/LogEventOnRecycle}
	}
}
function Set-ShareName
{
	param (
		[string] $path = $(throw 'A path is required')
	)

	if ($path -match "^[a-z][:]")
				{
					$out += $path -replace "[:]","$"
				}
			
	
	return $out
}

function Recycle-ApplicationPool
{
	param(
	[string] $app = $(throw 'Application Name Required'),
	
	[string] $env = $(throw 'environment is required'),
	
	[switch]
	$full,
	
	[switch]
	$record,
	
	[string]
	$description,
	
	[string] $servername = 'default'
)

$url = "http://teamadmin.gt.com/sites/ApplicationOperations/"
$list = "Issues Tracker"
$kill = {
	param ( [int] $p ) 
	Stop-Process -id $p -force
}
if ( $servername -eq 'default')
{
	Write-Host 'Retrieving Application information for $app'
	$appinfo = Get-SPListViaWebService -url 'http://teamadmin.gt.com/sites/ApplicationOperations/applicationsupport/' -list "WebSites" -view '{D26D8609-B932-445C-823B-776EF9079285}' | Where {$_.SiteName -eq $apps -and $_.Environment -eq $env}
	$apppool = '/W3SVC/AppPools/'+$appinfo."AppPoolName"
	$servernames = Get-LookupFieldData $appinfo."Real Servers"
	Foreach($servername in $servernames)
	{
		$before = Find-IISProcess -server $servername -app $app
		Stop-IISAppPool -server $servername -appPools $apppool
		$after = Find-IISProcess -server $servername -app $app
		if ( $before -eq $after)
			{
			Write-Host -foreground red "Found a process that didn't stop so going to kill PID - " $after " on " $servername
			Invoke-Command -computer $servername -script $kill -arg $after
			}
		if($record)
		{
		Set-Record -Title ($app + ' outage') -Description ('Application Pool '+$apppool+' was recycled on '+$servername)
		}
	}
	
	
}
else
{
		$before = Find-IISProcess -server $servername -app $app
		Stop-IISAppPool -server $servername -appPools $apppool
		$after = Find-IISProcess -server $servername -app $app
		if ( $before -eq $after)
			{
			Write-Host -foreground red "Found a process that didn't stop so going to kill PID - " $after " on " $servername
			Invoke-Command -computer $servername -script $kill -arg $after
			}
		if($record)
		{
		Set-Record -Title ($app + ' outage') -Description ('Application Pool '+$apppool+' was recycled on '+$servername)
		}	
	
}
}
function Find-IISProcess
{	
	param (
	[string] $server = $(throw 'Server must be specified'),
	[string] $app = $(throw 'Application must be specified')
	)
	[regex]$pattern = "-ap ""(.+)"""
	$apps= gwmi win32_process -filter 'name="w3wp.exe"' -computer $computers | Select CSName, ProcessId, @{Name="AppPoolID";Expression={$pattern.Match($_.commandline).Groups[1].Value}} | where { $_.AppPoolID.Contains($app) } 
	return $apps.ProcessId
	{
	#	Write-Host -foreground red "Found a process that didn't stop so going to kill PID - " $_.ProcessId " on " $_.CSName 
	#	Invoke-Command -computer $_.CSName -script $kill -arg $_.ProcessId
	}
}
function Start-IISAppPool
{
param (
	[string] $server = $(throw 'The server name is required'),
	[string] $appPools = $(throw 'Application pool name is required'),
	[switch] $whatif
)
$apppool = 'W3SVC/AppPools/'+$appPools
Get-WmiObject -Class IISApplicationPool -Namespace "root\microsoftiisv2" -ComputerName $server -Authentication 6 | where { $_.Name -eq $apppool } | % { 
	if($whatif) {
		Write-Host "[WHATIF] Starting " $_.Name " on " $_.__SERVER -foregroundcolor YELLOW
	} else {
		Write-Host "Starting " $_.Name " on " $_.__SERVER -foregroundcolor GREEN	
	 	$_.Start() 
	}
}
}
function Stop-IISAppPool
{
param (
	[string] $server = $(throw 'The server name is required'),
	[string] $appPools = $(throw 'Application pool name is required'),
	[switch] $whatif
)
$apppool = 'W3SVC/AppPools/'+$appPools
Get-WmiObject -Class IISApplicationPool -Namespace "root\microsoftiisv2" -ComputerName $server -Authentication 6 | where { $_.Name -eq $apppool } | % { 
	if($whatif) {
		Write-Host "[WHATIF] Starting " $_.Name " on " $_.__SERVER -foregroundcolor YELLOW
	} else {
		Write-Host "Stopping " $_.Name " on " $_.__SERVER -foregroundcolor GREEN	
	 	$_.Stop() 
	}
}

}

function Reset-IIS
{
param (
	[string[]] $servers = $(throw 'At least one server name is required'),
	[switch] $record
	
	)
	$servers | % { 
		iisreset $_ /stop
		Start-sleep 5
		iisreset $_ /start
	}
	if($record)
	{
	Set-Record -Title ($app + ' outage') -Description ($_ +' - A Full IIS Reset was performed')
	}
}
function Validate-ApplicationPool
{
param (
	[string] $server = $(throw 'The server name is required'),
	[string] $app = $(throw 'Application Name is required')
	)
$apppool = 'W3SVC/AppPools/'+$app
$a = Get-WmiObject -Class IISApplicationPool -Namespace "root\microsoftiisv2" -ComputerName $server -Authentication 6 | where { $_.Name -eq $apppool }
if ($a -ne $null)
	{
	return $true
	}
else
	{
	return $false
	}
}
function Validate-IIS7ApplicationPool
{
param (
	[string] $server = $(throw 'The server name is required'),
	[string] $app = $(throw 'Application Name is required')
	)
$apppool = 'IIS:\AppPools\'+$app
$a = Select-Object $apppool
if ($a -ne $null)
	{
	return $true
	}
else
	{
	return $false
	}
}
function get-IISexecution{
	param(
	[string] $server,
	[string] $App
	)
$WGCscript = {
			Import-Module WebAdministration
			cd "IIS:\AppPools\AppPool - team.gt.com\workerprocesses"
			$proc = dir | Select ProcessID -First 1
			$proc
			$handles= ((get-item $proc.ProcessID).GetRequests(0).Collection) | Sort-Object timeelapsed -Descending | select url,timeelapsed
			return $handles
}  
	$session = New-PSSession -ComputerName $server
	if ($App -eq "WGC")
	{
	Invoke-Command -ComputerName $server -ScriptBlock $WGCscript
	
	}
}

