### Brian Denicola
### brian.x.denicola@jpmchase.com
### 

function New-PSWindow { Invoke-item "$pshome\powershell.exe" }

function Get-TopProcesses
{
	Get-WmiObject Win32_PerfFormattedData_PerfProc_Process | `
  		where-object{ $_.Name -ne "_Total" -and $_.Name -ne "Idle"} | `
  		Sort-Object PercentProcessorTime -Descending | `
  		select -First 5 | `
  		Format-Table Name,IDProcess,PercentProcessorTime -AutoSize
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

	if( [System.Environment]::OsVersion.ToString().StartsWith(5) ) 
	{
 		$cert = Get-ChildItem -path cert:\$certRootStore\$certStore | where { $_.FriendlyName.ToLower().Contains($subject) }
	}
	else
	{
		$cert = Get-ChildItem -path cert:\$certRootStore\$certStore | where { $_.Subject.ToLower().Contains($subject) }
	}

	$store = new-object System.Security.Cryptography.X509Certificates.X509Store($certStore,$certRootStore)
	
	$store.Open("ReadWrite")
	$store.Remove($cert)
	$store.Close()
	
}

# ===================================================================================
# Func: Pause
# Desc: Wait for user to press a key - normally used after an error has occured
# ===================================================================================mmc
Function Pause
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
		[String] $password
	)

	$secure_string = ConvertTo-SecureString $password
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

### http://www.databasejournal.com/img/2007/11/CreateServerAlias_ps1.txh
function Create-SQL2K5Alias( [string] $instance, [int] $port, [string] $alias)
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

$AutoUpdateNotificationLevels= @{0="Not configured"; 1="Disabled" ; 2="Notify before download"; 3="Notify before installation"; 4="Scheduled installation"}
$AutoUpdateDays=@{0="Every Day"; 1="Every Sunday"; 2="Every Monday"; 3="Every Tuesday"; 4="Every Wednesday";5="Every Thursday"; 6="Every Friday"; 7="EverySaturday"}
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
	#$PSEXEC = "d:\Users\US32784\utils\psexec.exe"
	#$cmd = "$PSEXEC \\$server -c $GACUTIL /l"
	
	$s = New-PSSession -Computer $servers
	Invoke-Command -Session $s -ScriptBlock {
		$gac = @()
		
		d:\Utils\gacutil.exe /l | where { $_ -like "*Culture*" } | Sort | %  {
			$assembly = New-Object PSObject
			
			$entry = $_.Split(",")
			$assembly | Add-Member -MemberType NoteProperty -Name DllName -Value $entry[0].Trim()
		
			$entry | where { $_.Contains("=") } | % {
				$details = $_.Split("=")
				$assembly | Add-Member -MemberType NoteProperty -Name $details[0].Trim() -Value $details[1].Trim()
			}
			$gac += $assembly
		}
		
		return $gac
				
	}

}

function Get-GoogleGraph([HashTable] $ht, [String] $title, [String] $size="750x350", [string] $file="chart.png",  [switch] $invoke)
{
    Set-Variable -Option Constant -Name chartType -Value bhs
    
	$chartdata = [String]::Join( "," , ($values.GetEnumerator() | sort Key -Descending | % { $_.Value } ))
    $chartYLabel = [String]::Join( "|", ($values.GetEnumerator() | sort Key | % { $_.Key } )) 
	
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

# Some code copied with permission from Steve Schofield 
# http://weblogs.asp.net/steveschofield/archive/2009/01/08/list-local-administrators-on-a-machine-using-powershell-adsi.aspx 
function Get-LocalAdmins( [string] $computer )
{
	$adsi  = [ADSI]("WinNT://" + $computer + ",computer") 
	$Group = $adsi.psbase.children.find("Administrators") 
	$members = $Group.psbase.invoke("Members") | %{$_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)} 
	
	return $members
}

