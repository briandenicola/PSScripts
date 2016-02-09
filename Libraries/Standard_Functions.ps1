#Variables
[void] [Reflection.Assembly]::LoadWithPartialName("System.Security")

$domain_controller = ""
$from = ""
$domain  = ""

$AutoUpdateNotificationLevels= @{0="Not configured"; 1="Disabled" ; 2="Notify before download"; 3="Notify before installation"; 4="Scheduled installation"}
$AutoUpdateDays=@{0="Every Day"; 1="Every Sunday"; 2="Every Monday"; 3="Every Tuesday"; 4="Every Wednesday";5="Every Thursday"; 6="Every Friday"; 7="EverySaturday"}

function Get-Fonts
{
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
    $objFonts = New-Object System.Drawing.Text.InstalledFontCollection
    return $objFonts.Families
}

function Update-PathVariable 
{
	param(	
		[Parameter(Mandatory=$true)]
	    [ValidateScript({Test-Path $_})]
		[string] $Path,
		
		[Parameter(Mandatory=$false)]
		[ValidateSet("User","Machine")] 
		[string] $Target = "User" 
	)

	$current_path = [Environment]::GetEnvironmentVariable( "Path", $Target )
	
	Write-Verbose -Message ("[Update-PathVariable] - Current Path Value: {0}" -f $current_path )
	
	$current_path = $current_path.Split(";") + $Path
	$new_path = [string]::Join( ";", $current_path)
	
	Write-Verbose -Message ("[Update-PathVariable] - New Path Value: {0}" -f $new_path)
	[Environment]::SetEnvironmentVariable( "Path", $new_path, $Target )
}

