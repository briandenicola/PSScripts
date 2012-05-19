
#region Functions
Function New-LogCollectionInfo()
{
   $LogCollectionInfo = New-Object System.Object
   $LogCollectionInfo | Add-Member -MemberType NoteProperty -Name SetupLogs      -Value $false
   $LogCollectionInfo | Add-Member -MemberType NoteProperty -Name PSCLogs        -Value $false
   $LogCollectionInfo | Add-Member -MemberType NoteProperty -Name PowerShellLogs -Value $false
   $LogCollectionInfo | Add-Member -MemberType NoteProperty -Name ULSLogs        -Value $false
   $LogCollectionInfo | Add-Member -MemberType NoteProperty -Name UpgradeLogs    -Value $false
   $LogCollectionInfo | Add-Member -MemberType NoteProperty -Name EventLogs      -Value $false
   $LogCollectionInfo | Add-Member -MemberType NoteProperty -Name Registry       -Value $false

   return $LogCollectionInfo
}

Function Get-LogsCollectionInfo($AllLogs, $SetupLogs, $PSCLogs, $PowerShellLogs, $ULSLogs, $UpgradeLogs, $EventLogs, $Registry)
{
   $LogsToCollect = New-LogCollectionInfo

   if ($SetupLogs -or $PSCLogs -or $PowerShellLogs -or $ULSLogs -or $UpgradeLogs -or $EventLogs -or $Registry)
   {
	  if($SetupLogs)      { $LogsToCollect.SetupLogs      = $true } 
	  if($PSCLogs)        { $LogsToCollect.PSCLogs        = $true }
	  if($PowerShellLogs) { $LogsToCollect.PowerShellLogs = $true }
	  if($ULSLogs)        { $LogsToCollect.ULSLogs        = $true }
	  if($UpgradeLogs)    { $LogsToCollect.UpgradeLogs    = $true }
	  if($EventLogs)      { $LogsToCollect.EventLogs      = $true }
	  if($Registry)       { $LogsToCollect.Registry       = $true }
   }
   elseif ($AllLogs)
   {
	  $LogsToCollect.SetupLogs      = $true
	  $LogsToCollect.PSCLogs        = $true 
	  $LogsToCollect.PowerSHellLogs = $true
	  $LogsToCollect.ULSLogs        = $true
	  $LogsToCollect.UpgradeLogs    = $true
	  $LogsToCollect.EventLogs      = $true
	  $LogsToCollect.Registry       = $true
   }
   else
   {
	  $LogsToCollect.SetupLogs      = $true
	  $LogsToCollect.PSCLogs        = $true 
	  $LogsToCollect.PowerSHellLogs = $true
	  $LogsToCollect.ULSLogs        = $true
	  $LogsToCollect.UpgradeLogs    = $true
	  $LogsToCollect.EventLogs      = $true
	  $LogsToCollect.Registry       = $true
   }

   # Check at least something is set to true otherwise fail

   return $LogsToCollect
}

Function Collect-Logs($Path, $FileMask, $OutputPath)
{   
	$Logs = @(Get-ChildItem -Path $Path | ? { $_.Name -match $FileMask })
	
	if (($Logs.Count -eq 0) -or ($Logs -eq $null))
	{
	Write-Warning ("No Logs could be found matching {0}" -f $FileMask)
	return
	}
	
	if (-not (Test-Path $OutputPath))
	{
		New-Item -Path $OutputPath -ItemType Directory | Out-Null
	}

	Write-Verbose ("Found {0} log(s) matching {1} in {2}" -f $Logs.Count, $FileMask, $Path )
	
	foreach ($Log in $Logs)
	{
		Write-Verbose ("Copying Log {0} to {1}" -f $Log, $OutputPath)
		Copy-Item $Log.FullName -Destination $OutputPath -Force
	}
}

Function Collect-EventLog($LogName, $OutputPath)
{
	Write-Verbose ("Gathering Event Log entries from: {0}" -f $LogName)
	
	if (-not (Test-Path $OutputPath))
	{
		New-Item -Path $OutputPath -ItemType Directory | Out-Null
	}
	
	wevtutil export-log $LogName ("{0}\{1}_{2}.evtx" -f $OutputPath, ($LogName -replace "/","_"), $env:computername) | Out-Null
	
	switch ($lastexitcode) 
	{
		0       { Write-Verbose ("Sucessfully saved log: {0}" -f $LogName) }
		3       { Write-Warning ("Cannot find path specified: {0} {1}" -f $OutputPath, $LogName) }
		15007   { Write-Warning ("Log does not exist: {0}" -f $LogName) }
		default { Write-Warning ("Unexpected failure in obtaining log: {0}, {1}" -f $LogName, $lastexitcode) }
	}
	
}

