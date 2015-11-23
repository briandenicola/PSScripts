#Variables
[void] [Reflection.Assembly]::LoadWithPartialName("System.Security")

$domain_controller = "ad.sharepoint.test"
$from = "admin@sharepoint.test"
$domain  = "mail.sharepoint.test"

$AutoUpdateNotificationLevels= @{0="Not configured"; 1="Disabled" ; 2="Notify before download"; 3="Notify before installation"; 4="Scheduled installation"}
$AutoUpdateDays=@{0="Every Day"; 1="Every Sunday"; 2="Every Monday"; 3="Every Tuesday"; 4="Every Wednesday";5="Every Thursday"; 6="Every Friday"; 7="EverySaturday"}

function Load-AzureModules
{

    if (-not(Get-Module -Name Azure) ) {
        . (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Azure_Functions.ps1")
    }
}

function New-PSCredentials
{
    param(
        [string] $UserName,
        [string] $Password
    )

    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    return ( New-Object System.Management.Automation.PSCredential ($UserName, $SecurePassword) )
}

function Check-ServerAccess
{
    param(
        [string] $computer
    )

    Get-WmiObject -Query "Select Name from Win32_ComputerSystem" -ComputerName $computer -ErrorAction SilentlyContinue | Out-Null
    return $? 
}

function Create-DBConnectionString 
{
    param(
         [Parameter(Mandatory = $True)][string]$sql_instance,
         [Parameter(Mandatory = $True)][string]$database,

         [Parameter(Mandatory = $False, ParameterSetName="Integrated")][switch] $integrated_authentication,
         [Parameter(Mandatory = $true, ParameterSetName="SQL")][string]$user = [string]::empty,
         [Parameter(Mandatory = $true, ParameterSetName="SQL")][string]$password = [string]::empty
    )
    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder['Data Source'] = $sql_instance
    $builder['Initial Catalog'] = $database

    if( $integrated_authentication )  { 
        $builder['Integrated Security'] = $true
    }
    else { 
        $builder['User ID'] = $user
        $builder['Password'] = $password
    }

    return $builder.ConnectionString
}

function Get-BitlyLink
{
    param(
        [Parameter(Mandatory = $True)][string] $url,
        [switch] $copy_to_clipboard
    )
    
    Set-Variable -Name access_token -Value "" -Option Constant
    $link = [string]::Format( "https://api-ssl.bitly.com/v3/user/link_save?access_token={0}&longUrl={1}", $access_token,  [system.web.httputility]::urlencode($url) )

    $result = Invoke-RestMethod -Method Get -Uri $link

    if( $result.status_code -ne 200 ) {
        throw ("Erorr Occured - " + $result.status_txt )
    }
    
    if( $copy_to_clipboard ) { 
        $result.data.link_save.link | Set-Clipboard
    }

    return $result.data.link_save.link 
}

function Get-RemoteDesktopSessions
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [string[]] $computers
    )
     
    begin {
        $users = @()
        $filter = "name='explorer.exe'"
    }
    process {
        foreach( $computer in $computers ) {
            foreach( $process in (Get-WmiObject -ComputerName $computer -Class Win32_Process -Filter $filter ) ) {
                $users += (New-Object PSObject -Property @{
                    Computer = $computer
                    User = $process.getOwner() | Select -Expand User
                })                     
            }
        }
    }
    end {
        return $users
    }
}

function LogOff-Computer 
{
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [string[]] $computer,
        [switch] $forced
    )
     
    begin {
        $log_off = 0
    }
    process {
        if( $forced ) {
            $log_off = 4
        }

        foreach( $computer in $computers) {
            Write-Verbose "Logging off $computer "
            (Get-WMIObject -class Win32_OperatingSystem -Computername $computer).Win32Shutdown($log_off) | Out-Null
        }
    }
    end {
    }
}

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

function Get-Installed-DotNet-Versions 
{
    $path = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP'

    return (
        Get-ChildItem $path -recurse | 
        Get-ItemProperty -Name Version  -ErrorAction SilentlyContinue | 
        Select  -Unique -Expand Version
    )
}

function Get-DetailedServices 
{
    param(
        [string] $ComputerName = $ENV:COMPUTERNAME,
        [string] $state = "running"
    )
    
    $services = @()

    $processes = Get-WmiObject Win32_process -ComputerName $ComputerName
    foreach( $service in (Get-WmiObject -ComputerName $ComputerName -Class Win32_Service -Filter ("State='{0}'" -f $state ) )  ) {
        
        $process = $processes | Where { $_.ProcessId -eq $service.ProcessId }
    
        $services += (New-Object PSObject -Property @{
            Name = $service.Name
            DisplayName = $service.DisplayName
            User = $process.getOwner().user
            CommandLine = $process.CommandLine
            PID = $process.ProcessId
            Memory = [math]::Round( $process.WorkingSetSize / 1mb, 2 )
        })    

    }

    return $Services
}

