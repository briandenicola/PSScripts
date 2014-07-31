Set-Variable -Name nr_api_key -Value "" -Option Constant
Set-Variable -Name nr_account_id -Value "" -Option Constant

Set-Variable -Name nr_url_apps -Value "https://api.newrelic.com/api/v1/accounts/{0}/applications.xml" -Option Constant
Set-Variable -Name nr_url_deploy -Value "https://api.newrelic.com/deployments.xml" -Option Constant
Set-Variable -Name nr_web_config_key -Value "NewRelic.AppName" -Option Constant
Set-Variable -Name nr_deploy_description  -Value "[{0}] - Deployment for {1} ({2}) by {3}"

function Get-NewRelicApplications
{
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("x-api-key", $nr_api_key)
    $apps = [xml] $wc.DownloadString($nr_url_apps -f $nr_account_id)
    
    $nr_apps = @()
    foreach ($application in $apps.applications.application)
    {
	    $nr_apps += (New-Object PSObject -Property @{
            Name = $application.Name
            ID = $application.Id.'#text'
            Url = $application.'OverView-Url'
        })
    }
    
    return $nr_apps
}

function Get-NewRelicAppName
{
    param (
        [Parameter(Mandatory=$true)]
        [string] $iis_site_name
    )

    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1" )

    Set-Variable -Name nr_app_name -Value ([string]::Empty)

    $config = [xml](Get-Content -Path (Get-WebConfigFile ("IIS:\Sites\{0}" -f $iis_site_name) | Select -Expand FullName ))
    $nr_app_name = $config.configuration.appSettings.add | 
                Where { $_.Key -eq $nr_web_config_key } | 
                Select -ExpandProperty Value

    return $nr_app_name
}

function Set-NewRelicDeploymentMarker
{
    Param(
        [Parameter(Mandatory=$true)]
	    [string] $iis_site_name
    )
   
   	$app_id = Get-NewRelicApplications | 
		Where { $_.Name -eq (Get-NewRelicAppName -iis_site_name $iis_site_name) } |
		Select -Expand ID
	
   	$wc = new-object system.net.WebClient 
    $wc.Headers.Add("x-api-key", $nr_api_key)

   	$deployment_info = new-object System.Collections.Specialized.NameValueCollection 
	$deployment_info.Add("application_id", $app_id ) 
	$deployment_info.Add("description", ($nr_deploy_description -f $(Get-Date), $iis_site_name, $app_id, $ENV:USERNAME) )
	$deployment_info.Add("user", ("{0}\{1}" -f $env:USERDOMAIN, $ENV:USERNAME ) ) 
	$result = $wc.UploadValues($nr_url_deploy, "POST", $deployment_info) 

    return ( [System.Text.Encoding]::ASCII.GetString($result) )

}


Export-ModuleMember -Function Set-NewRelicDeploymentMarker, Get-NewRelicApplications, Get-NewRelicAppName