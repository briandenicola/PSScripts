#Requires -version 2.0

function Install-SharePoint
{
    <#
    .Synopsis
        Installs SharePoint with the provided parameters.
    .Description
        Installs SharePoint with the provided parameters. InstallSharePoint.log + Config.xml contain PIDKey post install. If this is sensitive information, 
        those files should be removed or edited.
    .Example
        Install-SharePoint –SetupExePath D:\setup.exe -PIDKey xxxxx-xxxxx-xxxxx
    .Example
        Install-SharePoint –ConfigXml \\server\share\folder\config.xml
    .Example
        Install-SharePoint –SetupExePath \\server\share\folder\setup.exe -ServerRole singleserver -PIDKey xxxxx-xxxxx-xxxxx-xxxxx-xxxxx
    .Example
        Install-SharePoint –SetupExePath \\server\share\folder -ConfigXml \\server\share\folder\config.xml
    .Parameter LoggingType
        The logging level this function will use for the 
        execution of the function itself. 
        DEFAULT: "verbose"   
        VALID VALUES: "off", "standard", "verbose", "debug"
    .Parameter LogPath
        This defines the location of the logs generated if 
        the LoggingType is not set to "off". 
        DEFAULT: "%temp%"   
        VALID VALUES: <<NOT NULL>>
    .Parameter LogTemplate
        This defines the format of the filename of the log. 
        DEFAULT: "SharePoint Setup Log (*).log"   
        VALID VALUES: <<NOT NULL>>
    .Parameter DisplayLevel
        The level of interactive UI when the funciton is run. 
        DEFAULT: "none"   
        VALID VALUES: "none", "basic", "full"
    .Parameter ShowCompletionNotice
        If set, the a completion notice will be shown. 
        DEFAULT: false   
        VALID VALUES: {This is a switch. True is used, false if not}
    .Parameter UseUIInstallMode
        If set, the function will use a UI install mode. 
        DEFAULT: false   
        VALID VALUES: {This is a switch. True is used, false if not}
    .Parameter AcceptEula
        If set, the Eula is automatically accepted. 
        DEFAULT: false   
        VALID VALUES: {This is a switch. True is used, false if not}
    .Parameter ShowModalDialogs
        If set, the modal dialog boxes are shown. 
        DEFAULT: false   
        VALID VALUES: {This is a switch. True is used, false if not}
    .Parameter AllowCancel
        If set, cancel is an option. 
        DEFAULT: false   
        VALID VALUES: {This is a switch. True is used, false if not}
    .Parameter ServerRole
        Defines the type of SharePoint server installation. 
        DEFAULT: "APPLICATION"   
        VALID VALUES: "APPLICATION", "WFE", "SINGLESERVER"
    .Parameter SetupType
        Defines to style of SharePoint server installation. 
        DEFAULT: "CLEAN_INSTALL"   
        VALID VALUES: "CLEAN_INSTALL", "V2V_INPLACE_UPGRADE", "B2B_UPGRADE", "SKU2SKU_UPGRADE"
    .Parameter InstallDirectory
        Defines the directory the product is installed into. 
        DEFAULT: N/A   
        VALID VALUES: {This is a path. We validate that it exists}
    .Parameter DataDirectory
        Defines the directory product data will reside. 
        DEFAULT: N/A   
        VALID VALUES: {This is a path. We validate that it exists}
    .Parameter SetupExePath
        MANDATORY if no ConfigXml. The location of the setup.exe file. 
        DEFAULT: N/A   
        VALID VALUES: {This is a path. We validate that it exists}
    .Parameter ConfigXmlPath
        MANDATORY if no SetupExePath. The location of a custom config.xml file. 
        DEFAULT: N/A   
        VALID VALUES: {This is a path. We validate that it exists}
    .Parameter PIDKeys
        MANDATORY if no ConfigXml. The product key. 
        DEFAULT: N/A   
        VALID VALUES: {A PID Key of the format }
    .Parameter RunSNWorkaround
        If set, strong name signing is disabled for all 
        Office products. This may be necessary for private 
        builds. Use only if guided to by Microsoft.
        DEFAULT: false   
        VALID VALUES: {This is a switch. True is used, false if not}
    .Parameter SkipPreReqInstaller
        If you have already installed prerequisites, this
        switch can speed up your installation time by skipping
        this step. 
        DEFAULT: false   
        VALID VALUES: {This is a switch. True is used, false if not}
    .Parameter PhysicalSKU
        The product being installed. 
        DEFAULT: "OfficeServer"   
        VALID VALUES: "OfficeServer", "SharePoint", "SearchServer", "SearchServerExpress", "WCServer", "ProjectServer", "SharePointLanguagePack", "ServerLanguagePack"
    .Parameter LanguagePacks
        Language packs that will be installed if available. 
        DEFAULT: N/A   
        VALID VALUES: "ar-sa","bg-bg","ca-es","cs-cz","da-dk","de-de","el-gr","en-us","es-es","et-ee","eu-es","fi-fi","fr-fr","gl-es","he-il","hi-in","hr-hr","hu-hu","it-it","ja-jp","kk-kz","ko-kr","lt-lt","lv-lv","nb-no","nl-nl","pl-pl","pt-br","pt-pt","ro-ro","ru-ru","sk-sk","sl-si","sr-latn-cs","sv-se","th-th","tr-tr","uk-ua","zh-cn","zh-tw", "all"
    .Link
        New-SharePointFarm
        Join-SharePointFarm
    #>
    [CmdletBinding(DefaultParameterSetName="BuildPath+SetupInfo")]
    param
    (
        #region SetupInfo
        [Parameter(Mandatory=$false, ParameterSetName="BuildPath+SetupInfo")][ValidateSet("off", "standard", "verbose", "debug")]
        [String]$LoggingType = "verbose",
    
        [Parameter(Mandatory=$false, ParameterSetName="BuildPath+SetupInfo")][ValidateNotNullOrEmpty()]
        [String]$LogPath = "%temp%",
    
        [Parameter(Mandatory=$false, ParameterSetName="BuildPath+SetupInfo")][ValidateNotNullOrEmpty()]
        [String]$LogTemplate = "SharePoint Setup Log (*).log",
    
        [Parameter(Mandatory=$false, ParameterSetName="BuildPath+SetupInfo")][ValidateSet("none", "basic", "full")]
        [String]$DisplayLevel = "none",
    
        [Parameter(Mandatory=$false, ParameterSetName="BuildPath+SetupInfo")]
        [switch]$ShowCompletionNotice,
    
        [Parameter(Mandatory=$false, ParameterSetName="BuildPath+SetupInfo")] 
        [switch]$UseUIInstallMode,
    
        [Parameter(Mandatory=$false, ParameterSetName="BuildPath+SetupInfo")] 
        [switch]$AcceptEula,
    
        [Parameter(Mandatory=$false, ParameterSetName="BuildPath+SetupInfo")] 
        [switch]$ShowModalDialogs,
    
        [Parameter(Mandatory=$false, ParameterSetName="BuildPath+SetupInfo")] 
        [switch]$AllowCancel,
    
        [Parameter(Mandatory=$false, ParameterSetName="BuildPath+SetupInfo")][ValidateSet("APPLICATION", "WFE", "SINGLESERVER")]
        [String]$ServerRole = "APPLICATION",
    
        [Parameter(Mandatory=$false, ParameterSetName="BuildPath+SetupInfo")][ValidateSet("CLEAN_INSTALL", "V2V_INPLACE_UPGRADE", "B2B_UPGRADE", "SKU2SKU_UPGRADE")]
        [String]$SetupType = "CLEAN_INSTALL",
    
        [Parameter(Mandatory=$false, ParameterSetName="BuildPath+SetupInfo")][ValidateScript({Test-Path $_ -IsValid -PathType Container })]
        [String]$InstallDirectory,
    
        [Parameter(Mandatory=$false, ParameterSetName="BuildPath+SetupInfo")][ValidateScript({Test-Path $_ -IsValid -PathType Container })]
        [String]$DataDirectory,
        #endregion
    
        #region BuildPath
        [Alias("sep")]
        [Parameter(Mandatory=$true, ParameterSetName="BuildPath+SetupInfo")][ValidateScript({Test-Path $_})]
        [Parameter(Mandatory=$true, ParameterSetName="BuildPath+ConfigXML")][ValidateScript({Test-Path $_})]
        [String]$SetupExePath,
        #endregion
    
        #region ConfigXML
        [Alias("cxp")]
        [Parameter(Mandatory=$true, ParameterSetName="BuildPath+ConfigXML")][ValidateScript({Test-Path $_ -PathType Leaf })]
        [String]$ConfigXmlPath,
        #endregion
    
        #region PIDKey
        [Alias("key")]
        [Parameter(Mandatory=$false, ParameterSetName="BuildPath+SetupInfo")]
        [Parameter(Mandatory=$false, ParameterSetName="BuildPath+ConfigXML")]
        [String]$PIDKey,
        #endregion
    
        #region Misc Parameters
        [Parameter(Mandatory=$false)]
        [switch]$RunSNWorkaround,
        
        [Alias("spr")]
        [Parameter(Mandatory=$false)]
        [switch]$SkipPreReqInstaller,
    
        [Parameter(Mandatory=$false)][ValidateSet("OfficeServer", "SharePoint", "SearchServer", "SearchServerExpress", "WCServer", "ProjectServer", "SharePointLanguagePack", "ServerLanguagePack", "")]
        [String]$PhysicalSKU,
        
        [Parameter(Mandatory=$false)][ValidateSet("ar-sa","bg-bg","ca-es","cs-cz","da-dk","de-de","el-gr","en-us","es-es","et-ee","eu-es","fi-fi","fr-fr","gl-es","he-il","hi-in","hr-hr","hu-hu","it-it","ja-jp","kk-kz","ko-kr","lt-lt","lv-lv","nb-no","nl-nl","pl-pl","pt-br","pt-pt","ro-ro","ru-ru","sk-sk","sl-si","sr-latn-cs","sv-se","th-th","tr-tr","uk-ua","zh-cn","zh-tw", "all")]
        [String[]]$LanguagePacks
        #endregion
    )
    
    $ErrorActionPreference = "Stop"

    #region Constants
    $SKUTable = @{
        "wss.msi"="SharePoint";
        "wsslpk.msi"="SharePointLanguagePack";
        "oserver.msi"="OfficeServer";
        "osmui.msi"="ServerLanguagePack";
        "pserver.msi"="ProjectServer";
        "sserver.msi"="SearchServer";
        "sserverx.msi"="SearchServerExpress";
        "wcserver.msi"="WCServer"
        }
    $ScriptLog = "$env:Temp\Install-SharePoint.log"
    #endregion 

    # Log out the usage for debugging
    Write-Output "Command Line:" | Out-File $ScriptLog -Append
    Write-Output $MyInvocation.Line | Out-File $ScriptLog -Append
    
    Write-Output `n | Out-File $ScriptLog -Append
    
    Write-Output "Initial Bound parameters:" | Out-File $ScriptLog -Append
    Write-Output $MyInvocation.BoundParameters | Out-File $ScriptLog -Append

    # Test to see if UAC is disabled or bypassed by 'Run as administrator'
    if(Test-ElevatedProcess)
    {
        Write-Output "Elevation: True" | Out-File $ScriptLog -Append
    }
    else
    {
       Write-Output "Elevation: False" | Out-File $ScriptLog -Append
        Write-Error "This Windows PowerShell session is not elevated.  Close this window and open Windows PowerShell again by right clicking and selecting 'Run as administrator'."
       throw
    }

    # Check to see if I need to build up a config.xml file (i.e. I only have setup info)
    if ($PsCmdlet.ParameterSetName -eq "BuildPath+SetupInfo")
    {
        [System.Xml.XmlDocument]$CurrentConfigXml = 
        @"
<Configuration>
    <Logging Type="verbose" Path="%temp%" Template="SharePoint Server Setup(*).log"/>
    <PIDKEY Value="Enter PID Key Here" />
    <Display Level="none" CompletionNotice="no" AcceptEula="no" SuppressModal="yes" NoCancel="yes"/>
    <Setting Id="SERVERROLE" Value="APPLICATION"/>
    <Setting Id="USINGUIINSTALLMODE" Value="0"/>
    <Setting Id="SETUP_REBOOT" Value="Never" />
    <Setting Id="SETUPTYPE" Value="CLEAN_INSTALL"/>
</Configuration>
"@

        # Change above config.xml to match custom parameters
        $CurrentConfigXml.Configuration.Logging.Type = $LoggingType
        $CurrentConfigXml.Configuration.Logging.Path = $LogPath
        $CurrentConfigXml.Configuration.Logging.Template = $LogTemplate

        $CurrentConfigXml.Configuration.Display.Level = $DisplayLevel.ToLower()

        if (($ShowCompletionNotice) -and ($CurrentConfigXml.Configuration.Display.Level -ne "Full"))
        {
            $CurrentConfigXml.Configuration.Display.CompletionNotice = "yes"
        }
        if (($ShowCompletionNotice) -and ($DisplayLevel -eq "Full"))
        {
            Write-Warning "ShowCompletionNotice not valid with DisplayLevel=Full"
        }

        if ($AcceptEULA)
        {
            $CurrentConfigXml.Configuration.Display.AcceptEULA = "yes"
        }

        if (($ShowModalDialogs) -and ($CurrentConfigXml.Configuration.Display.Level -eq "basic"))
        {
            $CurrentConfigXml.Configuration.Display.SuppressModal = "no"
        }
        if (($SuppressModal) -and (($DisplayLevel -eq "none") -or ($DisplayLevel -eq "full")))
        {
            Write-Warning ("SuppressModal not valid with DisplayLevel={0}" -f $DisplayLevel)
        }

        if (($AllowCancel) -and (($CurrentConfigXml.Configuration.Display.Level -eq "basic") -or ($CurrentConfigXml.Configuration.Display.Level -eq "full")))
        {
            $CurrentConfigXml.Configuration.Display.NoCancel="no"
        }
        if (($AllowCancel) -and ($DisplayLevel -eq "none"))
        {
            Write-Warning "AllowCancel and is not valid with DisplayLevel=none"
        }

        $ServerRoleSetting = $CurrentConfigXml.Configuration.Setting | ? { $_.Id -eq "SERVERROLE"}
        $ServerRoleSetting.Value = $ServerRole.ToUpper()

        $UiInstallModeSetting = $CurrentConfigXml.Configuration.Setting | ? { $_.Id -eq "USINGUIINSTALLMODE"}
        if ($UseUIInstallMode)
        {
            $UiInstallModeSetting.Value = "1"
        }

        $SetupTypeSetting = $CurrentConfigXml.Configuration.Setting | ? { $_.Id -eq "SETUPTYPE"}

        if ((Test-Path "HKLM:\SOFTWARE\Microsoft\Shared Tools\Web Server Extensions\$MajorVersion.0\Secure\ConfigDB") -and ($SetupType -eq "CLEAN_INSTALL"))
        {
            Write-Warning "This doesnt appear to be a clean install (or an incomplete uninstall) and you appear to be joined to a farm, changing SetupType to SKU2SKU_UPGRADE"
            $SetupType = "SKU2SKU_UPGRADE"
        }

        if ((Test-Path "HKLM:\SOFTWARE\Microsoft\Shared Tools\Web Server Extensions\12.0\Secure\FarmAdmin"))
        {
            Write-Warning "This doesnt appear to be a clean install you seem to have O12 installed, changing SetupType to V2V_INPLACE_UPGRADE"
            $SetupType = "V2V_INPLACE_UPGRADE"
        }

        $SetupTypeSetting.Value = $SetupType.ToUpper()

        if (-not ([String]::IsNullOrEmpty($InstallDirectory)))
        {
            $InstallDirNode = $CurrentConfigXml.CreateNode([System.Xml.XmlNodeType]::Element, "INSTALLLOCATION", $null);
            $InstallDirNode.SetAttribute("Value", $InstallDirectory)
            $CurrentConfigXml.Configuration.AppendChild($InstallDirNode) | Out-Null
        }

        if (-not ([String]::IsNullOrEmpty($DataDirectory)))
        {
            $DataDirNode = $CurrentConfigXml.CreateNode([System.Xml.XmlNodeType]::Element, "DATADIR", $null);
            $DataDirNode.SetAttribute("Value", $DataDirectory)
            $CurrentConfigXml.Configuration.AppendChild($DataDirNode) | Out-Null
        }
    }
    else
    {
        Write-Verbose "User specified config.xml, not making any changes, your config.xml had better be correct."
        [Xml]$CurrentConfigXml = Get-Content $ConfigXmlPath
    }
    
	    if (-not $PhysicalSku)
    {
        $SetupXML = Get-ChildItem -Recurse -Filter setup.xml -Path (Split-Path $SetupExePath -Parent) | Sort -Property Length -Descending | Select -First 1 
        
        if ($SetupXML -eq $null)
        {
            throw [System.NotSupportedException]("Could not find a setup.xml file in your build at {0}. Are you sure this is a SharePoint install?" -f $SetupExePath)
        }
        
        Write-Verbose ("setup.XML file found at: {0}" -f $SetupXML.FullName)
        
        $MSIPath = $SetupXML.DirectoryName
        $SkuMsi = Get-ChildItem -Path $MSIPath -Filter *.msi
        
        if ($SkuMsi -eq $null)
        {
            throw [System.IO.FileNotFoundException]("Could not find a valid SKU Specific MSI in your build at {0}. Are you sure this is a SharePoint install?" -f $SetupExePath)
        }
        
        Write-Verbose ("Sku specific MSI found at: {0}" -f $SkuMsi.FullName )
        
        $PhysicalSKU = $SKUTable[$SkuMsi.Name]
        
        
        #We may want to throw here, but the wost case is that you wont be able to isntall a free sku, 
        #as it will always ask for a key and we will put the value in the config.xml file.
        if ($PhysicalSKU -eq $null)
        {
            Write-Error "Could not determine Physical SKU. Are you sure this is a SharePoint setup.exe?"
        }
        
        Write-Verbose ("PhysicalSku was determined to be: {0}" -f $PhysicalSku)
    }

	if( [String]::IsNullOrEmpty($CurrentConfigXml.Configuration.PIDKEY.Value) )
	{
		# Regardless of what the config xml file says lets add a pid key (unless this is WSS or MSSx)
		if (($PhysicalSKU -eq "SharePoint") -or ($PhysicalSKU -eq "SearchServerExpress") -or ($PhysicalSKU -eq "SharePointLanguagePack") -or ($PhysicalSKU -eq "ServerLanguagePack"))
		{
			# Ensure there is no pidkey element
			$PIDNode = $CurrentConfigXml.Configuration.SelectSingleNode("PIDKEY")
			$DeletedNode = $CurrentConfigXml.Configuration.RemoveChild($PIDNode)
			Write-Verbose ("Deleted Node for PIDKey as you are installing a free SKU: {0}" -f $DeletedNode)
		}
		else
		{
			if ($PIDKey)
			{
				# Ensure we honor the PIDKey
				$CurrentConfigXml.Configuration.PIDKEY.Value = $PIDKey
			}
			elseif (([String]::IsNullOrEmpty($PIDKey)) -or (-not ($PIDKey)))
			{
				Write-Verbose "You didn't provide a PID Key, looks like I'll have to give you a trial key."
				
				switch ($PhysicalSKU)
				{
					"OfficeServer"   { $CurrentConfigXml.Configuration.PIDKEY.Value = "BR68M-F6WK6-W6BVB-GXQGB-W67BG"  ; Write-Verbose "Using a SharePoint Standard Trial PID Key. You can upgrade to Enterprise trial from Central Admin if you want to."; break}
					"ProjectServer"  { $CurrentConfigXml.Configuration.PIDKEY.Value = "9B4JM-6R6F8-2CMGW-T3T7W-6TYJW"  ; Write-Verbose "Using a Project Server Trial PID Key."; break}
					"SearchServer"   { $CurrentConfigXml.Configuration.PIDKEY.Value = "CX79M-QPKH7-7GFJQ-Y37T4-KKBRM"  ; Write-Verbose "Using a Search Server Trial PID Key."; break}
					"WCServer"       { Write-Error "There is no trial for WCServer, you must specify a retail PID Key."; break}
					default          { Write-Verbose ("Your SKU doesn't require a PIDKey: {0}" -f $PhysicalSKU)}
				}
			}    
			else
			{
				# The PID key is madatory if you dont specify a config.xml file.
				Write-Verbose "PID key not specified, this is only supported if it is in a specified config.xml"
			}
		}
	}
	
    #Check if we are installing on a suppported client OS...
    $Sku = $((gwmi win32_operatingsystem).OperatingSystemSKU)

    if (($Sku -eq 1) -or ($Sku -eq 4) -or ($Sku -eq 6) -or ($Sku -eq 16))
    {
        $ClientOSNode = $CurrentConfigXml.CreateNode([System.Xml.XmlNodeType]::Element, "Setting", $null);
        $ClientOSNode.SetAttribute("Id", "AllowWindowsClientInstall")
        $ClientOSNode.SetAttribute("Value", "True")
        $CurrentConfigXml.Configuration.AppendChild($ClientOSNode) | Out-Null
    }
    else
    {
        Write-Verbose "Not running on a client OS, so don't do anything." 
    } 

    #save the config.xml file localy
	$ConfigXmlName = ("config_{0}.xml" -f (Get-Date -Format 'yyyy_MMM_dd_HH_mm_ss'))	
    $NewConfigXmlPath = Join-Path $env:temp $ConfigXmlName
    $CurrentConfigXml.Save($NewConfigXmlPath)
	
    #Validate build path
    if (-not ($SetupExePath.EndsWith("setup.exe")))
    {
        Write-Verbose "Looks like your setup.exe path doesn't end in setup.exe, appending it for you"
        $SetupExePath = Join-Path -Path $SetupExePath -ChildPath "setup.exe"
    }

    if (-not (Test-Path $SetupExePath))
    {
        throw [System.IO.FileNotFoundException]("Setup Path does not exist: {0}" -f $SetupExePath)
    }

    Write-Verbose ("Installing build from: {0}" -f $SetupExePath)

    #ensure MSI Verbose logging is on
    Enable-VerboseMsiLogging

    #Do I need the sn workaround
    if ($RunSNWorkdaround)
    {
        Disable-OfficeSigningCheck
    }

    #Grab a second copy just in case anything changed.
    Write-Output "Final Bound parameters:" | Out-File $ScriptLog -Append
    Write-Output $MyInvocation.BoundParameters | Out-File $ScriptLog -Append

    #Run Setup
    $SetupArgs = ("/config {0}" -f $NewConfigXmlPath)
	
    $StartTime = [System.DateTime]::Now
    if (!$SkipPreReqInstaller)
    {
        $PreReqSetupExePath = $SetupExePath -replace "setup.exe","PrerequisiteInstaller.exe"
        $PreReqProcessStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $PreReqProcessStartInfo.FileName = $PreReqSetupExePath
        $PreReqProcessStartInfo.Arguments = "/unattended"
        $PreReqProcessStartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized
        $PreReqSetupExe = [System.Diagnostics.Process]::Start($PreReqProcessStartInfo)
        $prstep = 5
        $prvalue = 0
        while (-not ($PreReqSetupExe.HasExited)){
            $CurrentRuntime = [System.DateTime]::Now - $StartTime
            Write-Progress -Activity "Installing Prerequisites..." -PercentComplete ($prvalue+=$prstep) -Status ("Setup has been running for {0}:{1}:{2}" -f $CurrentRuntime.Hours.ToString("00"), $CurrentRuntime.Minutes.ToString("00"), $CurrentRuntime.Seconds.ToString("00"))
    
            if ($prvalue -ge 100) { $prvalue = 0}
                Start-Sleep -Seconds 1
        }
    }
        
    $SetupExe = [System.Diagnostics.Process]::Start($SetupExePath, $SetupArgs)
    $step = 5
    $value = 0

    while (-not ($SetupExe.HasExited)){
        $CurrentRuntime = [System.DateTime]::Now - $StartTime
        Write-Progress -Activity "Installing SharePoint..." -PercentComplete ($value+=$step) -Status ("Setup has been running for {0}:{1}:{2}" -f $CurrentRuntime.Hours.ToString("00"), $CurrentRuntime.Minutes.ToString("00"), $CurrentRuntime.Seconds.ToString("00"))

        if ($value -ge 100) { $value = 0}
            Start-Sleep -Seconds 1
    }
        
    $TimeForSetup = [System.DateTime]::Now - $StartTime

    Write-Verbose $TimeForSetup
    
    #region SetupResult object
    $SetupResult = @"
        using System;
    
        namespace SPModule.setup {
            public class SetupResult {
                public int      ExitCode {get;  set;}
                public TimeSpan SetupDuration {get; set;}
                public String   Message {get; set;}
                public String   SetupExePath {get; set;}
            }
        }
"@
    # Mask any errors if the type has already been loaded
    Add-Type $SetupResult -Language CSharpVersion3 -ErrorAction SilentlyContinue 
    #endregion
    
    $Result = New-Object SPModule.setup.SetupResult

    $Result.ExitCode = $SetupExe.ExitCode
    $Result.SetupDuration = $TimeForSetup
    $Result.SetupExePath = $SetupExePath
    
    if ($Result.ExitCode -eq 0)
    {
        Write-Verbose "Installation was sucessful"
        
        $Result.Message = "Installation Sucessful"
    
        $Result | Out-File $ScriptLog -Append
    
        $Result 
    }
    else 
    {
        # Find the newest setup log and show the error.
        $SetupLogPath = [System.Environment]::ExpandEnvironmentVariables($CurrentConfigXml.Configuration.Logging.Path) 
        $SetupLogTemplate = $CurrentConfigXml.Configuration.Logging.Template

        $SetupLogFile = Get-ChildItem -Path $SetupLogPath | ? { $_.Name -like $SetupLogTemplate } | Sort-Object LastWriteTime | Select -Last 1

        [String]$SetupLog = Get-Content $SetupLogFile.FullName

        if ($SetupLog -match "Title: 'Setup is unable to proceed due to the following error\(s\):', Message: '(?<SetupError>.*)'")
        {
            $Result.Message = $matches.SetupError
            $Result | Out-File $ScriptLog -Append
            Write-Error ("Installation Error: {0} Exit Code {1}." -f $Result.Message, $Result.ExitCode) 
        }
        # Try to find a dialog error
        elseif ($SetupLog -match "Title: 'Setup Error', Message: '(?<SetupError>.*)'|Title: 'Setup Errors', Message: '(?<SetupError>.*)'|Title: 'Setup Warning', Message: '(?<SetupError>.*)'")
        {
            $Result.Message = $matches.SetupError
            $Result | Out-File $ScriptLog -Append
            Write-Error ("Installation Error: {0} Exit Code {1}." -f $Result.Message, $Result.ExitCode) 
        }
        # Try to find an exception error
        elseif ($setuplog -match "Error: (?<SetupError>.*\.\s\s) Error:")
        {
            $Result.Message = $matches.SetupError
            $Result | Out-File $ScriptLog -Append 
            Write-Error ("Installation Error: {0} Exit Code {1}." -f $Result.Message, $Result.ExitCode) 
        } 
        else
        {
            $Result.Message = ("Could not find setup error, please check log at {0}. Exit Code {1}." -f $SetupLogFile.FullName, $Result.ExitCode)
            $Result | Out-File $ScriptLog -Append
            Write-Error ("Could not find setup error, please check log at {0}. Exit Code {1}." -f $SetupLogFile.FullName, $Result.ExitCode)
        }
        throw
    }
}