#http://poshcode.org/2059
function Get-FileEncoding
{
    [CmdletBinding()] Param (
     [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [string]$Path
    )

    [byte[]]$byte = get-content -Encoding byte -ReadCount 4 -TotalCount 4 -Path $Path

    if ( $byte[0] -eq 0xef -and $byte[1] -eq 0xbb -and $byte[2] -eq 0xbf ) {
         Write-Output 'UTF8' 
    } 
    elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff) {
        Write-Output 'Unicode' 
    }
    elseif ($byte[0] -eq 0 -and $byte[1] -eq 0 -and $byte[2] -eq 0xfe -and $byte[3] -eq 0xff) {
        Write-Output 'UTF32' 
    }
    elseif ($byte[0] -eq 0x2b -and $byte[1] -eq 0x2f -and $byte[2] -eq 0x76) {
        Write-Output 'UTF7'
    }
    else { 
        Write-Output 'ASCII' 
    }

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
    Write-Verbose -Message ("IE Enhanced Security Configuration (ESC) has been disabled.")
}

function Enable-InternetExplorerESC 
{
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 1
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 1
    Stop-Process -Name Explorer
    Write-Verbose -Message ("IE Enhanced Security Configuration (ESC) has been enabled.")
}

function Disable-UserAccessControl
{
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 00000000
    Write-Verbose -Message ("User Access Control (UAC) has been disabled.")
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
	
	return ("System ({0}) has been online since : {1} days {2} hours {3} minutes {4} seconds" -f $computer, $sysuptime.days, $sysuptime.hours, $sysuptime.minutes, $sysuptime.seconds)
}

