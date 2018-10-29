Set-Variable -Name nr_api_key -Value "" -Option Constant
Set-Variable -Name nr_account_id -Value "" -Option Constant
Set-Variable -Name nr_web_config_key -Value "NewRelic.AppName" -Option Constant

$nr_urls = New-Object PSObject -Property @{
    Applications = "https://api.newrelic.com/v2/applications.xml"
    Application  = "https://api.newrelic.com/v2/applications/{0}.xml"
    Deployment   = "https://api.newrelic.com/deployments.xml"
    Servers      = "https://api.newrelic.com/v2/servers.xml"
    Server       = "https://api.newrelic.com/v2/servers/{0}.xml"
}

$nr_output = New-Object PSObject -Property @{
    Deployment = "[{0}] - Deployment for {1} ({2}) by {3}"
}

$nr_error_data = New-Object PSObject -Property @{   
    NoAppName    = "No New Relic Application was found of Name : {0}."
    NoAppId      = "No New Relic Application was found of ID : {0}."
    NoServerId   = "No New Relic Server was found of ID : {0}."
    NoAppSetting = "Could not find {0} in {1} web.config's AppSettings."
}

function Get-NewRelicWebClient {
    $web_client = New-Object System.Net.WebClient
    $web_client.Headers.Add("x-api-key", $nr_api_key)
    return $web_client
}

function Get-NewRelicApplications {
    $wc = Get-NewRelicWebClient
    $apps = [xml] $wc.DownloadString($nr_urls.Applications)
    
    $nr_apps = @()
    foreach ($application in $apps.applications_response.applications.application) {
        $nr_apps += (New-Object PSObject -Property @{
                Name         = $application.Name
                ID           = $application.id
                Status       = $application.Health_Status
                Reporting    = $application.Reporting
                LastReported = $application.last_reported_at
            })
    }
    
    return $nr_apps
}

function Get-NewRelicApplication {
    param(
        [Parameter(ParameterSetName = "Name", Mandatory = $true)]
        [string] $name,

        [Parameter(ParameterSetName = "ID", Mandatory = $true)]
        [int] $id,

        [Parameter(ParameterSetName = "Object", Mandatory = $true, ValueFromPipeline = $true)]
        [System.Management.Automation.PSObject] $app
    )

    begin { 
        $nr_app_details = @()
    }

    process {
        if ($PsCmdlet.ParameterSetName -eq "Name") {
            $id = Get-NewRelicApplications | Where { $_.Name -eq $Name } | Select -ExpandProperty Id

            if (!$id) {
                throw ($nr_error_data.NoAppName -f $name)
            }
        }
        elseif ($PsCmdlet.ParameterSetName -eq "Object" ) {
            $id = $app.Id
        }

        $wc = Get-NewRelicWebClient
        $response = [xml] $wc.DownloadString($nr_urls.Application -f $id)

        if (!$response) {
            throw ($nr_error_data.NoAppId -f $id)
        }

        $nr_app_details += (New-Object PSObject -Property @{
                Name         = $response.application_response.application.Name
                ID           = $response.application_response.application.id
                Status       = $response.application_response.application.Health_Status
                Reporting    = $response.application_response.application.Reporting
                LastReported = $response.application_response.application.last_reported_at
                ResponseTime = $response.application_response.application.application_summary.response_time
                ApdexScore   = $response.application_response.application.application_summary.apdex_score
                ApdexTarget  = $response.application_response.application.application_summary.apdex_target
                ErrorRate    = $response.application_response.application.application_summary.error_rate
                ServerIds    = @($response.application_response.application.links.servers.server)
            })
    }
    end {
        return $nr_app_details
    }
}

function Get-NewRelicServers {
    $wc = Get-NewRelicWebClient
    $servers = [xml] $wc.DownloadString($nr_urls.Servers)
    
    $nr_servers = @()
    foreach ($server in $servers.servers_response.servers.server) {
        $nr_servers += (New-Object PSObject -Property @{
                Name         = $server.Name
                ID           = $server.id
                Reporting    = $server.Reporting
                LastReported = $server.last_reported_at
            })
    }
    
    return $nr_servers

}

function Get-NewRelicServer {
    param(
        [Parameter(ParameterSetName = "Name", Mandatory = $true)]
        [string] $name,

        [Parameter(ParameterSetName = "ID", Mandatory = $true)]
        [int[]] $ids,

        [Parameter(ParameterSetName = "Object", Mandatory = $true, ValueFromPipeline = $true)]
        [System.Management.Automation.PSObject] $app
    )

    begin { 
        $nr_server_details = @()
    }

    process {
        if ($PsCmdlet.ParameterSetName -eq "Name") {
            $ids = @(Get-NewRelicServers | Where { $_.Name -eq $Name } | Select -ExpandProperty Id)

            if (!$ids) {
                throw ($nr_error_data.NoAppName -f $name)
            }
        }
        elseif ($PsCmdlet.ParameterSetName -eq "Object" ) {
            $ids = @(Get-NewRelicApplication -id $app.Id | Select -Expand ServerIds)
        }

        $wc = Get-NewRelicWebClient

        foreach ( $id in $ids) {
            $response = [xml] $wc.DownloadString($nr_urls.Server -f $id)

            if (!$response) {
                throw ($nr_error_data.NoServerId -f $id)
            }

            $nr_server_details += (New-Object PSObject -Property @{
                    Name                = $response.server_response.server.Name
                    ID                  = $response.server_response.server.id
                    Reporting           = $response.server_response.server.Reporting
                    LastReported        = $response.server_response.server.last_reported_at
                    CPU                 = $response.server_response.server.summary.CPU
                    IO                  = $response.server_response.server.summary.disk_io
                    MemoryUsedByPercent = $response.server_response.server.summary.memory
                })
        }
    }
    end {
        return $nr_server_details
    }
}

function Get-NewRelicAppName {
    param (
        [Parameter(Mandatory = $true)]
        [string] $iis_site_name
    )

    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1" )

    Set-Variable -Name nr_app_name -Value ([string]::Empty)

    $config = [xml](Get-Content -Path (Get-WebConfigFile ("IIS:\Sites\{0}" -f $iis_site_name) | Select -Expand FullName ))
    $nr_app_name = $config.configuration.appSettings.add | 
        Where { $_.Key -eq $nr_web_config_key } | 
        Select -ExpandProperty Value

    if ( [String]::IsNullOrEmpty($nr_app_name) ) {
        throw ( $nr_error_data.NoAppSetting -f $nr_web_config_key, $iis_site_name )
    }

    return $nr_app_name
}

function Set-NewRelicDeploymentMarker {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $iis_site_name
    )
   
   	$app_id = Get-NewRelicApplications | 
        Where { $_.Name -eq (Get-NewRelicAppName -iis_site_name $iis_site_name) } |
        Select -Expand ID
	
    if ( $app_id -eq $null ) {
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


Export-ModuleMember -Function Set-NewRelicDeploymentMarker, Get-NewRelicApplications, Get-NewRelicApplication, Get-NewRelicAppName, Get-NewRelicServers, Get-NewRelicServer