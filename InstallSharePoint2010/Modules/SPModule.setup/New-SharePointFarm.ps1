function New-SharePointFarm
{
    <#
    .Synopsis
        Creates a farm
    .Description
        Creates a farm using the provided parameters
    .Example
        New-SharePointFarm -DatabaseAccessAccount (Get-Credential DOMAIN\username) -DatabaseServer SQL01\instancename -FarmName TestFarm
    .Parameter DatabaseAccessAccount
        The farm account.  This needs to be in the form of a PSCredential object.
	.Parameter DatabaseServer
        The SQL server name
	.Parameter Passphrase
        The secret string that must be used to add servers to the farm.
	.Parameter AdminAuthMethod
        The authentication method for the central admin site
	.Parameter FarmName
        The name of the farm
    .Link
        Install-SharePoint
        Join-SharePointFarm
	#>
    [CmdletBinding()]
    param 
    (    
        [Parameter(Mandatory=$true)][ValidateNotNull()]
        [System.Management.Automation.PSCredential]$DatabaseAccessAccount,
        
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]
        [String]$DatabaseServer,
        
        [Parameter(Mandatory=$false)][ValidateScript({$_.Length -ne 0})]
        [System.Security.SecureString]$Passphrase,
        
        [Parameter(Mandatory=$false)][ValidateRange(1024, 65535)]
        [int]$Port = "10000",
        
        [Parameter(Mandatory=$false)][ValidateSet("NTLM", "Kerberos")]
        [String]$AdminAuthMethod = "NTLM",
        
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]
        [String]$FarmName = $env:COMPUTERNAME
    )
    
    Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction "SilentlyContinue" | Out-Null
        
    $ErrorActionPreference = "Stop"
    
    if ($Verbose -eq $null) { $Verbose = $false }
    
    $Activity = "Creating SharePoint Farm"
    $ScriptLog = ("$env:TEMP\New-SharePointFarm_{0}.ps1.log" -f (Get-Date -Format 'dd_MMM_yyyy_HH_mm_ss'))
   
	Write-Output "Initial Bound parameters:" | Out-File $ScriptLog -Append
	Write-Output $MyInvocation.BoundParameters | Out-File $ScriptLog -Append   
    
    #region Settings Object
    $FarmInfoSettings = @"
        using System;
        namespace SPModule.setup {
            public class CreateFarmInformation {
                public DateTime StartTime {get; set;}
				public TimeSpan TotalTime {get; set; }
                public String   DatabaseAccessUser {get; set;}
                public String   DatabaseAccessPassword {get; set;}
                public String   DatabaseServer {get; set;}
                public String   FarmPassphrase {get; set;}
                public String   ConfigurationDatabaseName {get; set;}
                public String   AdminDatabaseName {get; set;}
                public int      AdminPort {get; set;}
				public String   CommandLine {get; set;}
            }
        }
"@
    Add-Type $FarmInfoSettings -Language CSharpVersion3
    #endregion 
    
    $RunSettings = New-Object SPModule.setup.CreateFarmInformation
    
    $RunSettings.StartTime = Get-Date -Format 'dd-MMM-yyyy HH:mm:ss'
    $RunSettings.DatabaseAccessUser = $DatabaseAccessAccount.UserName
    $RunSettings.DatabaseAccessPassword = (ConvertFrom-SecureString $DatabaseAccessAccount.Password)
    $RunSettings.DatabaseServer = $DatabaseServer
    $RunSettings.ConfigurationDatabaseName = ("{0}_SharePoint_Configuration_Database" -f $FarmName)
    $RunSettings.AdminDatabaseName = ("{0}_SharePoint_Administration_Content_Database" -f $FarmName)
    $RunSettings.AdminPort = $Port
	$RunSettings.CommandLine = $MyInvocation.Line
	

    if (($Passphrase.Length -eq 0) -or ($Passphrase -eq $null))
    {
        $Passphrase = $DatabaseAccessAccount.Password
    }
    
    $RunSettings.FarmPassphrase = (ConvertFrom-SecureString $Passphrase)
    
    $RunSettings | Out-File $ScriptLog -Append
    
    
    $ErrorActionPreference = "Stop"
    
    try 
    {
        # Create a new config db 
        Write-Progress -Activity $Activity -Status ("Creating new configuration database: {0}..." -f $RunSettings.ConfigurationDatabaseName)
        New-SPConfigurationDatabase -DatabaseServer $DatabaseServer -DatabaseName $RunSettings.ConfigurationDatabaseName -AdministrationContentDatabaseName $RunSettings.AdminDatabaseName -FarmCredentials $DatabaseAccessAccount -Passphrase $Passphrase -Verbose:$Verbose
        if (-not $?) { throw "Failed to create Configuration Database."    }
        
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
        
        #Provision Central Administration
        Write-Progress -Activity $Activity -Status "Provisioning Central Administration..." 
        New-SPCentralAdministration -Port $RunSettings.AdminPort -WindowsAuthProvider $AdminAuthMethod -Verbose:$Verbose
                
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