function Get-CpuLoad 
{
    param(
        [string] $ComputerName = $ENV:COMPUTERNAME,
        [int]    $Refresh      = 5
    )

    $query = "select * from Win32_PerfRawData_PerfProc_Process"
    $filter = " where Name = `"{0}`""

    Clear-Host

    while(1) {
                
        $system_utilization = @()
        $all_running_processes = Get-WmiObject -Query $query -ComputerName $ComputerName
        
        Start-Sleep -Milliseconds 500
        
        foreach( $process in $all_running_processes ) {
            $process_utlization_delta = Get-WmiObject -Query ($query + $Filter -f $process.Name) -ComputerName $ComputerName
            $cpu_utilization = [math]::Round((($process_utlization_delta.PercentProcessorTime - $process.PercentProcessorTime)/($process_utlization_delta.Timestamp_Sys100NS - $process.Timestamp_Sys100NS)) * 100,2)
        
            $system_utilization += (New-Object psobject -Property @{
                ComputerName   = $ComputerName
                ProcessName    = $process.Name
                PID            = $process.IDProcess
                ThreadCount    = $process.ThreadCount
                PercentageCPU  = $cpu_utilization
                WorkingSetKB  = $process.WorkingSetPrivate/1kb
            })
        }
        Clear-Host
        $system_utilization | Sort-Object -Property PercentageCPU -Descending | Select -First 10 | Format-Table -AutoSize
        Start-Sleep -Seconds $Refresh
    }
}

function Get-ScheduledTasks
{
    param(
        [string] $ComputerName
    )

	$tasks = @()
	
	$tasks_com_connector = New-Object -ComObject("Schedule.Service")
	$tasks_com_connector.Connect($ComputerName)
	foreach( $task in ($tasks_com_connector.getFolder("\").GetTasks(0) | Select Name, LastRunTime, LastTaskResult, NextRunTime, XML )) {
	
		$xml = [xml] ( $task.XML )
		
		$tasks += (New-Object PSObject -Property @{
			HostName = $ComputerName
			Name = $task.Name
			LastRunTime = $task.LastRunTime
			LastResult = $task.LastTaskResult
			NextRunTime = $task.NextRunTime
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
    
	$pfx = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2    
   
    if ($pfxPass -eq $null) {
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
 
    if ($pfxPass -eq $null) {
		$pfxPass = Read-Host "Enter the pfx password" -assecurestring
	}
	
	$bytes = $cert.export($type, $pfxPass)
	[System.IO.File]::WriteAllBytes($file , $bytes)
}

function pause
{
	#From http://www.microsoft.com/technet/scriptcenter/resources/pstips/jan08/pstip0118.mspx
	Write-Output "Press any key to exit..."
	$null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Get-PreviousMonthRange
{
	$Object = New-Object PSObject -Property @{ 
		last_month_begin = $(Get-Date -Day 1).AddMonths(-1)
		last_month_end =   $(Get-Date -Day 1).AddMonths(-1).AddMonths(1).AddDays(-1)
	}
	
	return $Object
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

	if($key) {
		$secure_string = ConvertTo-SecureString $password -Key $key
	}
	else {
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

function Create-SQLAlias( [string] $instance, [int] $port, [string] $alias )
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
	$sb = {
		$assemblies = @()
		$util = "D:\Utils\gacutil.exe"
		
		if( Test-Path $util ) {
			foreach( $dll in (&$util /l | where { $_ -imatch "culture" } | Sort) ) {
				$dll -imatch "(\w+),\sVersion=(.*),\sCulture=(.*),\sPublicKeyToken=(.*),\sprocessorArchitecture=(.*)" | Out-Null				
				$assemblies += (New-Object PSObject -Property @{	
					DllName = $matches[1]
					Version = $matches[2]
					PublicKeyToken = $matches[3]
					Architecture = $matches[4]
				})
			}
		}
		else {
			throw "Could not find gacutil.exe"
		}
		
		return $assemblies
	}
	
	if( $servers -imatch $ENV:COMPUTERNAME ) {
		return &$sb
	}
	else {
		return ( Invoke-Command -Computer $servers -ScriptBlock $sb )
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
	
    $DownLoadFile = Join-Path -Path $ENV:TEMP -ChildPath $file 
    $webClient = New-Object System.Net.WebClient 
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

function Get-MSMQQueues ( [String] $Server )
{
	$queues = @()
	if( Check-MSMQInstall -server $Server )	{
		[void][Reflection.Assembly]::LoadWithPartialName("System.Messaging")
		$msmq = [System.Messaging.MessageQueue]
		
		foreach( $private in $msmq::GetPrivateQueuesByMachine($Server) ) {
			$queues += (New-Object PSObject -Property @{
				Name = $private.QueueName
				Type = "Private"
			})
		}
		
		foreach( $public in $msmq::GetPublicQueuesByMachine($Server) ) {
			$queues += (New-Object PSObject -Property @{
				Name = $public.QueueName
				Type = "Public"
			})
		}
	} 
	else {
		Write-Error -Message ("MSMQ is either not installed or not running on $Server")
	}
		
	return $queues
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
		
		if( [string]::IsNullOrEmpty( $User ) ) {
			$inparams.StartName = $null # will start as localsystem builtin if null
			$inparams.StartPassword = $null
		} 
		else {
			$inparams.StartName = $User
			$inparams.StartPassword = $Pass
		}

		$result += $mc.PSBase.InvokeMethod($method,$inparams,$null)
	}
	return $result 
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

function Get-IPAddress ( [string] $name )
{
 	return ( try { [System.Net.Dns]::GetHostAddresses($name) | Select -Expand IPAddressToString } catch {} )
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
	param(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)][string] $ComputerName
	)
	begin {
		$replies  = @()
		$timeout  = 1000
		$ping     = New-Object System.Net.NetworkInformation.Ping 
	}
	process {
		trap { continue }
			
		$reply = $ping.Send($ComputerName , $timeout)
		$replies += (New-Object PSObject -Property @{
			ComputerName	 	= $ComputerName	
			Address 			= $reply.Address
			Time 				= $reply.RoundtripTime
			Status 				= $reply.Status
		})
	}
	end {
		return ( $replies  )
	}
}

function Read-RegistryHive 
{
	param(
		[string[]] $servers,
		[string] $key,
		[string] $rootHive = "LocalMachine"
	)
	
	$regPairs = @()
	foreach( $server in $servers ) {
		if( ping $server ) {
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
		} 
        else  {
			Write-Error -Message ("Could not ping " + $server + " . . .")
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

function Get-Tail
{
    param(
        [string] $path = $(throw "Path name must be specified."),
        [int] $count = 10,
        [Alias("f")]
        [switch] $wait
    )

    try { 
        Get-Content $path -Tail $count -Wait:$wait
    }
    catch { 
        throw "An error occur - $_ "
    }

}
Set-Alias -Name Tail -Value Get-Tail

function Get-FileSize ( [string] $path ) 
{
	$reader = new-object System.IO.FileStream $path, ([io.filemode]::Open), ([io.fileaccess]::Read), ([io.fileshare]::ReadWrite)
	$len = $reader.Length
	$reader.Close()
	return $len
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

function Is-64Bit() 
{   
	return ( [IntPtr]::Size -eq 8 ) 
}