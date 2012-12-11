#Variables
[void] [Reflection.Assembly]::LoadWithPartialName("System.Security")

$domain_controller = "ad.sharepoint.test"
$from = "admin@sharepoint.test"
$domain  = "mail.sharepoint.test"

$AutoUpdateNotificationLevels= @{0="Not configured"; 1="Disabled" ; 2="Notify before download"; 3="Notify before installation"; 4="Scheduled installation"}
$AutoUpdateDays=@{0="Every Day"; 1="Every Sunday"; 2="Every Monday"; 3="Every Tuesday"; 4="Every Wednesday";5="Every Thursday"; 6="Every Friday"; 7="EverySaturday"}

function New-PSWindow 
{ 
	param( 
		[switch] $noprofile
	)
	
	if($noprofile) { 
		cmd.exe /c start powershell.exe -NoProfile
	} else {
		cmd.exe /c start powershell.exe 
	}
}

function Get-WindowsServices
{
	param (
		[string] $computer
	)
	
	Get-wmiobject win32_service -computer $computer | Select Name,Startname
}

function Change-ServiceAccount
{
	param (
		[string] $account,
		[string] $password,
		[string] $service,
		[string] $computer = "localhost"
	)
	
	$svc=gwmi win32_service -computername $computer | ? { $_.Name -eq $service }
	
	$svc.StopService()
	$svc.change($null,$null,$null,$null,$null,$null,$account,$password,$null,$null,$null)
	$svc.StartService()
}

function Disable-InternetExplorerESC 
{
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer
    Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
}

function Enable-InternetExplorerESC 
{
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 1
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 1
    Stop-Process -Name Explorer
    Write-Host "IE Enhanced Security Configuration (ESC) has been enabled." -ForegroundColor Green
}

function Disable-UserAccessControl
{
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 00000000
    Write-Host "User Access Control (UAC) has been disabled." -ForegroundColor Green    
}
 
function Install-MSMQ
{
    Import-module ServerManager
    Get-WindowsFeature | ? { $_.Name -match "MSMQ" } | % { Add-WIndowsFeature $_.Name }
}

function Get-Url 
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string] $url,
	    [ValidateSet("NTLM", "BASIC", "NONE")]
        [string] $AuthType = "NTLM",
        [ValidateSet("HEAD", "POST", "GET")]
        [string] $Method = "HEAD",
    	[int] $timeout = 8,
        [string] $Server,
        [Management.Automation.PSCredential] $creds
    )
    
    $request = [System.Net.WebRequest]::Create($url)
    $request.Method = $Method
    $request.Timeout = $timeout * 1000
    $request.AllowAutoRedirect = $false
    $request.ContentType = "application/x-www-form-urlencoded"
    $request.UserAgent = "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0; .NET CLR 1.1.4322)"
    
    if ($AuthType -eq "BASIC")
    {
        $network_creds = $creds.GetNetworkCredential()
        $auth = "Basic " + [Convert]::ToBase64String([Text.Encoding]::Default.GetBytes($network_creds.UserName + ":" + $network_creds.Password))
        $request.Headers.Add("Authorization", $auth)
        $request.Credentials = $network_creds
        $request.PreAuthenticate = $true
    }
    elseif( $AuthType -eq "NTLM" ) 
    {
        $request.Credentials =  [System.Net.CredentialCache]::DefaultCredentials
    }
       
    if( -not [String]::IsNullorEmpty($Server) )
    {
        #$request.Headers.Add("Host", $HostHeader)
		$request.Proxy = new-object -typename System.Net.WebProxy -argumentlist $Server
    }
    
    #Wrap this with a measure-command to determine type
    "[{0}][REQUEST] Getting $url ..." -f $(Get-Date)
	try {
		$timing_request = Measure-Command { $response = $request.GetResponse() }
		$stream = $response.GetResponseStream()
		$reader = New-Object System.IO.StreamReader($stream)

		"[{0}][REPLY] Server = {1} " -f $(Get-Date), $response.Server
		"[{0}][REPLY] Status Code = {1} {2} . . ." -f $(Get-Date), $response.StatusCode, $response.StatusDescription
		"[{0}][REPLY] Content Type = {1} . . ." -f $(Get-Date), $response.ContentType
		"[{0}][REPLY] Content Length = {1} . . ." -f $(Get-Date), $response.ContentLength
		"[{0}][REPLY] Total Time = {1} . . ." -f $(Get-Date), $timing_request.TotalSeconds

		if( $Method -ne "HEAD" )
		{
			$ans = Read-Host "Do you wish to see the contents of the request (y/n) - "
			if( $ans -eq "y" ) {
				$url_split = $url.Split("/")
				if( $url_split[$url_split.Length - 1].Contains(".") ) 
				{ 
					$file_name =  $url_split[$url_split.Length - 1]
				} 
				else
				{
					$file_name = $server + ".html"
				}
				$ResultFile = Join-Path $ENV:TEMP ($url.Trim("http://").Split("/")[0] + "-" + $file_name)
				$reader.ReadToEnd() | Out-File -Encoding ascii $ResultFile
				
				if( (dir $ResultFile).Extension -match "html|aspx" ) {
					$ie = new-object -comobject "InternetExplorer.Application"  
					$ie.visible = $true  
					$ie.navigate($ResultFile)
				} else { 
					&$ResultFile
				}
				
				Start-Sleep 10
				
				Remove-Item $ResultFile
			}
		}
	}
	catch [System.Net.WebException]
	{
		Write-Error ("The request failed with the following WebException - " + $_.Exception.ToString() )
	}
    
}

