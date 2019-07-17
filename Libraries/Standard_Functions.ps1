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
    begin {
        $objectsToProcess = @()
    }
    process {
        $objectsToProcess += $inputObject
    }
    end {
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
	
    return $uptime_template -f $computer, $sysuptime.days, $sysuptime.hours, $sysuptime.minutes, $sysuptime.seconds
}

function Get-ScheduledTasks 
{
    param(
        [string] $ComputerName
    )

    $tasks = @()
	
    $tasks_com_connector = New-Object -ComObject("Schedule.Service")
    $tasks_com_connector.Connect($ComputerName)
    
    $all_tasks = $tasks_com_connector.GetFolder("\").GetTasks(0) | Select-Object Name, LastRunTime, LastTaskResult, NextRunTime, XML 
    $tasks = foreach ( $task in $all_tasks ) {
        $xml = [xml] ( $task.XML )
        $task_properties = [ordered]@{
            HostName    = $ComputerName
            Name        = $task.Name
            LastRunTime = $task.LastRunTime
            LastResult  = $task.LastTaskResult
            NextRunTime = $task.NextRunTime
            Author      = $xml.Task.RegistrationInfo.Author
            RunAsUser   = $xml.Task.Principals.Principal.UserId
            TaskToRun   = $xml.Task.Actions.Exec.Command
        }
        New-Object psobject -Property $task_properties 
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
   
    if ([string]::IsNullOrEmpty($pfxPass)) {
        $pfxPass = read-host "Enter the pfx password" -assecurestring
    }
   
    $pfx.import($certPath, $pfxPass, "Exportable,PersistKeySet")    
   
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($certStore, $certRootStore)    
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

    $cert = Get-ChildItem -path cert:\$certRootStore\$certStore | 
        Where-Object { $_.Subject.ToLower().Contains($subject) }
    $store = new-object System.Security.Cryptography.X509Certificates.X509Store($certStore, $certRootStore)
	
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
	
    $cert = Get-ChildItem -path cert:\$certRootStore\$certStore | 
        Where-Object { $_.Subject.ToLower().Contains($subject) }
    $type = [System.Security.Cryptography.X509Certificates.X509ContentType]::pfx
 
    if ([string]::IsNullOrEmpty($pfxPass)) {
        $pfxPass = Read-Host "Enter the pfx password" -assecurestring
    }
	
    $bytes = $cert.export($type, $pfxPass)
    [System.IO.File]::WriteAllBytes($file , $bytes)
}

function pause 
{
    Write-Output "Press any key to exit..."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Get-PerformanceCounters 
{
    param (
        [String[]] $counters = @("\processor(_total)\% processor time", "\physicaldisk(_total)\% disk time", "\memory\% committed bytes in use", "\physicaldisk(_total)\current disk queue length"),
        [String[]] $computers,
        [int] $samples = 10,
        [int] $interval = 10		
    )
	
    Get-Counter $counters -ComputerName $computers -MaxSamples $samples -SampleInterval $interval |
        ForEach-Object { $t = $_.TimeStamp; $_.CounterSamples } | 
        Select-Object @{Name = "Time"; Expression = {$t}}, Path, CookedValue 
}

function Get-LocalAdmins 
{
    param ( [string] $computer )

    $adsi = [ADSI]("WinNT://" + $computer + ",computer") 
    $Group = $adsi.psbase.children.find("Administrators") 
    $members = $Group.psbase.invoke("Members") | 
        ForEach-Object {$_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)} 
	
    return $members
}

function Get-LocalGroup 
{
    param ( [string] $computer, [string] $Group )

    $adsi = [ADSI]("WinNT://" + $computer + ",computer") 
    $adGroup = $adsi.psbase.children.find($group) 
    $members = $adGroup.psbase.invoke("Members") | 
        ForEach-Object {$_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)} 
	
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

function Convert-ObjectToHash 
{
    param ( 
        [Object] $obj
    )
	
    $ht = @{}
    $Keys = $obj | Get-Member -MemberType NoteProperty | Select-Object -Expand Name

    foreach ( $key in $Keys ) { 
        if ( $obj.$key -is [System.Array] ) { 
            $value = [String]::Join(" | ", $obj.$key )
        }
        else {
            $value = $obj.$key
        }
        $ht.Add( $Key, $Value )
    }

    return $ht
}
	
function Get-IPAddress 
{
    param ( [string] $name )
    return ( try { [System.Net.Dns]::GetHostAddresses($name) | Select-Object -Expand IPAddressToString } catch {} )
}

function Ping-Multiple 
{
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $ComputerName
    )
    begin {
        $replies = @()
        $timeout = 1000
        $ping = New-Object System.Net.NetworkInformation.Ping 
    }
    process {
        trap { continue }
			
        $reply = $ping.Send($ComputerName , $timeout)
        $replies += (New-Object PSObject -Property @{
            ComputerName = $ComputerName	
            Address      = $reply.Address
            Time         = $reply.RoundtripTime
            Status       = $reply.Status
        })
    }
    end {
        return $replies
    }
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
	
    return ( ([system.bitconverter]::tostring($hash)).Replace("-", "") )
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
    $ds.Tables[0].Columns | Select-Object ColumnName | ForEach-Object { $Columns += $_.ColumnName }
    $res = $ds.Tables[0].Rows  | Select-Object $Columns
	
    $ds.Clear()
    $da.Dispose()
    $ds.Dispose()

    return $res
}