# .SYNOPSIS
#
# Set-SiteMailboxConfig helps configure Site Mailboxes for a SharePoint farm
#
# .DESCRIPTION
#
# Establishes trust with an Exchange Server, sets Site Mailbox settings and enables Site Mailboxes for a farm.
#
# .PARAMETER ExchangeSiteMailboxDomain
#
# The FQDN of the Exchange Organization where Site Mailboxes will be created
#
# .PARAMETER ExchangeAutodiscoverDomain
#
# [Optional] The FQDN of an Exchange Autodiscover Virtual Directory
#
# .PARAMETER WebApplicationUrl
#
# [Optional] The URL of a specific web application to configure. If not specified all Web Applications will be configured
#
# .PARAMETER Force
#
# [Optional] Indicate that the script should ignore any configuration issues and enable Site Mailboxes anyway
#

Param
(
   [Parameter(Mandatory=$true)]
   [ValidateNotNullOrEmpty()]   
   [string]$ExchangeSiteMailboxDomain,
   [Parameter(Mandatory=$false)]
   [ValidateNotNullOrEmpty()]   
   [string]$ExchangeAutodiscoverDomain,
   [Parameter(Mandatory=$false)]
   [ValidateNotNullOrEmpty()]   
   [string]$WebApplicationUrl,
   [Parameter(Mandatory=$false)]
   [switch]$Force
)

$script:currentDirectory = Split-Path $MyInvocation.MyCommand.Path

if($WebApplicationUrl -ne $NULL -and $WebApplicationUrl -ne "")
{
    $webapps = Get-SPWebApplication $WebApplicationUrl
}
else
{
    $webapps = Get-SPWebApplication
}

if($webapps -eq $NULL)
{
    if($WebApplicationUrl -ne $NULL)
    {
        Write-Warning "No Web Application Found at $($WebApplicationUrl). Please create a web application and re-run Set-SiteMailboxConfig"
    }
    else
    {
        Write-Warning "No Web Applications Found. Please create a web application and re-run Set-SiteMailboxConfig"
    }
    
    return
}

$rootWeb = $NULL

foreach($webapp in $webapps)
{
    if($rootWeb -eq $NULL)
    {
        $rootWeb = Get-SPWeb $webApp.Url -EA SilentlyContinue
    }
}

if($rootWeb -eq $NULL)
{
    Write-Warning "Unable to find a root site collection. Please create a root site collection on a web application and re-run Set-SiteMailboxConfig"
    return
}

$exchangeServer = $ExchangeAutodiscoverDomain

if($exchangeServer -eq $NULL -or $exchangeServer -eq "")
{
    $exchangeServer = "autodiscover.$($ExchangeSiteMailboxDomain)"
}

Write-Host "Establishing Trust with Exchange Server: $($exchangeServer)"

$metadataEndpoint = "https://$($exchangeServer)/autodiscover/metadata/json/1"

$exchange = Get-SPTrustedSecurityTokenIssuer | Where-Object { $_.MetadataEndpoint -eq $metadataEndpoint }

if($exchange -eq $NULL)  
{
    $exchange = New-SPTrustedSecurityTokenIssuer -Name $exchangeServer -MetadataEndPoint $metadataEndpoint
}

if($exchange -eq $NULL)
{
    Write-Warning "Unable to establish trust with Exchange Server $($exchangeServer). Ensure that $($metadataEndpoint) is accessible."

    if($ExchangeAutodiscoverDomain -eq $NULL -or $ExchangeAutodiscoverDomain -eq "")
    {
        Write-Warning "If $($metadataEndpoint) does not exist you may specify an alternate FQDN using ExchangeAutodiscoverDomain."
    }
    return
}

Write-Host "Granting Permissions to Exchange Server: $($exchangeServer)"
$appPrincipal = Get-SPAppPrincipal -Site $rootWeb.Url -NameIdentifier $exchange.NameId
Set-SPAppPrincipalPermission -AppPrincipal $appPrincipal -Site $rootWeb -Scope SiteSubscription -Right FullControl -EnableAppOnlyPolicy

Write-Host
Write-Host

Write-Host "Verifying Site Mailbox Configuration"
$warnings = & $script:currentDirectory\Check-SiteMailboxConfig.ps1 -ReturnWarningState

if($warnings -and -not $Force)
{
    Write-Warning "Pre-requisites not satisfied. Stopping Set-SiteMailboxConfig. Use -Force to override"
    return
}
elseif($warnings)
{
    Write-Warning "Pre-requisites not satisfied. -Force used to override"
}

foreach($webapp in $webapps)
{
    Write-Host "Configuring Web Application: $($webapp.Url)"
    Write-Host "Setting Exchange Site Mailbox Domain to $($ExchangeSiteMailboxDomain)"
    $webapp.Properties["ExchangeTeamMailboxDomain"] = $ExchangeSiteMailboxDomain
        
    if($ExchangeAutodiscoverDomain -ne $NULL -and $ExchangeAutodiscoverDomain -ne "")
    {
        Write-Host "Setting Exchange Autodiscover Domain to $($ExchangeAutodiscoverDomain)"
        $webapp.Properties["ExchangeAutodiscoverDomain"] = $ExchangeAutodiscoverDomain;
    }

    $webapp.Update()
}

$feature = Get-SPFeature CollaborationMailboxFarm -Farm -ErrorAction Ignore

if($feature -eq $NULL)
{
    Write-Host "Enabling Site Mailboxes for Farm"
    Enable-SPFeature CollaborationMailboxFarm
}
else
{
    Write-Host "Site Mailboxes already enabled for Farm"
}