function Get-JsonRequest 
{
	[CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string] $url,
	    [ValidateSet("NTLM", "BASIC", "NONE")]
        [string] $AuthType = "NTLM",
    	[int] $timeout = 8,
        [string] $Server,
        [Management.Automation.PSCredential] $creds
    )
    
	$request = [System.Net.HttpWebRequest]::Create($url)
    $request.Method = "GET"
    $request.Timeout = $timeout * 1000
    $request.AllowAutoRedirect = $false
    $request.ContentType = "application/x-www-form-urlencoded"
    $request.UserAgent = "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0; .NET CLR 1.1.4322)"
	$request.Accept = "application/json;odata=verbose"
	
	if ($AuthType -eq "BASIC") {
        $network_creds = $creds.GetNetworkCredential()
        $auth = "Basic " + [Convert]::ToBase64String([Text.Encoding]::Default.GetBytes($network_creds.UserName + ":" + $network_creds.Password))
        $request.Headers.Add("Authorization", $auth)
        $request.Credentials = $network_creds
        $request.PreAuthenticate = $true
    }
    elseif( $AuthType -eq "NTLM" ) {
        $request.Credentials =  [System.Net.CredentialCache]::DefaultCredentials
    }
       
    if( $Server -ne [String]::Empty ) {
		$request.Proxy = new-object -typename System.Net.WebProxy -argumentlist $Server
    }
    
    Write-Verbose ("[{0}][REQUEST] Getting $url ..." -f $(Get-Date))
	try {
		$timing_request = Measure-Command { $response = $request.GetResponse() }
		$stream = $response.GetResponseStream()
		$reader = New-Object System.IO.StreamReader($stream)
		
		Write-Verbose ("[{0}][REPLY] Server = {1} " -f $(Get-Date), $response.Server)
		Write-Verbose ("[{0}][REPLY] Status Code = {1} {2} . . ." -f $(Get-Date), $response.StatusCode, $response.StatusDescription)
		Write-Verbose ("[{0}][REPLY] Content Type = {1} . . ." -f $(Get-Date), $response.ContentType)
		Write-Verbose ("[{0}][REPLY] Content Length = {1} . . ." -f $(Get-Date), $response.ContentLength)
		Write-Verbose ("[{0}][REPLY] Total Time = {1} . . ." -f $(Get-Date), $timing_request.TotalSeconds)

		return ( $reader.ReadToEnd() | ConvertFrom-Json )
	}
	catch [System.Net.WebException] {
		Write-Error ("The request failed with the following WebException - " + $_.Exception.ToString() )
	}
	
}

function Get-Clipboard 
{
	PowerShell -NoProfile -STA -Command { Add-Type -Assembly PresentationCore; [Windows.Clipboard]::GetText() }
}

function Set-Clipboard 
{
 	Param(
		[Parameter(ValueFromPipeline = $true)]
		[object[]] $inputObject
	)
	begin
	{
		$objectsToProcess = @()
	}
	process
	{
		$objectsToProcess += $inputObject
	}
	end
	{
		$objectsToProcess | PowerShell -NoProfile -STA -Command {
			Add-Type -Assembly PresentationCore
			$clipText = ($input | Out-String -Stream) -join "`r`n" 
			[Windows.Clipboard]::SetText($clipText)
		}
	}
}

function Get-Uptime 
{
	param($computer)
	
	$lastboottime = (Get-WmiObject -Class Win32_OperatingSystem -computername $computer).LastBootUpTime
	$sysuptime = (Get-Date) - [System.Management.ManagementDateTimeconverter]::ToDateTime($lastboottime)
	
	Write-Host "System ($computer) has been online since : " $sysuptime.days "days" $sysuptime.hours "hours" $sysuptime.minutes "minutes" $sysuptime.seconds "seconds"
}

function Get-TopProcesses
{
	param(
        [string] $computer = $env:COMPUTERNAME,
        [int] $threshold = 5
    )
 
    # Test connection to computer
    if( !(Test-Connection -Destination $computer -Count 1) ){
        throw "Could not connect to :: $computer"
    }
 
    # Get all the processes
    $processes = Get-WmiObject -ComputerName $computer -Class Win32_PerfFormattedData_PerfProc_Process -Property Name, PercentProcessorTime
  
    $items = @()
    foreach( $process in ($processes | where { $_.Name -ne "Idle"  -and $_.Name -ne "_Total" }) )
	{
        if( $process.PercentProcessorTime -ge $threshold )
		{
            $items += (New-Object PSObject -Property @{
				Name = $process.Name
				CPU = $process.PercentProcessorTime
			})
        }
    }
  
    return ( $items | Sort-Object -Property CPU -Descending)
}

function Get-ScheduledTasks([string] $server) 
{
	$tasks = @()
	
	$tasks_com_connector = New-Object -ComObject("Schedule.Service")
	$tasks_com_connector.Connect($server)
	$tasks_com_connector.getFolder("\").GetTasks(0) | Select Name, LastRunTime, LastTaskResult, NextRunTime, XML | %  {
	
		$xml = [xml] ( $_.XML )
		
		$tasks += (New-Object PSObject -Property @{
			HostName = $server
			Name = $_.Name
			LastRunTime = $_.LastRunTime
			LastResult = $_.LastTaskResult
			NextRunTime = $_.NextRunTime
			Author = $xml.Task.RegistrationInfo.Author
			RunAsUser = $xml.Task.Principals.Principal.UserId
			TaskToRun = $xml.Task.Actions.Exec.Command
		})
	}
	
	return $tasks
}

