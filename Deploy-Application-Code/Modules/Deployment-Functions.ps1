function Backup-Solutions {
    param( 
        [Xml.XmlElement] $config
    )

    Log-Step -step ("Backup-SPSolutions -path {0}" -f $config.BackupPath)
    Backup-SPSolutions -backup $config.BackupPath
}


#Deploy Functions
function Deploy-Solutions {
    param( 
        [Xml.XmlElement] $config
    )

    Log-Step -step ("$deploy_solutions -web_application {0} -deploy_directory {1} -noupgrade" -f $config.Url, $config.Source)
    Log-Step -step ("$deploy_configs -operation backup -url {0}" -f $config.Url)
    if ([bool]$WhatIfPreference.IsPresent) { return }

    Get-SPWebApplication $config.url -EA Silentlycontinue | Out-Null
    if ( !$? ) {
        throw ("Could not find " + $config.url + " this SharePoint farm. Are you sure you're on the right one?")
        exit
    }

    Set-Location ( Join-Path -Path $app_home -Child "ScriptBlocks" )
    &$deploy_solutions -web_application $config.url -deploy_directory $config.Source -noupgrade
    &$deploy_configs -operation backup -url $config.url				
}

function Deploy-Config {
    param( 
        [Xml.XmlElement] $config
    )

    Log-Step -step ("$deploy_configs -operation deploy -url {0}" -f $config.Url)
    if ([bool]$WhatIfPreference.IsPresent) { return }

    Set-Location ( Join-Path -Path $app_home -Child "ScriptBlocks" )
    &$deploy_configs -operation deploy -url $config.Url 
}

function Update-Configs {
    param( 
        [Xml.XmlElement] $config
    )

    Log-Step -step ("$update_configs -config_filepath {0} -config_updates {1}" -f $config.ConfigPath, $config.ConfigUpdates)
    if ([bool]$WhatIfPreference.IsPresent) { return }
    
    Set-Location ( Join-Path -Path $app_home -Child "ScriptBlocks" )
    &$update_configs  -config_filepath $config.ConfigPath -config_updates $config.ConfigUpdates
    
}

function Enable-Features {
    param( 
        [Xml.XmlElement] $config
    )

    Log-Step -step ("$enable_features -webApp {0} -features {1}" -f $config.Url, $config.Features)
    if ([bool]$WhatIfPreference.IsPresent) { return }

    Set-Location ( Join-Path -Path $app_home -Child "ScriptBlocks" )
    powershell.exe -NoProfile -Command $enable_features -webApp $config.Url	-features $config.Features 
}

function Install-MSIFile {
    param( 
        [Xml.XmlElement] $config
    )

    if ([bool]$WhatIfPreference.IsPresent) {
        Log-Step -step ("Install all MSIs located in {0}" -f $config.Source) 
        return 
    }
    	
    foreach ( $msi in (Get-ChildItem $config.Source -Filter *.msi) ) {
        Log-Step -step ("Installing MSI - " + $msi.FullName )
        Start-Process -FilePath msiexec.exe -ArgumentList /i, $msi.FullName -Wait  
    } 
}

function Uninstall-MSIFile {
    param( 
        [Xml.XmlElement] $config
    )

    $uninstall_file = (Join-Path $config.Source "uninstall.txt") 
   
    if ([bool]$WhatIfPreference.IsPresent) {
        Log-Step -step ("Uninstall all MSIs located in {0}\uninstall.txt" -f $config.Source) 
        return 
    }

    if ( !( Test-Path $uninstall_file )) {
        throw "Could not file the file that contains the MSIs to uninstall at $uninstall_file"
        return
    } 
	
    foreach ( $id in (Get-Content $uninstall_file) ) { 
        Log-Step -step ("Removing MSI with ID - " + $id  )
        Start-Process -FilePath msiexec.exe -ArgumentList /x, $id, /qn -Wait  
    } 
}

