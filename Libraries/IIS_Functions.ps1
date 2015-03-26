Import-Module WebAdministration
Add-PSSnapin WebFarmSnapin -ErrorAction SilentlyContinue

$ENV:PATH += ';C:\Program Files\IIS\Microsoft Web Deploy V2'

Set-Variable -Name cert_path -Value 'cert:\LocalMachine\My' -Option Constant
Set-Variable -Name app_pool_path -value 'IIS:\AppPools' -Option Constant
Set-Variable -Name iis_path -value 'IIS:\Sites' -Option Constant

$global:netfx = @{
	"1.1x86" = "C:\WINDOWS\Microsoft.NET\Framework\v1.1.4322\CONFIG\machine.config"; 
    "2.0x86" = "C:\WINDOWS\Microsoft.NET\Framework\v2.0.50727\CONFIG\machine.config";
	"4.0x86" = "C:\WINDOWS\Microsoft.NET\Framework\v4.0.30319\CONFIG\machine.config";
	"2.0x64" = "C:\WINDOWS\Microsoft.NET\Framework64\v2.0.50727\CONFIG\machine.config";
	"4.0x64" = "C:\WINDOWS\Microsoft.NET\Framework64\v4.0.30319\CONFIG\machine.config"
}

function Get-ARRRules
{
    Set-Variable -Name filter -Value "/system.webServer/rewrite/globalRules/rule" -Option constant
    Set-Variable -Name path -Value "MACHINE/WEBROOT/APPHOST"  -Option constant

    $rules = Get-WebConfigurationProperty -Filter $filter -PSPath $path  -Name "."

    $ps_rules_objects = @()
    foreach( $rule in $rules ) {
	    foreach( $input in $rule.conditions.collection ) {
		    $ps_rules_objects += (New-Object PSObject -Property @{
			    RuleName = $rule.Name
			    Enabled = $rule.Enabled
			    Match = $rule.Match.Url
			    Input = $input.Input
			    MatchType = $input.MatchType
			    Pattern = $input.Pattern
		    })
	    }
    }

    return $ps_rules_objects
}

function Set-ARRRuleCondition
{
    param(
        [Parameter(Mandatory=$true)]
        [string] $pattern,
        [Parameter(Mandatory=$true)]
        [string] $rule_name,
        [string] $input = '{HTTP_HOST}'
    )

    Set-Variable -Name filter -Value ("/system.webServer/rewrite/globalRules/rule[@name='{0}']/conditions" -f $rule_name)
    Set-Variable -Name path -Value "MACHINE/WEBROOT/APPHOST"  -Option constant

    $condition = @{
	    pspath = $path
	    filter = $filter
	    value = @{
		    input = $input
		    pattern = $pattern
	    }
    }

    Add-WebConfiguration @condition
}