function Import-PfxCertificate 
{    
    param(
		[String] $certPath,
		[String] $certRootStore = "LocalMachine",
		[String] $certStore = "My",
		[object] $pfxPass = $null
    )
    
	$pfx = new-object System.Security.Cryptography.X509Certificates.X509Certificate2    
   
    if ($pfxPass -eq $null) 
	{
		$pfxPass = read-host "Enter the pfx password" -assecurestring
	}
   
    $pfx.import($certPath,$pfxPass,"Exportable,PersistKeySet")    
   
 	$store = new-object System.Security.Cryptography.X509Certificates.X509Store($certStore,$certRootStore)    
 	$store.open("MaxAllowed")    
 	$store.add($pfx)    
 	$store.close()    
 } 
 
function Remove-Certificate 
{
 	param(
		[String] $subject,
		[String] $certRootStore = "LocalMachine",
		[String] $certStore = "My"
    )

	$cert = Get-ChildItem -path cert:\$certRootStore\$certStore | where { $_.Subject.ToLower().Contains($subject) }

	$store = new-object System.Security.Cryptography.X509Certificates.X509Store($certStore,$certRootStore)
	
	$store.Open("ReadWrite")
	$store.Remove($cert)
	$store.Close()
	
}

function Export-Certificate
{
	param(
		[string] $subject,
		[string] $certStore = "My",
		[string] $certRootStore = "LocalMachine",
		[string] $file,
		[object] $pfxPass 
	)
	
	$cert = Get-ChildItem -path cert:\$certRootStore\$certStore | where { $_.Subject.ToLower().Contains($subject) }
	$type = [System.Security.Cryptography.X509Certificates.X509ContentType]::pfx
 
     if ($pfxPass -eq $null) 
	{
		$pfxPass = read-host "Enter the pfx password" -assecurestring
	}
	
	$bytes = $cert.export($type, $pfxPass)
	[System.IO.File]::WriteAllBytes($file , $bytes)
}

function pause
{
	#From http://www.microsoft.com/technet/scriptcenter/resources/pstips/jan08/pstip0118.mspx
	Write-Host "Press any key to exit..."
	$null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Get-PreviousMonthRange
{
	$Object = New-Object PSObject -Property @{            
    	last_month_begin = $(Get-Date -Day 1).AddMonths(-1)
		last_month_end = $(Get-Date -Day 1).AddMonths(-1).AddMonths(1).AddDays(-1)
	}
	
	return $Object
}

function map ($fn, $a)
{  
	for ($i = 0; $i -lt $a.length; $i++)
   	{  
   		$a[$i] = &$fn $a[$i]
   	}
}

function Get-PerformanceCounters
{
	param (
		[String[]] $counters = @("\processor(_total)\% processor time","\physicaldisk(_total)\% disk time","\memory\% committed bytes in use","\physicaldisk(_total)\current disk queue length"),
		[String[]] $computers,
		[int] $samples = 10,
		[int] $interval = 10		
	)
	
	Get-Counter $counters -ComputerName $computers -MaxSamples $samples -SampleInterval $interval | % { $t=$_.TimeStamp; $_.CounterSamples } | Select @{Name="Time";Expression={$t}},Path,CookedValue 

}

function Elevate-Process
{
	$file, [string]$arguments = $args;
	$psi = new-object System.Diagnostics.ProcessStartInfo $file;
	$psi.Arguments = $arguments;
	$psi.Verb = "runas";
	$psi.WorkingDirectory = get-location;
	[System.Diagnostics.Process]::Start($psi);
}

function Get-PSSecurePassword
{
	param (
		[String] $password
	)
	
	return ConvertFrom-SecureString ( ConvertTo-SecureString $password -AsPlainText -Force)
}

function Get-PlainTextPassword
{
	param (
		[String] $password,
		[byte[]] $key
	)

	if($key)
	{
		$secure_string = ConvertTo-SecureString $password -Key $key
	}
	else 
	{
		$secure_string = ConvertTo-SecureString $password
	}
	
	return ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto( [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure_string) ) )
}

function Gen-Passwords
{
	param (
		[int] $number = 10,
		[int] $length = 16,
		[switch] $hash
	)

	[void][Reflection.Assembly]::LoadWithPartialName("System.Web")
	$algorithm = 'sha256'

	$passwords = @()
	for( $i=0; $i -lt $number; $i++)
	{
		$pass = [System.Web.Security.Membership]::GeneratePassword($length,1)
		if( $hash ) {
			$hasher = [System.Security.Cryptography.HashAlgorithm]::create($algorithm)
			$computeHash = $hasher.ComputeHash( [Text.Encoding]::UTF8.GetBytes( $pass.ToString() ) )
			$pass = ( ([system.bitconverter]::tostring($computeHash)).Replace("-","") )
		}
		$passwords += $pass
	}
	return $passwords
}