function Get-GacAssembly 
{
	param(		
		[Parameter(Mandatory=$false)]
		[ValidateSet("v2.0","v4.0")]
		[string] $TargetFramework = "v2.0|v4.0"
	)

	function Get-Architecture 
	{
		param( [string] $Path )
		if( $Path -imatch "_64"   ) { return "AMD64" }
		if( $Path -imatch "_MSIL" ) { return "MSIL"  }
		return "x86"
	}

	$gac_locations = @(
		@{ "Path" = "C:\Windows\assembly";               "Version" = "v2.0" },
		@{ "Path" = "C:\Windows\Microsoft.NET\assembly"; "Version" = "v4.0" }
	)

	Set-Variable -Name assemblies -Value @()
	
	foreach( $location in ($gac_locations | Where Version -imatch $TargetFramework) ) {
		$framework = $location.Version 
		foreach( $assembly in (Get-ChildItem -Path $location.Path -Include "*.dll" -Recurse) ) {
			$public_key = $assembly.Directory.Name.Split("_") | Select -Last 1
		
			$properties = [ordered] @{
				Name         = $assembly.BaseName
				Version      = $assembly.VersionInfo.ProductVersion
 				PublicKey    = $public_key
				LastModified = $assembly.LastWriteTime
				Framework    = $framework
				Architecture = Get-Architecture -Path $assembly.FullName 
			}
		
			$assemblies += (New-Object PSObject -Property $properties)
		} 
	}
	
	return $assemblies
}

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
    [CmdletBinding()] 
	param (
		[Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] 
		[string]$Path
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
    Get-WindowsFeature | Where { $_.Name -match "MSMQ" } | Foreach { Add-WindowsFeature $_.Name }
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
       
    if( -not [String]::IsNullorEmpty($Server) ) {
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
	catch [System.Net.WebException] {
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
 	param(
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
	param(
		[string] $computer
	)
	
	$uptime_template = "System ({0}) has been online since : {1} days {2} hours {3} minutes {4} seconds"
	$lastboottime = (Get-WmiObject -Class Win32_OperatingSystem -computername $computer).LastBootUpTime
	$sysuptime = (Get-Date) - [System.Management.ManagementDateTimeconverter]::ToDateTime($lastboottime)
	
	$uptime = $uptime_template -f $computer, $sysuptime.days, $sysuptime.hours, $sysuptime.minutes, $sysuptime.seconds
	
	return $uptime
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
	
	foreach( $task in ($tasks_com_connector.GetFolder("\").GetTasks(0) | Select Name, LastRunTime, LastTaskResult, NextRunTime, XML )) {
	
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

function Get-PreviousMonth
{
	return (New-Object PSObject -Property @{ 
		last_month_begin = $(Get-Date -Day 1).AddMonths(-1)
		last_month_end =   $(Get-Date -Day 1).AddMonths(-1).AddMonths(1).AddDays(-1)
	})
}

function Get-PerformanceCounters
{
	param (
		[String[]] $counters = @("\processor(_total)\% processor time","\physicaldisk(_total)\% disk time","\memory\% committed bytes in use","\physicaldisk(_total)\current disk queue length"),
		[String[]] $computers,
		[int] $samples = 10,
		[int] $interval = 10		
	)
	
	Get-Counter $counters -ComputerName $computers -MaxSamples $samples -SampleInterval $interval |
		Foreach { $t=$_.TimeStamp; $_.CounterSamples } | 
		Select @{Name="Time";Expression={$t}},Path,CookedValue 
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

function Create-SQLAlias
{
	param( 
		[string] $instance, 
		[int]    $port, 
		[string] $alias
	)
	
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

	$AUObj = New-Object -TypeName PSObject -Property @{
		NotificationLevel  = $AutoUpdateNotificationLevels[$AUSettings.NotificationLevel]
		UpdateDays         = $AutoUpdateDays[$AUSettings.ScheduledInstallationDay]
		UpdateHour         = $AUSettings.ScheduledInstallationTime 
		RecommendedUpdates = $(IF ($AUSettings.IncludeRecommendedUpdates) {"Included."}  else {"Excluded."})
	}
	return $AuObj
} 

function Get-LocalAdmins
{
	param ( [string] $computer )
	$adsi  = [ADSI]("WinNT://" + $computer + ",computer") 
	$Group = $adsi.psbase.children.find("Administrators") 
	$members = $Group.psbase.invoke("Members") | %{$_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)} 
	
	return $members
}

function Get-LocalGroup
{
	param ( [string] $computer,[string] $Group )
	$adsi  = [ADSI]("WinNT://" + $computer + ",computer") 
	$adGroup = $adsi.psbase.children.find($group) 
	$members = $adGroup.psbase.invoke("Members") | %{$_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)} 
	
	return $members
}

function Add-ToLocalGroup
{
	param ( [string] $computer, [string] $LocalGroup, [string] $DomainGroup )
    $aslocalGroup = [ADSI]"WinNT://$computer/$LocalGroup,group"
    $aslocalGroup.Add("WinNT://$domain_controller/$DomainGroup,group")
}

function Add-LocalAdmins
{
	param ( [string] $computer, [string] $Group )
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

function Convert-ObjectToHash
{
	param ( 
		[Object] $obj
	)
	
	$ht = @{}
	$Keys = $obj | Get-Member -MemberType NoteProperty | Select -Expand Name

	foreach( $key in $Keys ) { 
		if( $obj.$key -is [System.Array] ) { 
			$value = [String]::Join(" | ", $obj.$key )
		} else {
			$value = $obj.$key
		}
		$ht.Add( $Key, $Value )
	}

	return $ht
}

function Get-RunningServices
{
	param( [string] $computer )
	gwmi Win32_Service -computer $Computer | Where { $_.State -eq "Running" } | Select Name, PathName, Id, StartMode  
}

function Get-IntermediateCerts
{
	Get-ChildItem -path cert:\LocalMachine\CA | Select Subject, Issuer, NotAfter | sort NotAfter
}

function Get-InstalledCerts
{
	Get-ChildItem -path cert:\LocalMachine\My | Select FriendlyName, Issuer, NotAfter, HasPrivateKey | sort NotAfter
}

function Check-MSMQInstall 
{
	param( [string] $Server )
	return (Get-WmiObject Win32_Service -ComputerName $Server | where {$_.Name -eq "MSMQ" -and $_.State -eq "Running" }) -ne $nul 
}

function Get-MSMQQueues 
{	
	param( [string] $Server )
	
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

function Audit-Server
{
	param( [string] $server )
	
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

function Create-WindowsService
{
	param(
		[string[]] $Servers, 
		[string]   $Path, 
		[string]   $Service,
		[string]   $User,
		[string]   $Pass
	)
	
	$class = "Win32_Service"
	$method = "Create"
	
	$result = @()
	foreach( $server in $Servers ) { 
		$mc = [wmiclass]"\\$server\ROOT\CIMV2:$class"
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
	
function Get-DirHash
{
	param(
		[Parameter(Mandatory=$false, ValueFromPipeline=$True)]
	    [ValidateScript({Test-Path $_})]
		[string] $Directory = $PWD.Path 
	)
	begin {
		$ErrorActionPreference = "silentlycontinue"
		$hashes = @()
	}
	process {
		$hashes = Get-ChildItem -Recurse -Path $Directory | 
			Where { $_.PsIsContainer -eq $false } | 
			Select Name, DirectoryName, @{Name="SHA1 Hash"; Expression={Get-Hash1 $_.FullName -algorithm "sha1"}}
	}
	end {
		return $hashes 
	}
}

function Get-LoadedModules
{
	param(
		[Parameter(Mandatory=$false, ValueFromPipeline=$True)]
		[string] $proc
	)
	begin{
		$modules = @()		
	}
	process {
		$procInfo = Get-Process | Where { $_.Name.ToLower() -eq $proc.ToLower() }
		$modules = $procInfo | Select Name, Modules
	}
	end {
		return $modules 
	}
}

function Get-IPAddress 
{
	param ( [string] $name )
 	return ( try { [System.Net.Dns]::GetHostAddresses($name) | Select -Expand IPAddressToString } catch {} )
}

function Encode-String 
{
	param( [string] $strEncode )
	[convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($strEncode))
}

function Decode-String
{
	param( [string] $strDecode )
	[Text.Encoding]::Unicode.GetString([convert]::FromBase64String($strDecode))
}

function Ping-Multiple 
{
	param(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
		[string] $ComputerName
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
		return $replies
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
		if( Test-Connection -Computername $server -Count 1 ) {
			$hive = [Microsoft.Win32.RegistryHive]::$rootHive
			$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($hive, $server )
			$regKey = $reg.OpenSubKey($key)
			foreach( $regValue in $regKey.GetValueNames() ) { 
				$regPairs += (New-Object PSObject -Property @{
					Server = $server
					Key    = $key + "\" + $regValue
					Value  = $regKey.GetValue($_.ToString())
				})
			}
			foreach( $regSubKey in $regKey.GetSubKeyNames() ) {
				$regPairs += Read-RegistryHive -Servers $server -Key "$key\$regSubKey"
			}
		} 
        else  {
			Write-Error -Message ("Could not ping {0} . . ." -f $server)
		}
	
	}
	return $regPairs
}

function Send-Email
{
	param(
		[Alias('s')][string]  $Subject,
		[Alias('b')][string]  $Body,
		[string[]] 			  $To
	) 
	$mail = New-Object System.Net.Mail.MailMessage
	
	for($i=0; $i -lt $to.Length; $i++) {
		$mail.To.Add($to[$i]);
	}
	$mail.From = New-Object System.Net.Mail.MailAddress($from)

	$mail.Subject = $subject
	$mail.Body = $body

	$smtp = New-Object System.Net.Mail.SmtpClient($domain)
	$smtp.Send($mail)
	
	$mail.Dispose()
}

function log
{
	param ( [string] $txt, [string] $log ) 
	Out-File -FilePath $log -Append -Encoding ASCII -InputObject ("[{0}] - {1}" -f $(Get-Date).ToString(), $txt )
}

function Get-Hash1 
{
	param(
		[string] $file = $(throw 'a filename is required'),
	    [string] $algorithm = 'sha256'
	)

	$fileStream = [system.io.file]::openread($file)
	$hasher = [System.Security.Cryptography.HashAlgorithm]::create($algorithm)
	$hash = $hasher.ComputeHash($fileStream)
	$fileStream.Close()
	
	return ( ([system.bitconverter]::tostring($hash)).Replace("-","") )
}

function Get-FileVersion
{
	param(
		[Parameter(Mandatory=$false, ValueFromPipeline=$True)]
	    [ValidateScript({Test-Path $_})]
		[string] $FilePath
	)
	begin{
		$info = @()
	}
	process {
        $info += [system.diagnostics.fileversioninfo]::GetVersionInfo($FilePath)
	}
	end {
		return $info
	}
}

function Get-Tail
{
    param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$True)]
	    [ValidateScript({Test-Path $_})]
		[Alias('path')]
        [string] $FilePath,
		
        [int] $count = 10,
		
        [Alias("f")]
        [switch] $wait
    )
    Get-Content -Path $FilePath -Tail $count -Wait:$wait
}
Set-Alias -Name Tail -Value Get-Tail

function Get-FileSize  
{
	param ( [string] $path )
	$reader = New-Object System.IO.FileStream $path, ([io.filemode]::Open), ([io.fileaccess]::Read), ([io.fileshare]::ReadWrite)
	$len = $reader.Length
	$reader.Close()
	return $len
}

function Query-DatabaseTable 
{
	param (
		[string] $server, 
		[string] $dbs, 
		[string] $sql
	)
	
	$Columns = @()
	$con = "server={0};Integrated Security=true;Initial Catalog={1}" -f $server, $dbs
	
	$ds = New-Object "System.Data.DataSet" "DataSet"
	$da = New-Object "System.Data.SqlClient.SqlDataAdapter" ($con)
	
	$da.SelectCommand.CommandText = $sql 
	$da.SelectCommand.Connection = $con
	
	$da.Fill($ds) | out-null
	$ds.Tables[0].Columns | Select ColumnName | Foreach { $Columns += $_.ColumnName }
	$res = $ds.Tables[0].Rows  | Select $Columns
	
	$ds.Clear()
	$da.Dispose()
	$ds.Dispose()

	return $res
}

function Is-64Bit
{   
	return ( [IntPtr]::Size -eq 8 ) 
}