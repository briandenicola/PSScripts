Param
(
   [Parameter(Mandatory=$false)]
   [ValidateNotNullOrEmpty()]   
   [switch]$ReturnWarningState
)

Add-PSSnapin Microsoft.SharePoint.Powershell

$anyWarnings = $false

Write-Host "Step 1: Checking for Exchange Web Services"

try
{
    $assm = [System.Reflection.Assembly]::Load("Microsoft.Exchange.WebServices, Version=15.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35")
    if($assm.GlobalAssemblyCache)
    {
        Write-Host -Foreground Green "Found Exchange Web Services in Global Assembly Cache"
        Write-Host "Exchange Web Services Version: $([System.Diagnostics.FileVersionInfo]::GetVersionInfo($assm.Location).FileVersion)"
    }
    else
    {
        Write-Warning "Unable to find Exchange Web Services in Global Assembly Cache"
        $anyWarnings = $true
    }
}
catch
{
    Write-Warning "Unable to find Exchange Web Services in Global Assembly Cache"
    $anyWarnings = $true
}


Write-Host
Write-Host

Write-Host "Step 2: Checking for https web application"

$webapps = Get-SPWebApplication -EA SilentlyContinue

$rootWeb = $NULL

if($webapps -ne $NULL)
{
    $sslWebAppExists = $false
    foreach($webapp in $webapps)
    {
        if($rootWeb -eq $NULL)
        {
            $rootWeb = Get-SPWeb $webApp.Url -EA SilentlyContinue
        }

        if(-not $webapp.Url.StartsWith("https://"))
        {
            Write-Warning "Web Application at $($webapp.Url) does not use HTTPS. Site Mailboxes will not work on this Web Application."
        }
        else
        {
            $sslWebAppExists = $true
            Write-Host -Foreground Green "Found Web Application at $($webapp.Url) that uses HTTPS"
        }
    }

    if(-not $sslWebAppExists)
    {
        Write-Warning "At least one Web Application must be configured for HTTPS in the default zone."
        $anyWarnings = $true
    }
}
else
{
    Write-Warning "No Web Applications Found. Please create a web application and re-run Check-SiteMailboxConfig"
    $anyWarnings = $true
    if($ReturnWarningState)
    {
        return $anyWarnings
    }
    return;
}

if($rootWeb -eq $NULL)
{
    Write-Warning "Unable to find any Sites. Please create a root site collection on a web application and re-run Check-SiteMailboxConfig"
    $anyWarnings = $true
    if($ReturnWarningState)
    {
        return $anyWarnings
    }
    return;
}

# Get App Permissions Management Objects
$appPrincipalManager = [Microsoft.SharePoint.SPAppPrincipalManager]::GetManager($rootWeb)
$appPrincipalPermissionsManager = New-Object -TypeName Microsoft.SharePoint.SPAppPrincipalPermissionsManager -ArgumentList $rootWeb        

Write-Host
Write-Host
Write-Host "Step 3: Checking for trusted Exchange Servers"

$trustedIssuers = Get-SPTrustedSecurityTokenIssuer
$trustedIssuerHosts = @()

if($trustedIssuers -ne $NULL)
{
    $foundTrustedIssuer = $false
    foreach($trustedIssuer in $trustedIssuers)
    {
        if($trustedIssuer.RegisteredIssuerName.StartsWith("00000002-0000-0ff1-ce00-000000000000@"))
        {
            if($trustedIssuer.IsSelfIssuer)
            {
                $foundTrustedIssuer = $true

                $uri = New-Object -TypeName System.Uri -ArgumentList $trustedIssuer.MetadataEndPoint
                
                Write-Host -Foreground Green "Found trusted Exchange Server at $($uri.Host)"
                $appPrincipalName = [Microsoft.SharePoint.SPAppPrincipalName]::CreateFromNameIdentifier($trustedIssuer.RegisteredIssuerName)
                $appPrincipal = $appPrincipalManager.LookupAppPrincipal([Microsoft.SharePoint.SPAppPrincipalIdentityProvider]::External, $appPrincipalName);
                


                if($appPrincipal -ne $NULL)
                {
                    $isValidAppPrincipal = $true;

                    if($appPrincipalPermissionsManager.GetAppPrincipalSiteSubscriptionContentPermission($appPrincipal) -eq [Microsoft.SharePoint.SPAppPrincipalPermissionKind]::FullControl)
                    {
                        Write-Host -Foreground Green "Exchange Server at $($uri.Host) has Full Control permissions"
                        
                    }
                    else
                    {
                        Write-Warning "Exchange Server at $($uri.Host) does not have Full Control permissions"
                        $isValidAppPrincipal = $false;
                        $anyWarnings = $true
                    }

                    if($appPrincipalPermissionsManager.IsAppOnlyPolicyAllowed($appPrincipal))
                    {
                        Write-Host -Foreground Green "Exchange Server at $($uri.Host) has App Only Permissions"
                    }
                    else
                    {
                        Write-Warning "Exchange Server at $($uri.Host) does not have App Only Permissions"
                        $isValidAppPrincipal = $false;
                        $anyWarnings = $true
                    }
                    
                    if($isValidAppPrincipal)
                    {
                        $trustedIssuerHosts += $uri.Host
                    }

                }
                else
                {
                    Write-Warning "Unable to get App Principal for $($uri.Host). Unable to check permissions for this Exchange Server"
                    $anyWarnings = $true
                }
            }
            else
            {
                Write-Warning "Found trusted Exchange Server at $($uri.Host) but it is not a Self Issuer"
                $anyWarnings = $true
            }
        }
    }

    if(-not $foundTrustedIssuer)
    {
        Write-Warning "Unable to find any trusted Exchange Servers"
        $anyWarnings = $true
    }
}
else
{
    Write-Warning "Unable to find any trusted Exchange Servers"
    $anyWarnings = $true
}

Write-Host
Write-Host
Write-Host "Step 4: Report current Site Mailbox Configuration"

if($webapps -ne $NULL)
{
    foreach($webapp in $webapps)
    {
        Write-Host
        Write-Host "Web Application Site Mailbox Configuration: $($webapp.Url)"
        Write-Host "Exchange Site Mailbox Domain: $($webapp.Properties["ExchangeTeamMailboxDomain"])"
        
        if($webapp.Properties["ExchangeAutodiscoverDomain"] -ne $NULL)
        {
            Write-Host "Exchange Autodiscover Domain: $($webapp.Properties["ExchangeAutodiscoverDomain"])"
        }
    }
}

Write-Host
Write-Host "Trusted Exchange Services: $([String]::Join(", ", $trustedIssuerHosts))"

$feature = Get-SPFeature CollaborationMailboxFarm -Farm -ErrorAction Ignore

if($feature -eq $NULL)
{
    Write-Host -ForegroundColor Red "Site Mailboxes are NOT enabled for Farm"
}
else
{
    Write-Host -ForegroundColor Green "Site Mailboxes are enabled for Farm"
}

if($ReturnWarningState)
{
    return $anyWarnings
}