function Create-SQL2K5Alias( [string] $instance, [int] $port, [string] $alias )
{
	[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
	$objComputer=New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer "."

	$newalias=New-Object ("Microsoft.SqlServer.Management.Smo.Wmi.ServerAlias")
	$newalias.Parent=$objComputer
	$newalias.Name=$alias
	$newalias.ServerName=$instance
	$newalias.ConnectionString=$port
	$newalias.ProtocolName='tcp' 
	$newalias.Create()
}

function Get-WindowsUpdateConfig
{
	$AUSettings = (New-Object -com "Microsoft.Update.AutoUpdate").Settings

	$AUObj = New-Object -TypeName System.Object
	Add-Member -inputObject $AuObj -MemberType NoteProperty -Name "NotificationLevel" -Value $AutoUpdateNotificationLevels[$AUSettings.NotificationLevel]
	Add-Member -inputObject $AuObj -MemberType NoteProperty -Name "UpdateDays"  -Value $AutoUpdateDays[$AUSettings.ScheduledInstallationDay]
	Add-Member -inputObject $AuObj -MemberType NoteProperty -Name "UpdateHour"  -Value $AUSettings.ScheduledInstallationTime 
	Add-Member -inputObject $AuObj -MemberType NoteProperty -Name "Recommended updates" -Value $(IF ($AUSettings.IncludeRecommendedUpdates) {"Included."}  else {"Excluded."})
	return $AuObj
} 

function Get-SystemGAC( [string[]] $servers )
{	
	$s = New-PSSession -Computer $servers
	Invoke-Command -Session $s -ScriptBlock {
		$assemblies = @()
		$dlls = Get-ChildItem -Path C:\windows\assembly -Filter *.dll -Recurse

		foreach ($assembly in $dlls)
		{
			$assembly = [Reflection.Assembly]::ReflectionOnlyLoadFrom($Assembly.FullName)
			if ($assembly -is [System.Reflection.Assembly]) {
				$assemblies += (New-Object PSObject -Property @{
					FullName = $assembly.FullName
					Module = $assembly.ManifestModule
					RunTime = $assembly.ImageRuntimeVersion
					Location = $assembly.Location
					Computer = $ENV:ComputerName	
				})
			}
		}
		return $assemblies
	}
}

function Get-GoogleGraph([HashTable] $ht, [String] $title, [String] $size="750x350", [string] $file="chart.png",  [switch] $invoke)
{
    Set-Variable -Option Constant -Name chartType -Value bhs
    
	$chartdata = [String]::Join( "," , ($ht.GetEnumerator() | sort Key -Descending | % { $_.Value } ))
    $chartYLabel = [String]::Join( "|", ($ht.GetEnumerator() | sort Key | % { $_.Key } )) 
	
	$maximum = $ht.Values | Measure-Object -max | Select -Expand Maximum
	$minimum = $ht.Values | Measure-Object -min | Select -Expand Minimum 
	
	if( $minimum -eq $maximum ) { $minimum = 0 } 
	
	$chartScale = "{0},{1}" -f $minimum, $maximum
    
	$url = "http://chart.apis.google.com/chart?"
	$url += "chtt=$title&"
	$url += "chxt=x,y&"
	$url += "chxl=1:|$chartYLabel&"
	$url += "chxr=0,$chartScale&"
	$url += "chds={0},{1}&" -f $minimum, $maximum
	$url += "cht=$chartType&"
	$url += "chd=t:$chartdata&"
	$url += "chco=4D89F9&"
	$url += "chg=20,50&"
	$url += "chbh=a&"
	$url += "chs=$size" 
	
    $DownLoadFile = $ENV:TEMP + "\"+ $file 
    $webClient = new-object System.Net.WebClient 
    $Webclient.DownloadFile($url, $DownLoadFile) 
	
    if( $invoke ) { Invoke-Item $DownLoadFile } else { return $DownLoadFile	 }
}

function Get-LocalAdmins( [string] $computer )
{
	$adsi  = [ADSI]("WinNT://" + $computer + ",computer") 
	$Group = $adsi.psbase.children.find("Administrators") 
	$members = $Group.psbase.invoke("Members") | %{$_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)} 
	
	return $members
}

function Get-LocalGroup( [string] $computer,[string] $Group )
{
	$adsi  = [ADSI]("WinNT://" + $computer + ",computer") 
	$adGroup = $adsi.psbase.children.find($group) 
	$members = $adGroup.psbase.invoke("Members") | %{$_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)} 
	
	return $members
}

function Add-ToLocalGroup( [string] $computer, [string] $LocalGroup, [string] $DomainGroup )
{
    $aslocalGroup = [ADSI]"WinNT://$computer/$LocalGroup,group"
    $aslocalGroup.Add("WinNT://$domain_controller/$DomainGroup,group")
}

function Add-LocalAdmin( [string] $computer, [string] $Group )
{
    $localGroup = [ADSI]"WinNT://$computer/Administrators,group"
    $localGroup.Add("WinNT://$domain_controller/$Group,group")
}

function Get-WindowsDiskSpace
{
	begin {
		$DiskSpace = @()
	}
	process
	{
		$n = $_.Server
		$p = $_.Partition
		
		$DiskSpace += get-wmiobject -class "Win32_Volume" -namespace "root\cimv2" -computername $n |
			where { $_.Name -eq $p } | 
			Select @{Name="Server";Expression={$n}},@{Name="Partition";Expression={$_.Name}}, @{Name="TotalDiskSpace";Expression={$_.Capacity/1mb}}, @{Name="FreeDiskSpace";Expression={$_.FreeSpace/1mb}}
	}
	end {
		return $DiskSpace
	}
}

function Convert-ObjectToHash( [Object] $obj )
{
	$ht = @{}
	
	$Keys = $obj | Get-Member -MemberType NoteProperty | select Name

	$Keys | % { 
		$key = $_.Name
		
		if( $obj.$key -is [System.Array] ) { 
			$value = [String]::Join(" | ", $obj.$key )
		} else {
			$value = $obj.$key
		}
		$ht.Add( $Key, $Value )
	}

	return $ht
}

function Get-RunningServices( [string] $computer )
{
	gwmi Win32_Service -computer $Computer | Where { $_.State -eq "Running" } | Select Name, PathName, Id, StartMode  
}

function Get-IntermediateCerts()
{
	Get-ChildItem -path cert:\LocalMachine\CA | Select Subject, Issuer, NotAfter | sort NotAfter
}

