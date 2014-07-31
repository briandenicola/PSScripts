Set-Variable -Name nr_api_key -Value "" -Option Constant
Set-Variable -Name nr_account_id -Value "" -Option Constant
Set-Variable -Name nr_web_config_key -Value "NewRelic.AppName" -Option Constant

$nr_urls = New-Object PSObject -Property @{
    Applications ="https://api.newrelic.com/api/v1/accounts/{0}/applications.xml"
    Deployment="https://api.newrelic.com/deployments.xml"
}

$nr_output = ConvertFrom-StringData @'
    Deployment="[{0}] - Deployment for {1} ({2}) by {3}"
'@

$nr_error_data = ConvertFrom-StringData @'    
    NoAppName=No New Relic Application was found of Name : {0}.
    NoAppSetting=Could not find {0} in {1} web.config's AppSettings.
'@

function Get-NewRelicWebClient
{
    $web_client = New-Object System.Net.WebClient
    $web_client.Headers.Add("x-api-key", $nr_api_key)
    return $web_client
}

function Get-NewRelicApplications
{
    $wc = Get-NewRelicWebClient
    $apps = [xml] $wc.DownloadString($nr_url.Applications -f $nr_account_id)
    
    $nr_apps = @()
    foreach ($application in $apps.applications.application)
    {
	    $nr_apps += (New-Object PSObject -Property @{
            Name = $application.Name
            ID = $application.Id.'#text'
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

    if( [String]::IsNullOrEmpty($nr_app_name) ) {
        throw ( $nr_error_data.NoAppSetting -f $nr_web_config_key, $iis_site_name )
    }

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
	
    if( $app_id -eq $null ) {
        throw ( $nr_error_data.NoAppName -f $iis_site_name )
    }

   	$wc = Get-NewRelicWebClient
   	$deployment_info = New-Object System.Collections.Specialized.NameValueCollection 
	$deployment_info.Add("application_id", $app_id ) 
	$deployment_info.Add("description", ($nr_output.Deployment -f $(Get-Date), $iis_site_name, $app_id, $ENV:USERNAME) )
	$deployment_info.Add("user", ("{0}\{1}" -f $env:USERDOMAIN, $ENV:USERNAME ) ) 
	$result = $wc.UploadValues($nr_urls.Deployment, "POST", $deployment_info) 

    return ( [System.Text.Encoding]::ASCII.GetString($result) )

}


Export-ModuleMember -Function Set-NewRelicDeploymentMarker, Get-NewRelicApplications, Get-NewRelicAppName