function Get-CustomHeaders 
{
    return ( Get-WebConfiguration //httpProtocol/customHeaders | Select -Expand Collection | Select Name, Value )
}

function Set-CustomHeader
{
    param (
        [string] $name,
        [string] $value
    )
    Add-WebConfiguration //httpProtocol/customHeaders -Value @{Name=$name;Value=$value}
}

function Set-AlwaysRunning
{
    param(
        [string] $app_pool
    )
    Set-ItemProperty -Path (Join-Path -Path $app_pool_path -ChildPath $app_pool) -Name startMode -Value "AlwaysRunning"
}

function Set-PreLoad 
{
    param(
        [string] $site
    )
    Set-ItemProperty -Path (Join-Path -Path $iis_path -ChildPath $site) -name applicationDefaults.preloadEnabled -value True
}

function Get-IISAppPoolDetails
{
    param(
        [string] $app_pool
    )

    if( !(Test-Path (Join-Path -Path $app_pool_path -ChildPath $app_pool) ) ) {
        throw "Could not find " + $app_pool
        return -1
    }

    $details =  Get-ItemProperty -Path (Join-Path $app_pool_path $app_pool) | Select startMode, processModel, recycling,  autoStart, managedPipelineMode, managedRuntimeVersion , queueLength                                

    return (New-Object PSObject -Property @{
        UserName = $details.processModel.UserName
        IdleTimeOut = $details.processModel.IdleTimeOut
        LoadProfile = $details.processModel.SetProfileEnvironment
        PipelineMode = $details.managedPipelineMode
        DotNetVersion = $details.managedRuntimeVersion
        QueueLength = $details.queueLength
        AutoStart = $details.autoStart
        StartupMode = $details.startMode
        RecyleTimeInHours = $details.recycling.periodicRestart.time.TotalHours
        RecyleMemory = $details.recycling.periodicRestart.Memory
        RecyleRequests = $details.recycling.periodicRestart.Requests
    })
}

function Get-AppPool-Requests 
{
    param(
        [string] $appPool
    )
    Set-Location (Join-Path $app_pool_path "$appPool\WorkerProcesses")
    $process = Get-ChildItem (Join-Path $app_pool_path "$appPool\WorkerProcesses") | Select -ExpandProperty ProcessId
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
		
	if( $creds -eq $null ) { 
		$creds = Get-Credential -Message "Please enter an administrator account on all servers in the farm"
	}
	
	$servers = @()
	$servers += $members
	$servers += $primary
	
	foreach( $server in $servers ) {
		$user = $creds.UserName.Split("\")[1] 
		if( -not ( Get-LocalAdmins -Computer $server | Where { $_ -imatch $user } ) ) {
			Write-Verbose -Message ("Adding " + $user + " to " + $server)
			Add-LocalAdmin -Computer $server -Group $user
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
	
    foreach( $computer in $members) {
	    New-Server -WebFarm $name -Address $computer -Enabled
    }
}

function Remove-ServersFromWebFarm
{
	param(
		[Parameter(Mandatory=$true)]
		[string] $name,
		
		[Parameter(Mandatory=$true)]
		[string[]] $members
	)

	foreach( $computer in $members) {
	    Remove-Server -WebFarm $name -Address $computer 
    }
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
	
	Write-Verbose -Message ("[{0}] - Get Web Farm Information" -f $(Get-Date))
	Get-WebFarm -WebFarm $name
	
	Write-Verbose -Message ("[{0}] - Get Web Farm Trace Messages" -f $(Get-Date))	
	Get-TraceMessage @options
	
	Write-Verbose -Message ("[{0}] - Get Web Farm Active Operation" -f $(Get-Date))
	Get-ActiveOperation @options
	
	Write-Verbose -Message ("[{0}] - Get Web Farm Server Requests" -f $(Get-Date))
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
		[String] $site = "Default Web Site"
	)
	
	Get-IISWebState $computers
	Write-Verbose -Message "Starting $site . . ."
	
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
		[String] $site = "Default Web Site"
	)
	Get-IISWebState $computers
	Write-Verbose -Message "Stopping $site . . ."

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
		Add-WebConfiguration //defaultDocument/files (Join-path $iis_path $site) -atIndex $pos -Value @{value=$file}
		Get-WebConfiguration //defaultDocument/files (Join-path $iis_path $site) | Select -Expand Collection | Select @{Name="File";Expression={$_.Value}}
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
	
	if( -not ( Test-Path $path) ) {
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

	if( -not [String]::IsNullOrEmpty($user)  ) {
		if( -not [String]::IsNullOrEmpty($pass) ) {
			Set-ItemProperty (Join-Path $app_pool_path $apppool) -name processModel -value @{userName=$user;password=$pass;identitytype=3}
		}
		else {
			throw ($pass + " can not be empty if the user variable is defined")
		}
	}

	if( -not [String]::IsNullOrEmpty($version) ) {
		Set-ItemProperty (Join-Path $app_pool_path $apppool) -name managedRuntimeVersion $version
	}

}

function Set-IISAppPoolforWebSite
{
	param (
		[string] $apppool = $(throw 'An AppPool name is required'),
		[string] $site = $(throw 'A site name is required'),
		[string] $vdir
	)

	if( [String]::IsNullOrEmpty($vdir) ) {
		Set-ItemProperty -Path (Join-path $iis_path $site) -name applicationPool -value $apppool
	}
	else  {
		Set-ItemProperty -Path (Join-path $iis_path "$site\$vdir") -name applicationPool -value $apppool
	}
}

function Set-SSLforWebApplication
{
	param (
		[string] $name,
		[string] $common_name,
        [string] $ip = "0.0.0.0",
		[Object] $options = @{}
	)

	$cert_thumbprint = Get-ChildItem -path $cert_path | Where { $_.Subject.Contains($common_name) } | Select -Expand Thumbprint

    if( $ip -eq "0.0.0.0" ) {
        New-WebBinding -Name $name -IP "*" -Port 443 -Protocol https @options
    }
    else {
        New-WebBinding -Name $name -IP $ip -Port 443 -Protocol https @options
    }

    $binding = Get-WebBinding -Name $name -Protocol https
    $binding.AddSslCertificate( [string]$cert_thumbprint, "My" )
}

function Update-SSLforWebApplication
{
	param (
		[string] $name,
		[string] $common_name
	)
	
    $cert_thumbprint = Get-ChildItem -path $cert_path | Where { $_.Subject.Contains($common_name) } | Select -Expand Thumbprint
    $binding = Get-WebBinding -Name $name -Protocol https
    $binding.RemoveSslCertificate()
    $binding.AddSslCertificate( [string]$cert_thumbprint, "My" )

}

function Set-IISLogging
{
	param (
		[string] $site = $(throw 'A site name is required'),
		[string] $path = $(throw 'A physical path is required')
	)
	
	Set-ItemProperty (Join-path $iis_path $site) -name LogFile.Directory -value $path
	Set-ItemProperty (Join-path $iis_path $site) -name LogFile.logFormat.name -value "W3C"	
	Set-ItemProperty (Join-path $iis_path $site) -name LogFile.logExtFileFlags -value 131023
}

function Get-WebDataConnectionString {
	param ( 
		[string] $computer = ".",
		[string] $site
	)

	$connect_string = { 
		param ( [string] $site	)
		
		. (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")
	
        if( !(Test-Path (Join-path $iis_path $site) ) ) {
            throw "Could not find $site"
            return
        }

		$connection_strings = @()
        $configs = Get-WebConfiguration (Join-path $iis_path $site) -Recurse -Filter /connectionStrings/* | 
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
	
    Write-Verbose -Message "Getting machineKey for $version"
    $machineConfig = $netfx[$version]
    
    if( Test-Path $machineConfig ){ 
        $machineConfig = $netfx.Get_Item( $version )
        $xml = [xml]( Get-Content $machineConfig )
        $root = $xml.get_DocumentElement()
        $system_web = $root.system.web

        if (!$system_web.machineKey -eq $nul) { 
			return (New-Object PSObject -Property @{
				ValidationKey = $($system_web.SelectSingleNode("machineKey").GetAttribute("validationKey"))
				DecryptionKey = $($system_web.SelectSingleNode("machineKey").GetAttribute("decryptionKey"))
				Validation    = $($system_web.SelectSingleNode("machineKey").GetAttribute("validation"))
			})
        }
	}
}

function Set-MachineKey 
{
	param(
		[string] $version = "2.0x64",
		[string] $validationKey,
		[string] $decryptionKey,
		[string] $validation
	) 
	
    Write-Verbose -Message "Setting machineKey for $version"
    $currentDate = (Get-Date).tostring("mmddyyyyhhmms") 
    $machineConfig = $netfx[$version]
        
    if( Test-Path $machineConfig )	{
        $xml = [xml] ( Get-Content $machineConfig )
        $xml.Save( $machineConfig + "." + $currentDate )
        $root = $xml.get_DocumentElement()
        $system_web = $root.system.web

        if ( $system_web.machineKey -eq $nul )	{ 
        	$machineKey = $xml.CreateElement("machineKey") 
        	$a = $system_web.AppendChild($machineKey)
        }
		
        $system_web.SelectSingleNode("machineKey").SetAttribute("validationKey","$validationKey")
        $system_web.SelectSingleNode("machineKey").SetAttribute("decryptionKey","$decryptionKey")
        $system_web.SelectSingleNode("machineKey").SetAttribute("validation","$validation")
       
		$xml.Save( $machineConfig )
    }
    else {
		Write-Error "$version is not installed on this machine" -Fore yellow 
	}
}