function Sync-Files {
    param( 
        [Xml.XmlElement] $config
    )

    $servers = $config.DestinationServers.Split(",")
    Log-Step -step ("Executed on {0} - (Join-Path $ENV:SCRIPTS_HOME Sync\Sync-Files.ps1) -src {1} -dst {2}  -verbose -logging" -f $config.DestinationServers, $config.Source, $config.DestinationPath)
    if ([bool]$WhatIfPreference.IsPresent) { return }
    Invoke-Command -Computer $servers `
        -Authentication CredSSP `
        -Credential (Get-Creds) `
        -ScriptBlock $sync_file_script_block 
    -ArgumentList $config.Source, $config.DestinationPath, $global:log_file 
}

function DeployTo-GAC {
    param( 
        [Xml.XmlElement] $config
    )

    Log-Step -step ("Executed on $servers - $gac_script_block -src {0}" -f $config.Source)
    if ([bool]$WhatIfPreference.IsPresent) { return }

    $servers = Get-SPServers -type "Microsoft SharePoint Foundation Web Application"
    Invoke-Command -Computer $servers -Authentication CredSSP -Credential (Get-Creds)-ScriptBlock $gac_script_block -ArgumentList $config.Source
}

function Cycle-IIS {
    param( 
        [Xml.XmlElement] $config
    )

    Log-Step -step "Invoke-Command -Computer $servers -ScriptBlock $iisreset_script_block" 
    if ([bool]$WhatIfPreference.IsPresent) { return }

    $servers = Get-SPServers
    Invoke-Command -Computer $servers -ScriptBlock $iisreset_script_block
}

function Cycle-Timer {
    param( 
        [Xml.XmlElement] $config
    )

    Log-Step -step "Invoke-Command -Computer $servers -ScriptBlock $sptimer_script_block"
    if ([bool]$WhatIfPreference.IsPresent) { return }

    $servers = Get-SPServers
    Invoke-Command -Computer $servers -ScriptBlock $sptimer_script_block
}

function Deploy-SSRSReport {
    param( 
        [Xml.XmlElement] $config
    )
    
    if ([bool]$WhatIfPreference.IsPresent) {
        Log-Step -step ("Publish all Reports located at {0}" -f $config.Source) 
        return 
    }

    $SSRS_WebService = $config.WebService
    foreach ( $report in ( Get-ChildItem $config.Source | Where { $_.Extension -eq ".rdl" } ) ) {
        Log-Step -step ("Install-SSRSRDL {0} {1} -reportFolder {2} -force" -f $SSRS_WebService, $report.FullName, $config.ReportFolder )
        Install-SSRSRDL $SSRS_WebService $report.FullName -reportFolder $config.ReportFolder -force
    }

}

function Execute-ManualScriptBlock {
    param( 
        [Xml.XmlElement] $config
    )

    if ([bool]$WhatIfPreference.IsPresent) { 
        Log-Step -step ("Execute Manual Script Block at {0}" -f $config.Source) 
        return
    }

    if ( (Test-Path $config.Source) ) {
        $script_block_text = Get-Content $config.Source | Out-String
        $script_block = [scriptblock]::Create($script_block_text)
        Log-Step -step ("Manual Powershell Scriptblock - {0}" -f $script_block_text) 
        &$script_block
    }
}

function Validate-Environment {
    param( 
        [Xml.XmlElement] $config
    )

    Log-Step -step ("$validate_environment -cfg {0} -SaveReply" -f $config.Rules)
    if ([bool]$WhatIfPreference.IsPresent) { return }

    Set-Location ( Join-Path $ENV:SCRIPTS_HOME "Validate-URLs" )
    &$validate_environment -cfg $config.Rules -SaveReply
}

function Pause-Deploy {
    param( 
        [Xml.XmlElement] $config
    )

    Log-Step -step ("Pausing the deploy for {0} seconds" -f $config.Seconds)
    if ([bool]$WhatIfPreference.IsPresent) { return }

    if ( [Convert]::ToInt32($config.Seconds) -eq -1 ) { 
        Write-Host "Press any key to continue. CTRL-C to exit ..."
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    else {
        Start-Sleep -Seconds $config.Seconds
    }
}