function Add-LocalAdmin( [string] $computer, [string] $Group )
{
	$domain_controller = "ent-dc-d04"
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

function Get-FrameworkVersion ([Object] $virtual_dir)
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
	
	$xmlScriptBlock = {
		$xml += "<Site server=`"$($this.ServerName)`" name=`"$($this.Name)`">`n"
		$xml += "<LogDirectory>$($this.LogFileDirectory)</LogDirectory>`n"
		$xml += "<HostHeaders>`n"
		$this.HostHeaders | where { [String]::IsNullOrEmpty($_.HostName) -eq $false } | % {
			$xml += "`t<HostHeader name=`"$($_.HostName)`" ip=`"$($_.IP)`" port=`"$($_.Port)`" />`n"
		}
		$xml += "</HostHeaders>`n"
		$xml += "<VirtualDirectories>`n"
		$this.VirtualDirectories | % { 
			$xml += "<VirtualDirectory name=`"$($_.Name)`" >`n"
			$xml += "`t<Path>$($_.Path)</Path>`n"
			$xml += "`t<AppFriendlyName>$($_.AppFriendlyName)</AppFriendlyName>`n"
			$xml += "`t<DotNetFrameworkVersion>$($_.DotNetFrameworkVersion)</DotNetFrameworkVersion>`n"
			$xml += "`t<DefaultDocuments>$($_.DefaultDocuments)</DefaultDocuments>`n"
			$xml += "`t<AppPoolName>$($_.AppPoolName)</AppPoolName>`n"
			$xml += "`t<AppPoolAccount>$($_.AppPoolAccount)</AppPoolAccount>`n"
			$xml += "`t<AnonymousUserName>$($_.AnonymousUserName)</AnonymousUserName>`n"
			$xml += "`t<AccessPermissions>$($_.AccessPermissions)</AccessPermissions>`n"
			$xml += "`t<Authentication>$($_.Authentication)</Authentication>`n"
			$xml += "`t<AuthenticationProviders>$($_.AuthenticationProviders)</AuthenticationProviders>`n"
			$xml += "</VirtualDirectory>`n"
		}
		
		$xml += "</VirtualDirectories>`n"
		$xml += "</Site>"
		
		$xml
	}
	
	$csvScriptBlock = {
		$csv=$nul
		$Server = $this.ServerName
		$SiteName = $this.Name
		$LogFileDirectory = $this.LogFileDirectory
		$this.VirtualDirectories | % {
			$DefaultDocs = $_.DefaultDocuments.Replace(",",";")
			$csv += "$Server,$SiteName,$LogFileDirectory,$($_.Name),$($_.Path),$($_.AppFriendlyName),"
			$csv += "$DefaultDocs,$($_.AppPoolName),$($_.AppPoolAccount),$($_.AnonymousUserName),"
			$csv += "$($_.AccessPermissions),$($_.Authentication),$($_.AuthenticationProviders)`n"
		}
		
		$csv
	
	}
	
	$Servers | % { 
		$Server = $_
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
				$audit | Add-Member -type ScriptMethod -Name toXML -Value $xmlScriptBlock
				$audit | Add-Member -type ScriptMethod -Name toCSV -Value $csvScriptBlock
			
				$iisAudit += $audit
			}
		} else 
		{
			Write-Host $_ "appears down. Will not continue with audit"
		}
	}
	
	return $iisAudit
}