Function Collect-RegistryNode($Node, $OutputPath)
{
	Write-Verbose ("Backing up node {0}" -f $Node)
	
	if (-not (Test-Path $OutputPath))
	{
		New-Item -Path $OutputPath -ItemType Directory | Out-Null
	}
	
	$NodeName = Split-Path $Node -Leaf
	reg export $Node ("{0}\{1}_{2}.reg" -f $OutputPath, $NodeName, $env:COMPUTERNAME) | Out-Null
	
	if ($LASTEXITCODE -ne 0)
	{
		Write-Warning ("Could not back up node {0}. Error code was {1}." -f $Node, $LASTEXITCODE)
	}
}


Function Collect-AllLogs($LogsToCollect, $TempCollectionDir)
{
   If (Test-Path $TempCollectionDir)
   {
	  Remove-Item $TempCollectionDir -Force -Recurse
   }

   New-Item $TempCollectionDir -Type Directory -Force -ErrorAction SilentlyContinue | Out-Null

   if ($LogsToCollect.SetupLogs) 
   { 
	  Write-Output "Collecting Setup logs..." 
	
	  $SetupLogPath = $env:TEMP
	  $SetupLogMask = "SharePoint.*.log|Office Server Setup.*.log|Microsoft Windows SharePoint Services 4.0 Setup.*.log|Search Server Setup.*.log|Project Server Setup.*.log|Wac Server Setup.*.log|Office Server Language Pack Setup.*.log|SetupExe.*.log|MSI.*.log"
	
	  Collect-Logs -Path $SetupLogPath -FileMask $SetupLogMask -OutputPath $TempCollectionDir\SetupLogs\
	
	  $ExtraLogMask = "WrapInstallLog.*.log|OsrvRedistLog.*.log|PrerequisiteInstaller.*.log"
	
	  Collect-Logs -Path $SetupLogPath -FileMask $ExtraLogMask -OutputPath $TempCollectionDir\SetupLogs\
   } 

   if ($LogsToCollect.PSCLogs) 
   {
	  Write-Output "Collecting PSC logs..." 
	
	  $PSCLogPath = Get-DefaultLogPath
	  $PSCLogMask = "PSCDiagnostics.*.log|psconfig.exe.*.log"
	
	  Collect-Logs -Path $PSCLogPath -FileMask $PSCLogMask -OutputPath $TempCollectionDir\PSCLogs\
	
   } 

   if ($LogsToCollect.PowerShellLogs) 
   { 
	  Write-Output "Collecting Windows PowerShell logs..."
	
	  $PowerShellLogPath = Get-DefaultLogPath
	  $PowerShellLogMask = "PowerShell_ConfigurationDiagnostics.*.log"
	
	  Collect-Logs -Path $PowerShellLogPath -FileMask $PowerShellLogMask -OutputPath $TempCollectionDir\PowerShellLogs\
   } 

   if ($LogsToCollect.ULSLogs)        
   {    
	  Write-Output "Collecting ULS logs..."
	
	  $ULSLogPath = Get-DefaultLogPath
	  $ULSLogMask = "$env:computername.*.log"
	
	  Collect-Logs -Path $ULSLogPath -FileMask $ULSLogMask -OutputPath $TempCollectionDir\ULSLogs\
   }

   if ($LogsToCollect.UpgradeLogs)        
   {    
	  Write-Output "Collecting Upgrade logs..."
	
	  $UpgradeLogPath = Get-DefaultLogPath
	  $UpgradeLogMask = "upgrade.*.log"
	
	  Collect-Logs -Path $UpgradeLogPath -FileMask $UpgradeLogMask -OutputPath $TempCollectionDir\UpgradeLogs\
   }

   if ($LogsToCollect.EventLogs)        
   { 
	  Write-Output "Collecting Event logs..."

	  $EventLogsToGrab = @("Application", "System", "Microsoft-SharePoint Products-Shared/Operational", "Microsoft-SharePoint Products-OfficeSearchServer/Analytic", "Microsoft-SharePoint Products-SharepointSearchServer/Analytic")
	
	  foreach ($EventLog in $EventLogsToGrab)
	  {
		 Collect-EventLog $EventLog -OutputPath $TempCollectionDir\EventLogs\
	  }
   }

   if ($LogsToCollect.Registry)        
   { 
	  Write-Output "Collecting Registry hives..."

	  $RegistryNodesToGrab = @("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Shared Tools\Web Server Extensions",
	  						   "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Office",
							   "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Office Server",
							   "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\FIMService",
							   "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\FIMSynchronizationService",
							   "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")
	
	  foreach ($Node in $RegistryNodesToGrab)
	  {
		 Collect-RegistryNode -Node $Node -OutputPath $TempCollectionDir\Registry\
	  }
   }
}

