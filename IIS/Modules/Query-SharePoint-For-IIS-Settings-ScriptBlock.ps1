param (
    [Parameter(Mandatory=$true)]
    [string] $url,
    [Parameter(Mandatory=$true)]
    [string] $environment,
    [Parameter(Mandatory=$true)]
    [string] $farm
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")

Set-Variable -Name audit -Value  @()

$sp_web_application = Get-SPWebApplication $url -ErrorAction SilentlyContinue

if( $sp_web_application -eq $null ) {
    return @()
}

$web_servers = @(Get-SPServiceInstance | 
                 Where { $_.TypeName -imatch "Web Application" -and $_.Status -eq "Online" } |
                 Select -Expand Server | Select -ExpandProperty Address)

$content_dbs = @($sp_web_application.ContentDatabases | Select -ExpandProperty Name)
$sql_servers = @($sp_web_application.ContentDatabases | Select -ExpandProperty Server | Sort | Select -Unique)

$app_pool_user = $sp_web_application.ApplicationPool.UserName
$app_pool_name = $sp_web_application.ApplicationPool.DisplayName

foreach( $zone in $sp_web_application.IISSettings.Keys ) {

    $zone_settings = $sp_web_application.IISSettings[$zone]
    $public_url = $sp_web_application.AlternateUrls | Where { $_.Zone -eq $zone } | Select -ExpandProperty PublicUrl
    $ip_address = Get-IPAddress ( $public_url -replace "https?://", [String]::Empty )
    $iis_settings = Get-WebSite | Where { $_.Name -eq $zone_settings.ServerComment }

    $audit += (New-Object PSObject -Property @{
        Real_x0020_Servers = [string]::join(";", $web_servers )
        WebApplication = $zone_settings.ServerComment
        UrlZone = $zone
        IISName = $zone_settings.ServerComment
        IISId = $zone_settings.PreferredInstanceId
        IISPath = $zone_settings.Path | Select -Expand FullName
        LogFileDirectory = (Join-Path $iis_settings.LogFile.Directory ("W3SVC" + $zone_settings.PreferredInstanceId))
        Uri = $public_url
        Internal_x0020_IP = $ip_address
        AppPoolName = $app_pool_name
        AppPoolUser = $app_pool_user
        AnonymousEnabled = $zone_settings.AllowAnonymous.ToString() 
        ClientIntegrated = $zone_settings.EnableClientIntegration.ToString() 
        Environment = $environment
        Farm = $farm
        Claims  = $zone_settings.UseClaimsAuthentication.ToString() 
        ClaimsUrl = if( -not [String]::IsNullOrEmpty($zone_settings.ClaimsAuthenticationRedirectionUrl) ) { $zone_settings.ClaimsAuthenticationRedirectionUrl.ToString() } else { [String]::Empty }
        AuthenticationMode = $zone_settings.AuthenticationMode.ToString()
        BrowserFileHandling = $sp_web_application.BrowserFileHandling.ToString()
        AllowDesigner = $sp_web_application.AllowDesigner.ToString()
        WindowsIntegrated = $zone_settings.UseWindowsIntegratedAuthentication.ToString()
        ContentDatabases = [string]::join(";", $content_dbs)
        SQL_x0020_Servers = [string]::join(";", $sql_servers)
    })
    
}

return $audit