function Get-InstalledCerts( )
{
	Get-ChildItem -path cert:\LocalMachine\My | Select FriendlyName, Issuer, NotAfter, HasPrivateKey | sort NotAfter
}

function Check-MSMQInstall ( [String] $Server )
{
	return (Get-WmiObject Win32_Service -ComputerName $Server | where {$_.Name -eq "MSMQ" -and $_.State -eq "Running" }) -ne $nul 
}

function Get-MSMQQueues([String] $Server)
{
	if( check-MSMQInstall -server $Server )
	{
		[void][Reflection.Assembly]::LoadWithPartialName("System.Messaging")
		$msmq = [System.Messaging.MessageQueue]
		
		$msmq::GetPrivateQueuesByMachine($Server) | % {
			Write-Host ($_.QueueName)
		}
		$msmq::GetPublicQueuesByMachine($Server) | % {
			Write-Host ($_.QueueName)
		}
		
	} else 
	{
		Write-Host "MSMQ is either not installed or not running on $Server"
	}
		
}

function Get-FrameworkVersion ([Object] $virtual_dir )
{
	$maps = $virtual_dir | Select ScriptMaps
	$version = $maps.ScriptMaps | Select -Uniq -Expand ScriptProcessor | where { $_.ToLower().Contains("microsoft.net") } | Select -First 1
	
	return $version 
}

function Audit-IISServers([String[]] $Servers )
{
	Set-Variable -Option Constant -Name WebServerQuery -Value "Select * from IIsWebServerSetting"
	Set-Variable -Option Constant -Name VirtualDirectoryQuery -Value "Select * from IISWebVirtualDirSetting"
	Set-Variable -Option Constant -Name AppPoolQuery -Value "Select * from IIsApplicationPoolSetting"
	Set-Variable -Name iisAudit -Value @()
	
	foreach( $server in $Servers ) 
	{ 
		Write-Progress -activity "Querying Server" -status "Currently querying $Server . . . "
		if( ping( $Server ) ) 
		{

			$wmiWebServerSearcher = [WmiSearcher] $WebServerQuery
			$wmiWebServerSearcher.Scope.Path = "\\{0}\root\microsoftiisv2" -f $Server
			$wmiWebServerSearcher.Scope.Options.Authentication = 6
			$iisSettings = $wmiWebServerSearcher.Get()

			$wmiVirtDirSearcher = [WmiSearcher] $VirtualDirectoryQuery
			$wmiVirtDirSearcher.Scope.Path = "\\{0}\root\microsoftiisv2" -f $Server
			$wmiVirtDirSearcher.Scope.Options.Authentication = 6
			$virtDirSettings = $wmiVirtDirSearcher.Get()
	
			$wmiAppPoolSearcher = [WmiSearcher] $AppPoolQuery
			$wmiAppPoolSearcher.Scope.Path = "\\{0}\root\microsoftiisv2" -f $Server
			$wmiAppPoolSearcher.Scope.Options.Authentication = 6
			$appPoolSettings = $wmiAppPoolSearcher.Get()

			$iisSettings | Select Name, ServerComment, LogFileDirectory, ServerBindings | % {
				$audit = New-Object System.Object
				
				$SiteName = $_.Name

				$audit | add-member -type NoteProperty -name ServerName -Value $Server		
				$audit | add-member -type NoteProperty -name Name -Value $_.ServerComment
				$audit | add-member -type NoteProperty -name LogFileDirectory -Value $_.LogFileDirectory
				
				$hostheaders = @()
				$_.ServerBindings | Where {[String]::IsNullorEmpty($_.Hostname) -eq $false } | % {
					$hostheader = New-Object System.Object
					$hostheader | add-member -type NoteProperty -name HostName -Value $_.Hostname		
					$hostheader | add-member -type NoteProperty -name IP -Value $_.IP
					$hostheader | add-member -type NoteProperty -name Port -Value $_.Port
					$hostheaders += $hostheader
				}
				$audit | Add-Member -type NoteProperty -Name HostHeaders -Value $hostheaders
			
				$VirtualDirectories = @()
				$virtDirSettings | where { $_.Name.Contains($SiteName) } | % {
					$VirtualDirectory = New-Object System.Object

					$VirtualDirectory | add-member -type NoteProperty -name Name -Value $_.Name
					$VirtualDirectory | add-member -type NoteProperty -name Path -Value $_.Path
					$VirtualDirectory | add-member -type NoteProperty -name AppFriendlyName -Value $_.AppFriendlyName
					$VirtualDirectory | add-member -type NoteProperty -name AnonymousUserName -Value $_.AnonymousUserName
					$VirtualDirectory | add-member -type NoteProperty -name DefaultDocuments -Value $_.DefaultDoc
					$VirtualDirectory | add-member -type NoteProperty -name AppPoolName -Value $_.AppPoolId
					$VirtualDirectory | add-member -type NoteProperty -name AuthenticationProviders -Value $_.NTAuthenticationProviders
					$VirtualDirectory | add-member -type NoteProperty -Name DotNetFrameworkVersion -Value (Get-FrameworkVersion $_ )

					$AppPoolId = $_.AppPoolId
					$AppPoolAccount = ($appPoolSettings | where { $_.Name.Contains($AppPoolId) } | Select WAMUserName).WAMUserName					
					$VirtualDirectory | add-member -type NoteProperty -name AppPoolAccount -Value $AppPoolAccount 

					$perms = $nul
					if( $_.AccessRead -eq $true ) { $perms += "R" }
					if( $_.AccessWrite -eq $true ) { $perms += "W" }
					if( $_.AccessExecute -eq $true ) { $perms += "E" }
					if( $_.AccessScript -eq $true ) { $perms += "S" }

					$auth = $Nul
					if( $_.AuthAnonymous -eq $true ) { $auth += "Anonymous|" }
					if( $_.AuthNTLM -eq $true ) { $auth += "Integrated|" }
					if( $_.AuthBasic -eq $true ) { $auth += "Basic|" }

					$VirtualDirectory | add-member -type NoteProperty -name AccessPermissions -Value $perms
					$VirtualDirectory | add-member -type NoteProperty -name Authentication -Value $auth.Trim("|")					
					$VirtualDirectories += $VirtualDirectory 
				}
				$audit | add-member -type NoteProperty -name VirtualDirectories -Value $VirtualDirectories
			
				$iisAudit += $audit
			}
		} else 
		{
			Write-Host $_ "appears down. Will not continue with audit"
		}
	}
	
	return $iisAudit
}