function audit-Server( [String] $server )
{
	
	$xmlScriptBlock = {
		$xml = "<System name=`"$($this.SystemName)`">`n"
		$xml += "<Application name=`"$($this.Application)`" env=`"$($this.Environment)`" />`n"
		$xml += "<Domain>$($this.Domain)</Domain>`n"
		$xml += "<Type>$($this.Type1)</Type>`n"
		$xml += "<SerialNumber>$($this.SerialNumber)</SerialNumber>`n"
		$xml += "<Processor>$($this.Processor)</Processor>`n"
		$xml += "<Memory>$($this.Memory)</Memory>`n"
		$xml += "<IPAddresses>`n"
		$this.IPAddresses | % {
			$xml += "`t<IPAddress>$_</IPAddress>`n"
		}
		$xml += "</IPAddresses>`n"
		$xml += "<LocalStorage>`n"
		$this.Drives | % { 
			$xml += "`t<Disk drive=`"$($_.DeviceId)`" size=`"$($_.TotalSpace)`" free=`"$($_.FreeSpace)`" />`n"
		}
		$xml += "</LocalStorage>`n"
		$xml += "<OperatingSystem>`n"
		$xml += "`t<version>$($this.OperatingSystem)</version>`n"
		$xml += "</OperatingSystem>`n"
		$xml += "</System>"
		
		$xml
	}
	
	$csvScriptBlock = {
		$ips += [string]::join( "|", $this.IPAddresses )
		$cpu = $this.Processor
		$os = $this.OperatingSystem.Replace(",","")
		if( $this.Drives.Count -eq $null ) {
			$drives = $this.Drives  
		} else { 
			$drives = [string]::join("|", $this.Drives)
		}
		$model = $this.Type1.Replace(",","")
		
		$csv = "$($this.SystemName),$ips,$($this.Application),$($this.Environment),$($this.Domain),$Model,$($this.SerialNumber),$cpu,"
		$csv += "$($this.Memory),$os, $drives`n"
	
		$csv
	}

	$audit = New-Object System.Object
	$computer = Get-WmiObject Win32_ComputerSystem -ComputerName $server
	$os = Get-WmiObject Win32_OperatingSystem -ComputerName $server
	$bios = Get-WmiObject Win32_BIOS -ComputerName $server
	$nics = Get-WmiObject Win32_NetworkAdapterConfiguration -ComputerName $server
	$cpu = Get-WmiObject Win32_Processor -ComputerName $server | select -first 1 -expand MaxClockSpeed
	$disks = Get-WmiObject Win32_LogicalDisk -ComputerName $server
	
	$audit | add-member -type NoteProperty -name SystemName -Value $computer.Name
	$audit | add-member -type NoteProperty -name Domain -Value $computer.Domain		
	$audit | add-member -type NoteProperty -name Type1 -Value ($computer.Manufacturer + " " + $computer.Model.TrimEnd())
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

function audit-Servers([String[]] $Servers, [String] $app, [String] $env)
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

function Get-EventViewer2003( [String] $server, [String[]] $evtlogs, [String] $filter = $nul) 
{
	set-variable -option constant -name eventqueryScript -Value "cscript //NoLogo $ENV:WINDIR\system32\eventquery.vbs /S {0} /L {1} /V /FO List {2}"
	$logs = @()
	
	if( -not [String]::IsNullOrEmpty($filter) ) 
	{
		$filter = "/FI `"$filter`""	
	}
	
	$evtlogs | % {
			
		$evtLog = "`"$_`""
		Write-Progress -activity "Querying Event logs" -status "Working on $server's $evtLog log"
	
		$scriptCmd = $eventqueryScript -f $server,$evtLog,$filter
		$eventquery = invoke-expression $scriptCmd
		
		for( $i = 0; $i -lt $eventquery.Length; $i++ )
		{
			$log = new-object System.Object
			$log | add-member -type NoteProperty -name Server -value $server
			$log | add-member -type NoteProperty -name EventLog -value $evtLog

			while($eventquery[$i] -ne "" -and $i -lt $eventquery.Length )
			{
				$key, $value, $nul = [regex]::Split( $eventquery[$i], ":  " )
				if($key -ne $nul -and $value -ne $nul) { $log | add-member -type NoteProperty -name $key -value $value.TrimStart() }
				$i++
			}
			$logs += $log
		}
	}
	
	return $logs	
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

function Get-GroupMembership ([String[]] $Groups)
{
	begin {
		$GroupMembership = @()
	}
	process {
		if( -not [String]::IsNullorEmpty($_) ) { $Groups = $_ }
		$Groups | % {
			$users = dsquery group -name "$_" | dsget group -members | % {
				if( -not [String]::IsNullorEmpty($_) ) { $_.Split("=")[1].Split(",")[0] }
			}	
			
			$group = new-object System.Object
			$group | add-member -type NoteProperty -name GroupName -value $_
			$group | add-member -type NoteProperty -name Users -value $users
			
			$GroupMembership += $group
		}
	}
	end {
		return $GroupMembership
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

##################################################################################################
## Rijndael symmetric key encryption ... with no passes on the key. Very lazy.
## USAGE:
## $encrypted = Encrypt-String "Oisin Grehan is a genius" "P@ssw0rd"
## Decrypt-String $encrypted "P@ssw0rd"
##
## You can choose to return an array by passing -arrayOutput to Encrypt-String
## I chose to use Base64 encoded strings because they're easier to save ...
##
## http://poshcode.org/116
##
[void] [Reflection.Assembly]::LoadWithPartialName("System.Security")
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
#End AES Encryption/Decryption Block
#Reference - http://poshcode.org/116
##################################################################################################

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

function ping-multiple 
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

Function read-RegistryHive 
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

function send-email($s,$b,$to) 
{
	$from = "SharePoint.Admins@gt.com";
	$domain  = "mail.gt.com";

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

function send-emailwithattachment( [string] $subject, [string] $body, [object] $to, [Object] $attachment  )
{
	$from = "spadmin@gt.com";
	$domain  = "mail.gt.com";
	
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

function get-hash1 
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

function get-fileVersion() 
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

# Author: William Stacey (http://www.codeplex.com/PsObject/WorkItem/View.aspx?WorkItemId=8521)
# Created: 02/22/2007
# Modified: Brian Denicola - removed looping
function get-tail([string]$path = $(throw "Path name must be specified."), [int]$count = 10)
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


function get-tailByBytes([string]$path = $(throw "Path name must be specified."), [int]$bytes)
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

function get-fileSize ( [string] $path ) 
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
