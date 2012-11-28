function Get-WebServiceURL( [String] $url )
{
	$listWebService = "_vti_bin/Lists.asmx?WSDL"
	
	if( -not $url.EndsWith($listWebService) )
	{
		return $url.Substring( 0, $url.LastIndexOf("/") ) + "/" + $listWebService
	} else
	{
		return $url
	}

}

function Get-SPListViaWebService([string] $url, [string] $list, [string] $view = $null )
{
	begin {
		$listData = @()
		
		$service = New-WebServiceProxy (Get-WebServiceURL -url $url) -Namespace List -UseDefaultCredential
		
		$FieldsWS = $service.GetList( $list )
		$Fields = $FieldsWS.Fields.Field | where { $_.Hidden -ne "TRUE"} | Select DisplayName, StaticName -Unique
	
		$data = $service.GetListItems( $list, $view, $null, $null, $null, $null, $null )
	}
	process {
			
		$ErrorActionPreference = "silentlycontinue"
		$data.data.row | % {
			$item = $_
			$t = new-object System.Object
			$Fields | % {
				$StaticName = "ows_" + $_.StaticName
				$DisplayName = $_.DisplayName
				if( $item.$StaticName -ne $nul ) {
					$t | add-member -type NoteProperty -name $DisplayName.ToString() -value $item.$StaticName
				}
			}
			$listData += $t
		}
	}
	end {
			return ( $listData )
	}
}

function WriteTo-SPListViaWebService ( [String] $url, [String] $list, [HashTable] $Item, [String] $TitleField )
{
	begin {
		$service = New-WebServiceProxy (Get-WebServiceURL -url $url) -Namespace List -UseDefaultCredential
	}
	process {

		$xml = @"
			<Batch OnError='Continue' ListVersion='1' ViewName='{0}'>  
				<Method ID='1' Cmd='New'>
					{1}
				</Method>  
			</Batch>  
"@   

		$listInfo = $service.GetListAndView($list, "")   

		foreach ($key in $item.Keys) {
			$value = $item[$key]
			if( -not [String]::IsNullOrEmpty($TitleField) -and $key -eq $TitleField ) {
				$key = "Title"
			}
			$listItem += ("<Field Name='{0}'>{1}</Field>`n" -f $key,$value)   
		}   
  
		$batch = [xml]($xml -f $listInfo.View.Name,$listItem)   
				
		$response = $service.UpdateListItems($listInfo.List.Name, $batch)   
		$code = [int]$response.result.errorcode   
	
 		if ($code -ne 0) {   
			Write-Warning "Error $code - $($response.result.errortext)"     
		} else {
			Write-Host "Success"
		}
	}
	end {
		
	}
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

function Disable-UserAccessControl
{
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 00000000
    Write-Host "User Access Control (UAC) has been disabled." -ForegroundColor Green    
} 

function Get-Uptime {
	param($computer)
	
	$lastboottime = (Get-WmiObject -Class Win32_OperatingSystem -computername $computer).LastBootUpTime
	$sysuptime = (Get-Date) - [System.Management.ManagementDateTimeconverter]::ToDateTime($lastboottime)
	
	Write-Host "System ($computer) has been online since : " $sysuptime.days "days" $sysuptime.hours "hours" $sysuptime.minutes "minutes" $sysuptime.seconds "seconds"
}

function Get-LocalAdmins( [string] $computer )
{
	$adsi  = [ADSI]("WinNT://" + $computer + ",computer") 
	$Group = $adsi.psbase.children.find("Administrators") 
	$members = $Group.psbase.invoke("Members") | %{$_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)} 
	
	return $members
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