function Audit-Server( [String] $server )
{
	$audit = New-Object System.Object
	$computer = Get-WmiObject Win32_ComputerSystem -ComputerName $server
	$os = Get-WmiObject Win32_OperatingSystem -ComputerName $server
	$bios = Get-WmiObject Win32_BIOS -ComputerName $server
	$nics = Get-WmiObject Win32_NetworkAdapterConfiguration -ComputerName $server
	$cpu = Get-WmiObject Win32_Processor -ComputerName $server | select -first 1 -expand MaxClockSpeed
	$disks = Get-WmiObject Win32_LogicalDisk -ComputerName $server
	
	$audit | add-member -type NoteProperty -name SystemName -Value $computer.Name
	$audit | add-member -type NoteProperty -name Domain -Value $computer.Domain		
	$audit | add-member -type NoteProperty -name Model -Value ($computer.Manufacturer + " " + $computer.Model.TrimEnd())
	$audit | add-member -type NoteProperty -name Processor -Value ($computer.NumberOfProcessors.toString() + " x " + ($cpu/1024).toString("#####.#") + " GHz")
	$audit | add-member -type NoteProperty -name Memory -Value ($computer.TotalPhysicalMemory/1gb).tostring("#####.#")
	$audit | add-member -type NoteProperty -name SerialNumber -Value ($bios.SerialNumber.TrimEnd())
	$audit | add-member -type NoteProperty -name OperatingSystem -Value ($os.Caption + " - " + $os.ServicePackMajorVersion.ToString() + "." + $os.ServicePackMinorVersion.ToString())
	
	$localDisks = $disks | where { $_.DriveType -eq 3 } | Select DeviceId, @{Name="FreeSpace";Expression={($_.FreeSpace/1mb).ToString("######.#")}},@{Name="TotalSpace";Expression={($_.Size/1mb).ToString("######.#")}}
	$audit | add-member -type NoteProperty -name Drives -Value $localDisks
	
	$IPAddresses = @()
	$nics | where { -not [string]::IsNullorEmpty($_.IPAddress)  -and $_.IPEnabled -eq $true -and $_.IpAddress -ne "0.0.0.0" } | % { $IPAddresses += $_.IPAddress }
	$audit | add-member -type NoteProperty -name IPAddresses -Value $IPAddresses
	
	$audit | Add-Member -type ScriptMethod -Name toXML -Value $xmlScriptBlock
	$audit | Add-Member -type ScriptMethod -Name toCSV -Value $csvScriptBlock

	return $audit
}

function Audit-Servers([String[]] $Servers, [String] $app, [String] $env)
{
	begin {
		$ErrorActionPreference = "silentlycontinue"
		$serverAudit = @()

	}
	process {
		if ( $_ -ne $null ) { $Servers = $_ }
		$Servers | % { 
			Write-Progress -activity "Querying Server" -status "Currently querying $_ . . . "
			
			$audit = audit-Server $_
			$audit | add-member -type NoteProperty -name Farm -Value $app
			$audit | add-member -type NoteProperty -name Environment -Value $env
			$serverAudit += $audit
		}
	}
	end {
		return $serverAudit | where { $_.SystemName -ne $null }
	}
}

function Create-WindowsService([string[]] $Servers, [string] $Path, [string] $Service, [string] $User, [string] $Pass)
{
	$class = "Win32_Service"
	$method = "Create"
	
	$Servers | % { 
		$mc = [wmiclass]"\\$_\ROOT\CIMV2:$class"
		$inparams = $mc.PSBase.GetMethodParameters($method)
		$inparams.DesktopInteract = $false
		$inparams.DisplayName = $Service
		$inparams.ErrorControl = 0
		$inparams.LoadOrderGroup = $null
		$inparams.LoadOrderGroupDependencies = $null
		$inparams.Name = $Service
		$inparams.PathName = $Path
		$inparams.ServiceDependencies = $null
		$inparams.ServiceType = 16
		$inparams.StartMode = "Automatic"
		
		if( [string]::IsNullOrEmpty( $User ) )
		{
			$inparams.StartName = $null # will start as localsystem builtin if null
			$inparams.StartPassword = $null
		} else 
		{
			$inparams.StartName = $User
			$inparams.StartPassword = $Pass
		}

		$result += $mc.PSBase.InvokeMethod($method,$inparams,$null)
	}
	return( $result | Format-List )
}
	
function sed () 
{
	param (
		[string] $OldText,
		[string] $NewText
	)
	begin {
	}
	process {
		$_ | % { $_.Replace( $OldText, $NewText ) } 
	}
	end {
	}		
}

