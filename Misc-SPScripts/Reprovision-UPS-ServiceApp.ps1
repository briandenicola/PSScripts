[CmdletBinding(SupportsShouldProcess=$true)]
param( 
	[string] $server = $ENV:COMPUTERNAME
)

Add-PSSnapin Microsoft.SharePoint.PowerShell -EA SilentlyContinue

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")

$title = "Reprovision UPA"
$message = "Do you want to unprovision User Profile Service Application on " + $server + " ?"

$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Unprovisions UPA and then reprovisions the service application"
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Exits Script"

$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

$continue = $host.ui.PromptForChoice($title, $message, $options, 1) 

if($continue -eq 0)
{
	$sharepoint_farm_account = (Get-SPFarm).DefaultServiceAccount | Select -ExpandProperty Name

	$admins = Get-LocalAdmins -computer $server 
	if( -not $admin -contains $sharepoint_farm_account )
	{
		Write-Host "[" $(Get-Date) "] - Adding $sharepoint_farm_account to Local Administrator Group . . . "
		Add-LocalAdmin -computer $server -group $sharepoint_farm_account.Split("\")[1] 
		Get-LocalAdmins -computer $server
	}
			
	$farm_password = Get-SPManageAccountPassword $sharepoint_farm_account -AsSecureString
	$creds = New-Object System.Management.Automation.PSCredential $sharepoint_farm_account, $farm_password
		
	Invoke-Command -Computer $server -Authentication CredSSP -Credential $creds -ScriptBlock {
		param( 
			[string] $server = $ENV:COMPUTERNAME
		)
		
		Add-PSSnapin Microsoft.SharePoint.PowerShell -EA SilentlyContinue

		$syncdb = Get-SPDatabase | where { $_.Type -eq "Microsoft.Office.Server.Administration.SynchronizationDatabase" }
		
		if( $syncdb -ne $null )
		{
				
			Write-Host "[" $(Get-Date) "] - Stopping sptimerv4 service . . . "
			Stop-Service sptimerv4 
				
			Write-Host "[" $(Get-Date) "] - UnProvisioning SyncDB Database - " $syncdb " . . . "
			$syncdb.Unprovision()
			$syncdb.Status='Offline'

			Write-Host "[" $(Get-Date) "] - Resetting User Profile Service Aplication . . . "
			$upa = Get-SPServiceApplication | where { $_.TypeName -match "User Profile" }
			$upa.ResetSynchronizationMachine()
			$upa.ResetSynchronizationDatabase()

			Write-Host "[" $(Get-Date) "] - Provisioning Databases . . . "
			$syncdb.Provision()

			$i = 0
			do
			{
				Write-Host -NoNewLine "." ;  Sleep 1 ; $i += 1
			} while( $i -le 60 )
			
			Write-Host "[" $(Get-Date) "] - Starting sptimerv4 service . . . "
			Start-Service sptimerv4 
				
			$id = Get-SPServer $server| Get-SPServiceInstance | where { $_.TypeName -match "User Profile Sync" } 
			Write-Host "[" $(Get-Date) "] - Starting Service Instance on $id . . . "
			Start-SPServiceInstance -Identity $id
				
			$i = 0
			do
			{
				Write-Host -NoNewLine "." ; Sleep 1 ; $i += 1
			} while( (Get-SPServiceInstance $id).Status -ne "Online" -and $i -le 300 )

			if( (Get-SPServiceInstance $id).Status -ne "Online" )
			{
				Write-Error "`nUser Profile Sync Service is still offline after 300 seconds. Try starting the service manually and then do an IISRESET . . ."
				Stop-SPServiceInstance -Identity $id -confirm:$false
			}
			else
			{	
				iisreset $server
				Write-Host "`n[" $(Get-Date) "] - UPS Service is Started $server. Connections to " $ENV:USERDOMAIN " now need to be recreated . . . "
			}
		}
		else
		{	
			Write-Host "[" $(Get-Date) "] - Could not find any database of type Microsoft.Office.Server.Administration.SynchronizationDatabase "
		}
	} -ArgumentList $server 
}