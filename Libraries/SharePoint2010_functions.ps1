Add-PSSnapin Microsoft.SharePoint.PowerShell –erroraction SilentlyContinue

# ===================================================================================
# Func: Set-WebAppUserPolicy
# AMW 1.7.2
# Desc: Set the web application user policy
# Refer to http://technet.microsoft.com/en-us/library/ff758656.aspx
# Updated based on Gary Lapointe example script to include Policy settings 18/10/2010
# ===================================================================================
Function Set-WebAppUserPolicy($wa, $userName, $displayName, $perm) 
{
    [Microsoft.SharePoint.Administration.SPPolicyCollection]$policies = $wa.Policies
    [Microsoft.SharePoint.Administration.SPPolicy]$policy = $policies.Add($userName, $displayName)
    [Microsoft.SharePoint.Administration.SPPolicyRole]$policyRole = $wa.PolicyRoles | where {$_.Name -eq $perm}
    If ($policyRole -ne $null) {
        $policy.PolicyRoleBindings.Add($policyRole)
    }
    $wa.Update()
}

#http://autospinstaller.codeplex.com/
Function Configure-ObjectCache( [string] $url, [string]$superuser)
{
	Try
	{
		$wa = Get-SPWebApplication $url
		# If the web app is using Claims auth, change the user accounts to the proper syntax
		If ($wa.UseClaimsAuthentication -eq $true) 
		{
			$SuperUserAcc = 'i:0#.w|' + $superuser
			$SuperReaderAcc = 'i:0#.w|' + $superuser
		}
		Write-Host -ForegroundColor White " - Applying object cache accounts to `"$url`"..."
        $wa.Properties["portalsuperuseraccount"] = $SuperUserAcc
	    Set-WebAppUserPolicy $wa $SuperUserAcc "Super User (Object Cache)" "Full Control"
        $wa.Properties["portalsuperreaderaccount"] = $SuperReaderAcc
	    Set-WebAppUserPolicy $wa $SuperReaderAcc "Super Reader (Object Cache)" "Full Read"
        $wa.Update()        
    	Write-Host -ForegroundColor White " - Done applying object cache accounts to `"$url`""
	}
	Catch
	{
		$_
		Write-Warning " - An error occurred applying object cache to `"$url`""
	}
}

function Audit-SharePointWebApplications
{
	$webAppSettings = @()
	
	get-SPWebApplication | % {
		$webApp = $_.Name
		$appPoolName = $_.ApplicationPool.DisplayName
		$appPoolUser = $_.ApplicationPool.UserName
		
		$iisSettings = ($_.IisSettings)
		
		$_.AlternateUrls | % {
			$webAppSetting = New-Object System.Object

			$zone = $_.UrlZone

			$zoneSettings = $iisSettings.GetEnumerator() | where { $_.Key -eq $zone }
			if( $zoneSettings -eq $nul ) {
				$zoneSettings = $iisSettings.GetEnumerator() | where { $_.Key -eq "Default" }
			}

			$webAppSetting | add-member -type NoteProperty -name WebApplication -Value $webApp
			$webAppSetting | add-member -type NoteProperty -name Uri -Value $_.Uri
			$webAppSetting | add-member -type NoteProperty -name UrlZone -Value $_.UrlZone
			$webAppSetting | add-member -type NoteProperty -name AppPoolName -Value $appPoolName
			$webAppSetting | add-member -type NoteProperty -name AppPoolUser -Value $AppPoolUser
			$webAppSetting | add-member -type NoteProperty -name IISName -Value $zoneSettings.Value.ServerComment
			$webAppSetting | add-member -type NoteProperty -name IISPath -Value ($zoneSettings.Value.Path).FullName
			$webAppSetting | add-member -type NoteProperty -name IISId -Value $zoneSettings.Value.PreferredInstanceId
			$webAppSetting | add-member -type NoteProperty -name AnonymousEnabled -Value $zoneSettings.Value.AllowAnonymous
			$webAppSetting | add-member -type NoteProperty -name ClientIntegrated  -Value $zoneSettings.Value.EnableClientIntegration
			$webAppSetting | add-member -type NoteProperty -name Kerberos  -Value (-not $zoneSettings.Value.DisableKerberos )
			$webAppSetting | add-member -type NoteProperty -name AuthenticationMode -value $zoneSettings.Value.AuthenticationMode

			$webAppSettings += $webAppSetting

		}
	}
	
	return $webAppSettings
}

function Get-StartedServices
{
	Get-SPServer | % {
		$server = $_.Address
		$_.ServiceInstances | where { $_.Status -eq "Online" } | Select @{Name="System";Expression={$server}}, @{Name="Service";Expression={$_.TypeName}}
	}
}

function Set-DeveloperDashboard( [string] $level, [Boolean] $enabled )
{
	$dash =[Microsoft.SharePoint.Administration.SPWebService]::ContentService.DeveloperDashboardSettings
	$dash.DisplayLevel = $level
	$dash.TraceEnabled = $true
	$dash.Update()
}