function Get-DirHash()
{
	begin {
		$ErrorActionPreference = "silentlycontinue"
	}
	process {
		dir -Recurse $_ | where { $_.PsIsContainer -eq $false } | select Name,DirectoryName,@{Name="SHA1 Hash"; Expression={get-hash1 $_.FullName -algorithm "sha1"}}
	}
	end {
	}
}

function Get-LoadedModules() 
{
	begin{
	}
	process {
		$proc = $_
		$procInfo = Get-Process | where { $_.Name.ToLower() -eq $proc.ToLower() }
		$procInfo | Select Name,Modules
	}
	end {
	}
}

function nslookup ( [string] $name )
{
 	$ns = nslookup.exe $name 2>$null

	if( $ns.Length -eq 3 ) {
		return $false
	} else {
		return $ns[$ns.Length - 2].Split(":")[1].TrimStart()
	}
}

## http://poshcode.org/116
function Encrypt-String($String, $Passphrase, $salt="My Voice is my P455W0RD!", $init="Yet another key", [switch]$arrayOutput)
{
   $r = new-Object System.Security.Cryptography.RijndaelManaged
   $pass = [Text.Encoding]::UTF8.GetBytes($Passphrase)
   $salt = [Text.Encoding]::UTF8.GetBytes($salt)

   $r.Key = (new-Object Security.Cryptography.PasswordDeriveBytes $pass, $salt, "SHA1", 5).GetBytes(32) #256/8
   $r.IV = (new-Object Security.Cryptography.SHA1Managed).ComputeHash( [Text.Encoding]::UTF8.GetBytes($init) )[0..15]
   
   $c = $r.CreateEncryptor()
   $ms = new-Object IO.MemoryStream
   $cs = new-Object Security.Cryptography.CryptoStream $ms,$c,"Write"
   $sw = new-Object IO.StreamWriter $cs
   $sw.Write($String)
   $sw.Close()
   $cs.Close()
   $ms.Close()
   $r.Clear()
   [byte[]]$result = $ms.ToArray()
   if($arrayOutput) {
      return $result
   } else {
      return [Convert]::ToBase64String($result)
   }
}

function Decrypt-String($Encrypted, $Passphrase, $salt="My Voice is my P455W0RD!", $init="Yet another key")
{
   if($Encrypted -is [string]){
      $Encrypted = [Convert]::FromBase64String($Encrypted)
   }

   $r = new-Object System.Security.Cryptography.RijndaelManaged
   $pass = [System.Text.Encoding]::UTF8.GetBytes($Passphrase)
   $salt = [System.Text.Encoding]::UTF8.GetBytes($salt)

   $r.Key = (new-Object Security.Cryptography.PasswordDeriveBytes $pass, $salt, "SHA1", 5).GetBytes(32) #256/8
   $r.IV = (new-Object Security.Cryptography.SHA1Managed).ComputeHash( [Text.Encoding]::UTF8.GetBytes($init) )[0..15]

   $d = $r.CreateDecryptor()
   $ms = new-Object IO.MemoryStream @(,$Encrypted)
   $cs = new-Object Security.Cryptography.CryptoStream $ms,$d,"Read"
   $sr = new-Object IO.StreamReader $cs
   Write-Output $sr.ReadToEnd()
   $sr.Close()
   $cs.Close()
   $ms.Close()
   $r.Clear()
}

function Encode-String( $strEncode ) 
{
	[convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($strEncode))
}

function Decode-String( $strDecode )
{
	[Text.Encoding]::Unicode.GetString([convert]::FromBase64String($strDecode))
}

function Compare-HashTable ( [HashTable] $src, [HashTable] $dst,[Object] $head  )
{
	$src.Keys | % { 
		if( ($dst.($_) -ne $null ) -and ($src.($_).GetType().Name -eq "HashTable" -and  $dst.($_).GetType().Name -eq "HashTable" ) ) {
			Compare-HashTable -src $src.($_) -dst $dst.($_) -head $_
		} else {
			if( $dst.Contains($_) ) {
				if( $src.($_) -ne $dst.($_) ) {
					Write-Host "`t$head - $_ differs " -foregroundcolor Green
				}
			} else {
				Write-Host "`t$head -  $_ is not contained in destination" -foregroundcolor DarkGray
			}
		}
	}
}

function Ping-Multiple 
{
	begin {
		$replies = @()
		$timeout=1000
		$ping = new-object System.Net.NetworkInformation.Ping 
	}
	process {
		trap { continue }
			
		$reply = $ping.Send($_ , $timeout)
		$status = New-Object PSObject -Property @{
			Time 		= $reply.RoundtripTime
			Status 		= $reply.Status
			Address 	= $reply.Address
			Server	 	= $_	
		}
		
		$replies += $status
	}
	end {
		return ( $replies  )
	}
}

function ping ( [string] $computer ) 
{
	$timeout=120
	$ping = new-object System.Net.NetworkInformation.Ping 

	trap { continue }

	$reply = $ping.Send($computer, $timeout)
   	if( $reply.Status -eq "Success"  ) {
	    return $true
	} else {
		return $false
	}  
}