Function Get-DefaultLogPath()
{
   $RegistryLogDir = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Shared Tools\Web Server Extensions\$Version.0\WSS\").LogDir 

   # need to find a neater way of fixing up batch paths
   if ($RegistryLogDir -match ".*%.*%.*")
   {
	  $RegistryLogDir = [System.Environment]::ExpandEnvironmentVariables($RegistryLogDir)
   }
   Write-Verbose ("Log dir is: {0}" -f $RegistryLogDir)
   return $RegistryLogDir
}

Function Add-Summary($OutputPath)
{
   $SummaryFilePath = ("{0}\Summary.txt" -f $OutPutPath)
}
#endregion

#region MainScript
function Backup-Logs
{

    [CmdletBinding()]
    param(
       [switch]$AllLogs,
       [switch]$SetupLogs,
       [switch]$PSCLogs,
       [switch]$PowerShellLogs,
       [switch]$ULSLogs,
       [switch]$UpgradeLogs,
       [switch]$EventLogs,
       [switch]$Registry,
       [switch]$KeepLogs,
       [switch]$Force,
       [switch]$Help,
       [String]$Version = "14",
       
       [Parameter(Mandatory=$true)]
       [String]$OutputPath
    )

    if ($Help)
    {
       Write-Output "Usage: Backup-Logs [-AllLogs | -SetupLogs | -PSCLogs | -PowerShellLogs | -ULSLogs | -UpgradeLogs | -EventLogs] -OutputPath <Path to place zip file with collected logs>"
       Write-Output "Each parameter is a swtich dictating whether you want the logs or not (default is false), AllLogs is a shortcut for all true and is the default."
       return
    }

    if ($Verbose)
    {
       $VerbosePreference = "Continue"
    }

    if ([String]::IsNullOrEmpty($OutputPath))
    {
       Write-Warning ("Must specify output path: {0}" -f $OutputPath)
       $OutputPath = Read-Host -Prompt "Full path to output zip file e.g. \\server\share\folder\file.zip or $env:userprofile\Desktop\file.zip"
    }

    Write-Debug ("SetupLogs: {0}, PSCLogs {1}, PowerShellLogs {2}, ULSLogs: {3}, EventLogs {4}" -f $SetupLogs, $PSCLogs, $PowerShellLogs, $ULSLogs, $EventLogs)
    
    #Temp Dir to hold the logs before compression
    $TempCollectionDir = "$env:userprofile\Desktop\CollectedLogs"

    $DesiredLogs = Get-LogsCollectionInfo -AllLogs:$AllLogs -SetupLogs:$SetupLogs -PSCLogs:$PSCLogs -PowerShellLogs:$PowerShellLogs -ULSLogs:$ULSLogs -UpgradeLogs:$UpgradeLogs -EventLogs:$EventLogs -Registry:$Registry
    
    Collect-AllLogs -LogsToCollect $DesiredLogs -TempCollectionDir $TempCollectionDir 
    
    Add-Summary -OutputPath $TempCollectionDir
    $FailedZips = @("")
    Write-Output ("Zipping logs to {0}" -f $OutputPath)    
    if ($DesiredLogs.SetupLogs) 
    {
        if (Test-Path $TempCollectionDir\SetupLogs\)
        {
            $tempZip = "$TempCollectionDir\SetupLogs.zip"
            if (Test-Path $tempZip)
            {
                Remove-Item $tempZip -Force
            }
            Write-Output ("  Compressing Setup logs...")
            Compress-ToZip -ZipFile $tempZip -FileName $TempCollectionDir\SetupLogs\
            $zipJob = Start-Job -name ZipJobSetup -ScriptBlock {Compress-ToZip -ZipFile $args[0] -FileName $args[1]} -InitializationScript {Import-Module SPModule.misc} -ArgumentList $OutputPath, $tempZip
            $null = $zipJob | Wait-Job
            $joberror = get-job -Name "ZipJobSetup" | %{$_.ChildJobs} | %{$_.Error} | %{$_.FullyQualifiedErrorId}
            if (($joberror -eq "DotNetMethodException") -or ($joberror -eq "RuntimeException"))
            {
                Write-Warning "Failed to add $tempZip to $OutputPath. Keeping file."
                $FailedZips = $FailedZips + @("SetupLogs.zip*")
            }
            Remove-Job $zipJob
        }
    }
    
    if ($DesiredLogs.PSCLogs) 
    {
        if (Test-Path $TempCollectionDir\PSCLogs\)
        {
            $tempZip = "$TempCollectionDir\PSCLogs.zip"
            if (Test-Path $tempZip)
            {
                Remove-Item $tempZip -Force
            }
            Write-Output ("  Compressing PSC logs...")
            Compress-ToZip -ZipFile $tempZip -FileName $TempCollectionDir\PSCLogs\
            $zipJob = Start-Job -name ZipJobPSC -ScriptBlock {Compress-ToZip -ZipFile $args[0] -FileName $args[1]} -InitializationScript {Import-Module SPModule.misc} -ArgumentList $OutputPath, $tempZip
            $null = $zipJob | Wait-Job
            $joberror = get-job -Name "ZipJobPSC" | %{$_.ChildJobs} | %{$_.Error} | %{$_.FullyQualifiedErrorId}
            if (($joberror -eq "DotNetMethodException") -or ($joberror -eq "RuntimeException"))
            {
                Write-Warning "Failed to add $tempZip to $OutputPath. Keeping file."
                $FailedZips = $FailedZips + @("PSCLogs.zip*")
            }
            Remove-Job $zipJob
        }
    }

    if ($DesiredLogs.PowerShellLogs) 
    {
        if (Test-Path $TempCollectionDir\PowerShellLogs\)
        {
            $tempZip = "$TempCollectionDir\PowerShellLogs.zip"
            if (Test-Path $tempZip)
            {
                Remove-Item $tempZip -Force
            }
            Write-Output ("  Compressing Windows PowerShell logs...")
            Compress-ToZip -ZipFile $tempZip -FileName $TempCollectionDir\PowerShellLogs\
            $zipJob = Start-Job -name ZipJobPowerShell -ScriptBlock {Compress-ToZip -ZipFile $args[0] -FileName $args[1]} -InitializationScript {Import-Module SPModule.misc} -ArgumentList $OutputPath, $tempZip
            $null = $zipJob | Wait-Job
            $joberror = get-job -Name "ZipJobPowerShell" | %{$_.ChildJobs} | %{$_.Error} | %{$_.FullyQualifiedErrorId}
            if (($joberror -eq "DotNetMethodException") -or ($joberror -eq "RuntimeException"))
            {
                Write-Warning "Failed to add $tempZip to $OutputPath. Keeping file."
                $FailedZips = $FailedZips + @("PowerShellLogs.zip*")
            }
            Remove-Job $zipJob
        }
    }
    
    if ($DesiredLogs.ULSLogs)        
    {
        if (Test-Path $TempCollectionDir\ULSLogs\)
        {
            $tempZip = "$TempCollectionDir\ULSLogs.zip"
            if (Test-Path $tempZip)
            {
                Remove-Item $tempZip -Force
            }
            Write-Output ("  Compressing ULS logs...")
            Compress-ToZip -ZipFile $tempZip -FileName $TempCollectionDir\ULSLogs\
            $zipJob = Start-Job -name ZipJobULS -ScriptBlock {Compress-ToZip -ZipFile $args[0] -FileName $args[1]} -InitializationScript {Import-Module SPModule.misc} -ArgumentList $OutputPath, $tempZip
            $null = $zipJob | Wait-Job
            $joberror = get-job -Name "ZipJobULS" | %{$_.ChildJobs} | %{$_.Error} | %{$_.FullyQualifiedErrorId}
            if (($joberror -eq "DotNetMethodException") -or ($joberror -eq "RuntimeException"))
            {
                Write-Warning "Failed to add $tempZip to $OutputPath. Keeping file."
                $FailedZips = $FailedZips + @("ULSLogs.zip*")
            }
            Remove-Job $zipJob
        }
    }

    if ($DesiredLogs.UpgradeLogs)        
    {
        if (Test-Path $TempCollectionDir\UpgradeLogs\)
        {
            $tempZip = "$TempCollectionDir\UpgradeLogs.zip"
            if (Test-Path $tempZip)
            {
                Remove-Item $tempZip -Force
            }
            Write-Output ("  Compressing Upgrade logs...")
            Compress-ToZip -ZipFile $tempZip -FileName $TempCollectionDir\UpgradeLogs\
            $zipJob = Start-Job -name ZipJobUpgrade -ScriptBlock {Compress-ToZip -ZipFile $args[0] -FileName $args[1]} -InitializationScript {Import-Module SPModule.misc} -ArgumentList $OutputPath, $tempZip
            $null = $zipJob | Wait-Job
            $joberror = get-job -Name "ZipJobUpgrade" | %{$_.ChildJobs} | %{$_.Error} | %{$_.FullyQualifiedErrorId}
            if (($joberror -eq "DotNetMethodException") -or ($joberror -eq "RuntimeException"))
            {
                Write-Warning "Failed to add $tempZip to $OutputPath. Keeping file."
                $FailedZips = $FailedZips + @("UpgradeLogs.zip*")
            }
            Remove-Job $zipJob
        }
    }

    if ($DesiredLogs.EventLogs)        
    {
        if (Test-Path $TempCollectionDir\Registry\)
        {
            $tempZip = "$TempCollectionDir\EventLogs.zip"
            if (Test-Path $tempZip)
            {
                Remove-Item $tempZip -Force
            }
            Write-Output ("  Compressing Event logs...")
            Compress-ToZip -ZipFile $tempZip -FileName $TempCollectionDir\EventLogs\
            $zipJob = Start-Job -name ZipJobEvent -ScriptBlock {Compress-ToZip -ZipFile $args[0] -FileName $args[1]} -InitializationScript {Import-Module SPModule.misc} -ArgumentList $OutputPath, $tempZip
            $null = $zipJob | Wait-Job
            $joberror = get-job -Name "ZipJobEvent" | %{$_.ChildJobs} | %{$_.Error} | %{$_.FullyQualifiedErrorId}
            if (($joberror -eq "DotNetMethodException") -or ($joberror -eq "RuntimeException"))
            {
                Write-Warning "Failed to add $tempZip to $OutputPath. Keeping file."
                $FailedZips = $FailedZips + @("EventLogs.zip*")
            }
            Remove-Job $zipJob
        }
    }

    if ($DesiredLogs.Registry)        
    {
        if (Test-Path $TempCollectionDir\Registry\)
        {
            $tempZip = "$TempCollectionDir\Registry.zip"
            if (Test-Path $tempZip)
            {
                Remove-Item $tempZip -Force
            }
            Write-Output ("  Compressing Registry hives...")
            Compress-ToZip -ZipFile $tempZip -FileName $TempCollectionDir\Registry\
            $zipJob = Start-Job -name ZipJobRegistry -ScriptBlock {Compress-ToZip -ZipFile $args[0] -FileName $args[1]} -InitializationScript {Import-Module SPModule.misc} -ArgumentList $OutputPath, $tempZip
            $null = $zipJob | Wait-Job
            $joberror = get-job -Name "ZipJobRegistry" | %{$_.ChildJobs} | %{$_.Error} | %{$_.FullyQualifiedErrorId}
            if (($joberror -eq "DotNetMethodException") -or ($joberror -eq "RuntimeException"))
            {
                Write-Warning "Failed to add $tempZip to $OutputPath. Keeping file."
                $FailedZips = $FailedZips + @("Registry.zip*")
            }
            Remove-Job $zipJob
        }
    }

    if (!$KeepLogs)
    {
        Write-Output ("Removing collected files...")
        Get-ChildItem $TempCollectionDir -Exclude $FailedZips -Recurse | Remove-Item -Recurse -Force
    }
    else
    {
        Write-Output ("Keeping collected files...")
    }

    Write-Output "Finished"
}
#endregion