function Join-SharePointFarm
{
    <#
    .Synopsis
        Joins a farm
    .Description
        This function will join the server to a farm per the specified config database and passphrase.
    .Example
        Join-SharePointFarm –DatabaseServer SQL01\instancename –DatabaseName TestFarm_SharePoint_Configuration_Database
	.Parameter DatabaseServer
        MANDATORY. The database server containing the config_db of the farm.  DEFAULT: N/A   VALID VALUES: <<NOT NULL>>
	.Parameter ConfigurationDatabaseName
        MANDATORY. The name of the config_db.  DEFAULT: N/A   VALID VALUES: <<NOT NULL>>
	.Parameter Passphrase
        MANDATORY. The passphrase used when creating the farm.  DEFAULT: N/A   VALID VALUES: {a string of one or more characters}
    .Link
        Install-SharePoint
        New-SharePointFarm
	#>
		
    [CmdletBinding()]
    param 
    (         
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]
        [String]$DatabaseServer,
		
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]
        [String]$ConfigurationDatabaseName,
        
        [Parameter(Mandatory=$true)][ValidateScript({$_.Length -ne 0})]
        [System.Security.SecureString]$Passphrase
    )
    
    Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction "SilentlyContinue" | Out-Null
        
    $ErrorActionPreference = "Stop"
    
    if ($Verbose -eq $null) { $Verbose = $false }
    
    $Activity = "Joining SharePoint Farm"
    $ScriptLog = ("$env:TEMP\Join-SharePointFarm_{0}.ps1.log" -f (Get-Date -Format 'dd_MMM_yyyy_HH_mm_ss'))
	
    Write-Output "Initial Bound parameters:" | Out-File $ScriptLog -Append
    Write-Output $MyInvocation.BoundParameters | Out-File $ScriptLog -Append
        
    #region Settings Object
    $FarmInfoSettings = @"
        using System;
        namespace SPModule.setup {
            public class JoinFarmInformation {
                public DateTime StartTime {get; set;}
                public TimeSpan TotalTime {get; set;}
                public String   DatabaseServer {get; set;}
                public String   FarmPassphrase {get; set;}
                public String   ConfigurationDatabaseName {get; set;}
                public String   CommandLine {get; set;}
            }
        }
"@
    Add-Type $FarmInfoSettings -Language CSharpVersion3
    #endregion
	
    $RunSettings = New-Object SPModule.setup.JoinFarmInformation
	
    $RunSettings.StartTime = Get-Date -Format 'dd-MMM-yyyy HH:mm:ss'
    $RunSettings.DatabaseServer = $DatabaseServer
    $RunSettings.ConfigurationDatabaseName = $ConfigurationDatabaseName
    $RunSettings.FarmPassphrase = (ConvertFrom-SecureString $Passphrase)
    $RunSettings.CommandLine = $MyInvocation.Line
    
    $RunSettings | Format-List |  Out-File $ScriptLog -Append
    
    
    $ErrorActionPreference = "Stop"
    
    try 
    {
        # Create a new config db 
        Write-Progress -Activity $Activity -Status ("Joining configuration database: {0}..." -f $RunSettings.ConfigurationDatabaseName)
        Connect-SPConfigurationDatabase -DatabaseServer $DatabaseServer -DatabaseName $RunSettings.ConfigurationDatabaseName -Passphrase $Passphrase -Verbose:$Verbose
        if (-not $?) { throw "Failed to join Configuration Database."    }
        
        #install help collections
        Write-Progress -Activity $Activity -Status "Installing Help Collections..." 
        Install-SPHelpCollection -All -Verbose:$Verbose
        if (-not $?) { throw "Failed to install Help Collections."    }
        
        #Secure resources
        Write-Progress -Activity $Activity -Status "Securing SharePoint Resources..."  
        Initialize-SPResourceSecurity -Verbose:$Verbose
        if (-not $?) { throw "Failed to Secure Resources."    }
        
        #Install Services
        Write-Progress -Activity $Activity -Status "Installing Services..." 
        Install-SPService -Verbose:$Verbose
        if (-not $?) { throw "Failed to Install Services."    }
                
        #Install Features
        Write-Progress -Activity $Activity -Status "Installing Features..." 
        $InstalledFeatures = Install-SPFeature -AllExistingFeatures -Verbose:$Verbose
        if (-not $?) { throw "Failed to Install Features."    }
        
        Write-Verbose ("Installed {0} features" -f $InstalledFeatures.Count)
        $InstalledFeatures | Out-File $ScriptLog -Append
        Write-Output ("Installed {0} features" -f $InstalledFeatures.Count) | Out-File $ScriptLog -Append
                        
        #Install Application content
        Write-Progress -Activity $Activity -Status "Installing Application Content..." 
        Install-SPApplicationContent -Verbose:$Verbose
        if (-not $?) { throw "Failed to Install Application Content."    }
        
        $Sucessful = $true
    }
    catch
    {
        Write-Output $_ | Out-File $ScriptLog -Append
        Write-Error $_
		
        throw
    }
    finally
    {
        if ($Sucessful)
        {		
            $TotalTime = [System.DateTime]::Now - $RunSettings.StartTime
            $RunSettings.TotalTime = $TotalTime
			
            $RunSettings | Format-List |  Out-File $ScriptLog -Append
			
            $RunSettings | Select-Object -Property ConfigurationDatabaseName, DatabaseServer, TotalTime | Format-List
        }
		
        Write-Verbose $RunSettings
		
        Remove-PSSnapin Microsoft.SharePoint.Powershell
    }
    
    
}