Function Read-RegistryHive 
{
	param(
		[string[]] $servers,
		[string] $key,
		[string] $rootHive = "LocalMachine"
	)
	
	$regPairs = @()
	$servers | % {
		$server = $_
		if( Ping $server )
		{
			$hive = [Microsoft.Win32.RegistryHive]::$rootHive
			$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($hive, $server )
			$regKey = $reg.OpenSubKey($key)
			$regKey.GetValueNames() | % { 
				$regPair = new-object System.Object
				$regPair | add-member -type NoteProperty -name Server -value $server
				$regPair | add-member -type NoteProperty -name Key -value "$key\$_"
				$regPair | add-member -type NoteProperty -name Value -value $regKey.GetValue($_.ToString())
				$regPairs += $regPair
			}
			
			$regKey.GetSubKeyNames() | % {
				$regPairs += read-RegistryHive -servers $server -key "$key\$_"
			}
		} else 
		{
			Write-Host "Could not ping $_ . . ." -foregroundcolor DarkRed
		}
	
	}
	return $regPairs
}

function Send-Email($s,$b,$to) 
{
	$mail = new-object System.Net.Mail.MailMessage;
	
	for($i=0; $i -lt $to.Length; $i++) {
		$mail.To.Add($to[$i]);
	}
	$mail.From = new-object System.Net.Mail.MailAddress($from);

	$mail.Subject = $s;
	$mail.Body = $b;

	$smtp = new-object System.Net.Mail.SmtpClient($domain);
	$smtp.Send($mail);

}

function Send-EmailWithAttachment( [string] $subject, [string] $body, [object] $to, [Object] $attachment  )
{	
	$mail = new-object System.Net.Mail.MailMessage
	
	for($i=0; $i -lt $to.Length; $i++) {
		$mail.To.Add($to[$i]);
	}

	$mail.From = new-object System.Net.Mail.MailAddress($from)
	$mail.Subject = $subject
	$mail.Body = $body
	
	$attach = New-Object System.Net.Mail.Attachment($attachment)
	$mail.Attachments.Add($attach)

	$smtp = new-object System.Net.Mail.SmtpClient($domain)
	$smtp.Send($mail)

	$attach.Dispose()
	$mail.Dispose()
}

function log( [string] $txt, [string] $log ) 
{
	"[" + (Get-Date).ToString() + "] - " + $txt | Out-File $log -Append -Encoding ASCII 
}

function Get-Hash1 
{
	param(
		[string] $file = $(throw 'a filename is required'),
	    [string] $algorithm = 'sha256'
	)

	$fileStream = [system.io.file]::openread($file)
	#$fileStream = [system.io.file]::openread((resolve-path $file))
	$hasher = [System.Security.Cryptography.HashAlgorithm]::create($algorithm)
	$hash = $hasher.ComputeHash($fileStream)
	$fileStream.Close()
	
	return ( ([system.bitconverter]::tostring($hash)).Replace("-","") )
}

function Get-FileVersion() 
{
	begin{
		$info = @()
	}
	process {

		if( test-path $_ ) {
   	     		$info += [system.diagnostics.fileversioninfo]::GetVersionInfo($_)
		} else {
			throw "Invalid Path - $_"
		}
	}
	end {
		return $info
	}
}

function Get-Tail([string]$path = $(throw "Path name must be specified."), [int]$count = 10)
{
	if ( $count -lt 1 ) {$(throw "Count must be greater than 1.")}

	$content = Get-Content $path
	
	if( $content.Length -le $count )
	{
		return $content
	}
	
	$start = $content.Length - $count
	for ($i = $start; $i -lt $content.Length; $i++)
  	{
  		$content[$i];
  	}
}

function Get-TailByBytes([string]$path = $(throw "Path name must be specified."), [int]$bytes)
{
	$tail = @()

	if ( $bytes -lt 1 ) {$(throw "Bytes must be greater than 1.")}

	$reader = new-object -typename System.IO.StreamReader -argumentlist $path, $true
	[long]$end = $reader.BaseStream.Length - 1
	[long]$cur = $end - $bytes - 100

	$reader.BaseStream.Position = $cur
	while(-not ($reader.EndofStream) )
	{
		$tail += $reader.ReadLine()
	} 
	
	$reader.Close()

	return $tail
}

function Get-FileSize ( [string] $path ) 
{
	$reader = new-object System.IO.FileStream $path, ([io.filemode]::Open), ([io.fileaccess]::Read), ([io.fileshare]::ReadWrite)
	$len = $reader.Length
	$reader.Close()
	return $len
}

function  flatten( [string[]] $txt, [string] $startString)
{
	$rtnVal=@()
	$tmp=""
	$txt | % {
		if( $_ -match $startString) { 
			$rtnVal += $tmp
			$tmp = $_ 
		} else {
			$tmp += $_ 
		}	
	}
	$rtnVal += $tmp
	return $rtnVal
}

function Query-DatabaseTable ( [string] $server , [string] $dbs, [string] $sql )
{
	$Columns = @()
	
	$con = "server=$server;Integrated Security=true;Initial Catalog=$dbs"
	
	$ds = new-object "System.Data.DataSet" "DataSet"
	$da = new-object "System.Data.SqlClient.SqlDataAdapter" ($con)
	
	$da.SelectCommand.CommandText = $sql 
	$da.SelectCommand.Connection = $con
	
	$da.Fill($ds) | out-null
	$ds.Tables[0].Columns | Select ColumnName | % { $Columns += $_.ColumnName }
	$res = $ds.Tables[0].Rows  | Select $Columns
	
	$ds.Clear()
	$da.Dispose()
	$ds.Dispose()

	return $res
}

function BulkWrite-ToSQLDatabase([Object] $table) 
{
    $bulkCopy = [Data.SqlClient.SqlBulkCopy] $ConnectionString
    $bulkCopy.DestinationTableName = $TableName
    $bulkCopy.WriteToServer($table)		
}

function Is-64Bit() 
{    
	if ([IntPtr].Size -eq 4) 
	{ 
		return $false 
	}    
	else 
	{ 
		return $true 
	}
}