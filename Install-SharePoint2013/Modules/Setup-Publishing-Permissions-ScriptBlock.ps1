param (
	[string] $id,
	[string[]] $users
)

Add-PSSnapin Microsoft.SharePoint.Powershell -EA SilentlyContinue

$service_apps_perms_map = @()
@("Application Load Balancer", "Search Service Application")  | % {
	$service_apps_perms_map += (New-Object PSObject -Property @{
		Name = $_
		Id = $id
		Perms = "Full Control"
	})
}
$service_apps_perms_map += (New-Object PSObject -Property @{
	Name = "Managed Metadata Service Application"
	Id = $id
	Perms = "Full Access to Term Store"
})
$users | % { 
	$service_apps_perms_map += (New-Object PSObject -Property @{
		Name = "User Profile Service Application" 
		Id = $_
		Perms = "Full Control"
	})
}

$provider = (Get-SPClaimProvider System).ClaimProvider
foreach( $service_app in $service_apps_perms_map )
{
	Write-Host "[ $(Get-Date) ] - Setting permissions for -" $service_app.Name "- with permissions -" $service_app.Perms "- for account/farm -" $service_app.Id
	if( $service_app.Name -match "Application Load Balancer" ) {
		$app = Get-SPTopologyServiceApplication
	}
	else {
		$app = Get-SPServiceApplication | where { $_.Name -eq $service_app.Name }
	}
	
	if( $app -ne $null ) {
		$security = $app | Get-SPServiceApplicationSecurity
		if( $service_app.Name -match "User Profile" ) {
			$principal = New-SPClaimsPrincipal -IdentityType WindowsSamAccountName -Identity $service_app.Id
		} 
		else {
			$principal = New-SPClaimsPrincipal -ClaimType "http://schemas.microsoft.com/sharepoint/2009/08/claims/farmid" -ClaimProvider $provider -ClaimValue $service_app.Id
		}
	
		Grant-SPObjectSecurity -Identity $security -Principal $principal -Rights $service_app.Perms
		$app | Set-SPServiceApplicationSecurity -ObjectSecurity $security
	} 
	else {
		Write-Host "Could not find Service Application - " $service_app.Name -ForegroundColor Red
	}
}