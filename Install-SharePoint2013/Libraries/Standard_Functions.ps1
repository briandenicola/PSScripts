$domain_controller = "ent-dc-d04"

function CheckFor-PendingReboot
{

  	$baseKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey("LocalMachine", $ENV:COMPUTERNAME)
	$key = $baseKey.OpenSubKey("Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\")
   	$subkeys = $key.GetSubKeyNames()
   	$key.Close()
   	$baseKey.Close()

   	if ($subkeys | Where {$_ -eq "RebootPending"}) 
   	{
    	return $true	
    } 
   	return $false
}

function Add-RunOnceTask
{
	param(
		[string] $name,
		[string] $command
	)

	New-ItemProperty "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name $name -PropertyType string
	Set-ItemProperty "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name $name -Value $command

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

function Get-Clipboard{
	PowerShell -NoProfile -STA -Command { Add-Type -Assembly PresentationCore; [Windows.Clipboard]::GetText() }
}

function Set-Clipboard{
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

function Get-Uptime {
	param($computer)
	
	$lastboottime = (Get-WmiObject -Class Win32_OperatingSystem -computername $computer).LastBootUpTime
	$sysuptime = (Get-Date) - [System.Management.ManagementDateTimeconverter]::ToDateTime($lastboottime)
	
	Write-Host "System ($computer) has been online since : " $sysuptime.days "days" $sysuptime.hours "hours" $sysuptime.minutes "minutes" $sysuptime.seconds "seconds"
}

function get-ScheduledTasks([string] $server) 
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

function audit-Server( [String] $server )
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

function nslookup ( [string] $name )
{
 	$ns = nslookup.exe $name 2>$null

	if( $ns.Length -eq 3 ) {
		return $false
	} else {
		return $ns[$ns.Length - 2].Split(":")[1].TrimStart()
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