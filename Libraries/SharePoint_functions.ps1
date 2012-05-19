#Load Sharepoint .NET assemblies 
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint")
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Office.Server.Search") 
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Office.Server") 
#[void][System.Reflection.Assembly]::LoadFrom("D:\Scripts\Libraries\Lists.dll")

$siteTypes = @{}
$siteTypes.Add("Team Site","STS#0")
$siteTypes.Add("Blank","STS#1")
$siteTypes.Add("Workspace", "STS#2")
$siteTypes.Add("Meeting Workspace","MPS#0")

$auditTypes= @{}
$auditTypes['OpenView'] = 4
$auditTypes['EditItem'] = 16
$auditTypes['CheckInOut'] = 3
$auditTypes['MoveCopyItem'] = 6144
$auditTypes['DeleteItem'] = 520
$auditTypes['EditContentType'] = 160
$auditTypes['SearchSiteContent'] = 8192
$auditTypes['UserSecurity'] = 256

$ops_site = "http://www.example.com/sites/SharePointOpsSite"

function get-SharePointServersWS()
{
	param(
		[string] $version = "2010"
	)
	
	$servers_2007 = '{}'
	$servers_2010 = '{}'
	
	if( $version -eq "2007" ) {
		return(	get-SPListViaWebService -Url $ops_site -list Servers -View $servers_2007 | Select SystemName, Farm, Environment)
	} else { 
		return(	get-SPListViaWebService -Url $ops_site -list Servers -View $servers_2010 | Select SystemName, Farm, Environment)
	}
}

function get-SharePointCentralAdmins()
{
	return(	get-SPListViaWebService -Url $ops_site -list Servers -view "{}" | Select SystemName, Farm, Environment, "Central Admin Address" )
}


function get-LatestLog()
{
	begin {
		$log_path = "\Logs\Trace\"
	}
	process {
		
		$src = Join-Path ("\\" + $_ ) $log_path
		$latest_file =  ( dir $src | sort LastWriteTime -desc | select -first 1 | Select -ExpandProperty Name )
		
		Copy-Item (Join-Path $src $latest_file) . -verbose
	}
	end {
	}
}


function get-SharePointSolutions()
{
	return (Get-SPFarm | Select -Expand Solutions | Select Name, Deployed, DeployedWebApplications, DeployedServers, ContainsGlobalAssembly, ContainsCasPolicy, SolutionId, LastOperationEndTime)
}


function get-WebServiceURL( [String] $url )
{
	$listWebService = "_vti_bin/Lists.asmx?WSDL"
	
	if( -not $url.EndsWith($listWebService) )
	{
		return $url.Substring( 0, $url.LastIndexOf("/") ) + "/" + $listWebService
	} else
	{
		return $url
	}

}

function get-SPListViaWebService([string] $url, [string] $list, [string] $view = $null )
{
	begin {
		$listData = @()
		
		$service = New-WebServiceProxy (get-WebServiceURL -url $url) -Namespace List -UseDefaultCredential			
		$FieldsWS = $service.GetList( $list )
		$Fields = $FieldsWS.Fields.Field | where { $_.Hidden -ne "TRUE"} | Select DisplayName, StaticName -Unique
	
		$data = $service.GetListItems( $list, $view, $null, $null, $null, $null, $null )
	}
	process {
			
		$ErrorActionPreference = "silentlycontinue"
		$data.data.row | % {
			$item = $_
			$t = new-object System.Object
			$Fields | % {
				$StaticName = "ows_" + $_.StaticName
				$DisplayName = $_.DisplayName
				if( $item.$StaticName -ne $nul ) {
					$t | add-member -type NoteProperty -name $DisplayName.ToString() -value $item.$StaticName
				}
			}
			$listData += $t
		}
	}
	end {
			return ( $listData )
	}
}

function Get-FarmAccount( [string[]] $Computername )
{
	$farmAccounts = @()
	$ComputerName | % {
		$computer = $_
		$farmAccounts += (gwmi Win32_Process -Computer $computer | Where { $_.Caption -eq "owstimer.exe"} ).GetOwner() | Select @{Name="System";Expression={$computer}}, Domain, User
	}
	return $farmAccounts

}

function WriteTo-SPListViaWebService ( [String] $url, [String] $list, [HashTable] $Item, [String] $TitleField )
{
	begin {
		$service = New-WebServiceProxy (get-WebServiceURL -url $url) -Namespace List -UseDefaultCredential
	}
	process {

		$xml = @"
			<Batch OnError='Continue' ListVersion='1' ViewName='{0}'>  
				<Method ID='1' Cmd='New'>
					{1}
				</Method>  
			</Batch>  
"@   

		$listInfo = $service.GetListAndView($list, "")   

		foreach ($key in $item.Keys) {
			$value = $item[$key]
			if( -not [String]::IsNullOrEmpty($TitleField) -and $key -eq $TitleField ) {
				$key = "Title"
			}
			$listItem += ("<Field Name='{0}'>{1}</Field>`n" -f $key,$value)   
		}   
  
		$batch = [xml]($xml -f $listInfo.View.Name,$listItem)   
				
		$response = $service.UpdateListItems($listInfo.List.Name, $batch)   
		$code = [int]$response.result.errorcode   
	
 		if ($code -ne 0) {   
			Write-Warning "Error $code - $($response.result.errortext)"     
		} else {
			Write-Host "Success"
		}
	}
	end {
		
	}
}


function get-MOSSProfileDetails([string]$SiteURL, [string]$UserLogin) 
{ 
    [Void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Office.Server.UserProfiles")

    $site = get-SPSite - url $SiteURL

    $srvContext = [Microsoft.Office.Server.ServerContext]::GetContext($site) 
    Write-Host "Status", $srvContext.Status 
    $userProfileManager = new-object Microsoft.Office.Server.UserProfiles.UserProfileManager($srvContext) 

    Write-Host "Profile Count:", $userProfileManager.Count 

    $UserProfile = $userProfileManager.GetUserProfile($UserLogin) 

    #Basic Data 
    Write-Host "SID :", $UserProfile["SID"].Value 
    Write-Host "Name :", $UserProfile["PreferredName"].Value 
    Write-Host "Email :", $UserProfile["WorkEmail"].Value 

    #Detailed Data 
    Write-Host "Logon Name :", $UserProfile["AccountName"].Value 
    Write-Host "SID :", $UserProfile["SID"].Value 
    Write-Host "Name :", $UserProfile["PreferredName"].Value 
    Write-Host "Job Title :", $UserProfile["Title"].Value 
    Write-Host "Department :", $UserProfile["Department"].Value 
    Write-Host "SIP Address :", $UserProfile["WorkEmail"].Value 
    Write-Host "Picture :", $UserProfile["PictureURL"].Value 
    Write-Host "About Me :", $UserProfile["AboutMe"].Value 
    Write-Host "Country :", $UserProfile["Country"].Value

    $site.Dispose() 
} 

function get-SSPSearchContext( )
{
	$context = [Microsoft.Office.Server.ServerContext]::Default
 	$searchContext = [Microsoft.Office.Server.Search.Administration.SearchContext]::GetContext($context)
	$content = [Microsoft.Office.Server.Search.Administration.Content]$searchContext
	
	return $content
}

function get-SSPSearchContentSources ( )
{
 	return $(get-SSPSearchContext).ContentSources
}

function Start-SSPFullCrawl( [String] $name, [switch] $force )
{
	$idle = [Microsoft.Office.Server.Search.Administration.CrawlStatus]::Idle
	
	$ContentSource = get-SSPSearchContentSources | where { $_.Name -eq $name }
	
	if( $force ) 
	{
		Stop-SSPCrawl -name $name
	}
	
	if( $ContentSource.CrawlStatus -eq $idle ) 
	{
		$ContentSource.StartFullCrawl()
	} else {
	 	throw "Invalid Crawl state - " +  $ContentSource.CrawlStatus
	}
}

function Stop-SSPCrawl( [String] $name )
{
	$idle = [Microsoft.Office.Server.Search.Administration.CrawlStatus]::Idle
	
	$ContentSource = get-SSPSearchContentSources | where { $_.Name -eq $name }
	
	if( $ContentSource.CrawlStatus -ne $idle ) 
	{
		$ContentSource.StopCrawl()
	} 
	
	$count = 0
	while ( $ContentSource.CrawlStatus -ne $idle -or $count -eq 30 )
	{
		sleep -Seconds 1
		$count++
	} 

	if( $ContentSource.CrawlStatus -ne "Idle" )
	{
		throw "Invalid Crawl State. Crawl should be idle but is not"
	}
}
function Get-CrawlHistory
{
    $serverContext = [Microsoft.Office.Server.ServerContext]::Default
    $searchContext = [Microsoft.Office.Server.Search.Administration.SearchContext]::GetContext($serverContext)
    
	return ( [Microsoft.Office.Server.Search.Administration.CrawlHistory]$searchContext )
}

function Get-LastCrawlStatus( [String] $name )
{
	$history = Get-CrawlHistory	
	$contentSource = get-SSPSearchContentSources | where { $_.Name -eq $name } 
	return ( $history.GetLastCompletedCrawlHistory($contentSource.Id) | Select CrawlId, @{Name="CrawlTimeInHours";Expression={($_.EndTime - $_.StartTime).TotalHours}}, EndTime, WarningCount, ErrorCount, SuccessCount )
}
 
function Get-FullCrawlAverage( [string] $name, [int] $days = 7)
{
	$history = Get-CrawlHistory
	$contentSource = get-SSPSearchContentSources | where { $_.Name -eq $name } 
	return $history.GetNDayAvgStats($contentSource, 1, $days)
}

function set-SPReadOnly ([bool] $state )
{
	begin{
	}
	process{
		Write-Host "Setting Read-Only flag on Site Collection " $_.ToString() " to " $state
		$site = get-SPSite -url $_.ToString()
		$site.ReadOnly = $state
		$site.Dispose()
	}
	end{
	}
}

function get-SPAudit( ) 
{	
	param(
		[Object] $obj
	)
	begin{
		
	}
	process{
		$flags = $_.Audit.AuditFlags.value__
		$Audit = ""
			
		$auditTypes.Keys.GetEnumerator() | % {
			if( $auditTypes[$_] -band $flags )
			{
				$Audit += $_ + "|"
			}
		}
		if( $Audit -eq "" ) { $Audit = "No Audits Set" }
		
		$a = new-object System.Object
		$a | add-member -type NoteProperty -name "SiteName" -value $_.RootWeb.Title
		$a | add-member -type NoteProperty -name "URL" -value $_.RootWeb.ServerRelativeURL
		$a | add-member -type NoteProperty -name "Audit" -value $Audit.TrimEnd("|")
		
		return $a
	}
	end {
	}
}

function get-SPWebApplication( [string] $name )
{
	$WebServiceCollection = new-object microsoft.sharepoint.administration.SpWebServiceCollection( get-SPFarm )
	$WebServiceCollection | % { $WebApplications += $_.WebApplications }
	
	return ( $webApplications | where { $_.Name.ToLower() -like "*"+$name.ToLower()+"*" } | select -Unique )
}

function get-SPFarm()
{
	return [microsoft.sharepoint.administration.spfarm]::local
}
function get-SPSite ( [String] $url )
{
	return new-object Microsoft.SharePoint.SPSite($url)
}

function get-SPSiteCollections( [Object] $webApp )
{
	return ( $webApp.Sites )
}

function get-SPWebCollections( [Object] $sc )
{
	return ( $sc.AllWebs )
}

function get-SPWeb( [String] $url )
{
	$site = new-object Microsoft.SharePoint.SPSite($url)
	return ( $site.OpenWeb() )
}

function UploadTo-Sharepoint {
	param ( 
		[string] $lib,
		[string] $file
	)

	$wc = new-object System.Net.WebClient
	$wc.Credentials = [System.Net.CredentialCache]::DefaultCredentials
	$uploadname = $lib + $(split-path -leaf $file)
	$wc.UploadFile($uploadname,"PUT", $file) 
}

function update-SpListEntry([String] $url, [string] $list, [int] $entryID, [HashTable] $entry)
{
	$web = get-SPWeb -url $url
	
	$splist = $web.Lists[$list]	
	$item = $splist.GetItemByID($entryID)
	
	$entry.Keys.GetEnumerator() | % {
		$item[$_] = $entry[$_]
	}
	
	$item.Update()
	$web.Dispose()
}

function add-toSpList ( [String] $url, [string] $list, [HashTable] $entry)
{
	$web = get-SPWeb -url $url
	
	$splist = $web.Lists[$list]
	$newitem = $splist.items.Add() 

	$entry.Keys.GetEnumerator() | % {
		$newitem[$_] = $entry[$_]
	}
	
	$newitem.update() 
	$web.Dispose()
}

function get-spList ( [string] $url, [string] $list, [string] $filter="all")
{
	begin{
		$rtList = @()
		$web = get-SPWeb -url $url
		$splist = $web.Lists[$list]

		$Fields = $splist.Fields | where { $_.Hidden -eq $false } | Select Title -Unique
	}

	process{
		$ErrorActionPreference = "silentlycontinue"
		$i=0
		$splist.Items | % {
			$item = $_
			write-progress -activity "Searching List" -status "Progress:" -percentcomplete ($i/$splist.Items.Count*100)
			$t = new-object System.Object
			$Fields | % {
				$t | add-member -type NoteProperty -name $_.Title.ToString() -value $item[$_.Title]
			}
			$i++ 	
			$rtList += $t
		}
		
		$web.Dispose()
	}
	end {
		if( $filter -eq "all" ) 
		{
			return $rtList
		} else 
		{
			$key,$value = $filter.Split(":")
			return ( $rtList | where { $_.$key -like $value } )
		}
	}
}

function remove-spGroupRole( [object] $role )
{
	$role.RoleDefinitionBindings | % { 
		Write-Host "Removing " $_.ToString()
		$role.RoleDefinitionBindings.Remove($_) 
	}
	$role.Update()
}

function remove-allSpGroupFromSite( [String] $url )
{
	$web = get-SPWeb -url $url
	$siteGroups = $web.RoleAssignments
	$web.RoleAssignments | % { remove-spGroupRole( $_ ) }
}

function get-spGroup( [String] $Url, [string] $GroupName ) 
{
	$web = get-SPWeb -url $url
	$siteGroups = $web.SiteGroups
	
	return ( $siteGroups | where { $_.Name -like $GroupName } )
}
	
function get-spUser ( [String] $url, [string] $User ) 
{
	$web = get-SPWeb -url $url
	if( $user.Contains("\") ) { $loginName = $user } else { $loginName = "*\$user" }
	return ( $web.AllUsers | where { $_.LoginName -like $loginName } )
}

function add-spGroupPermission( [String] $url, [string] $GroupName, [string] $perms)
{
	$web = get-SPWeb -url $url
	
	$spRoleAssignment = New-Object Microsoft.SharePoint.spRoleAssignment((get-spGroup -url $web -GroupName $groupName))
	$spRoleDefinition = $web.RoleDefinitions[$perms]
	
	$spRoleAssignment.RoleDefinitionBindings.Add($spRoleDefinition)
	$web.RoleAssignments.Add($spRoleAssignment)
	$web.Update()
	
	$web.Dispose()
}

function Add-MemberToSPGroup (  [String] $url, [string] $LoginName , [string] $GroupName) 
{
	$web = get-SPWeb -url $url
	$spGroup = get-spGroup -url $web -GroupName $GroupName
	$spGroup.Users.Add($LoginName,$nul,$nul,$nul)
	
	$web.Dispose()
}

function add-spUser( [string] $url, [string] $User )
{
	$web = get-SPWeb -url $url

	$spRoleAssignment = New-Object Microsoft.SharePoint.spRoleAssignment($User, $nul, $nul, $nul)
	$spRoleDefinition = $web.RoleDefinitions["Read"]
	
	$spRoleAssignment.RoleDefinitionBindings.Add($spRoleDefinition)
	$web.RoleAssignments.Add($spRoleAssignment)
	
	$web.Update()
	$web.Dispose()
}

function add-spGroup( [string] $url, [string] $GroupName, [string] $owner, [string] $description)
{
	$web = get-SPWeb -url $url
	$siteGroups = $web.SiteGroups
	
	$spUser = get-spUser -Url $web -User $owner 
	if( $spUser -eq $null ) { 
		add-spUser -SiteCollectionUrl $SiteCollectionUrl -User $owner 
		$spUser = get-spUser -Url $web -User $owner 
	}
		
	$rtValue = $siteGroups.Add( $GroupName, $spUser, $spUser, $description)
	
	$web.Dispose()
}

function add-spWeb([string] $url, [string]$WebUrl, [string]$Title, [string]$Description, [string]$Template, [bool] $Inherit) 
{
    # Create our SPSite object
    $spsite = get-SPSite $url

	# Add a site
    $web = $spsite.Allwebs.Add($WebUrl, $Title, $Description ,[int]1033, $siteTypes.Item($Template), $Inherit, $false)
	
	$spsite.Dispose()
	
	return $web	
}

function set-AccessRequestEmail([String] $url, [string] $email)
{
	$web = get-SPWeb -url $url
	$web.RequestAccessEmail = $email
	$web.RequestAccessEnabled = $true
	$web.Update()
	$web.Dispose()
}

function set-Inheritance( [String] $url, [bool] $unique)
{
	$web = get-SPWeb -url $url
	$web.HasUniquePerm = $unique
	$web.Update()
	$web.Dispose()
}

function set-SharedNavigation( [String] $url, [bool] $shared)
{
	$web = get-SPWeb -url $url
	$web.Navigation.UseShared = $shared
	$web.Update()
	$web.Dispose()
}

function set-spAssociatedGroups( [String] $url, [string] $owners, [string] $members, [string] $visitors)
{
	$web = get-SPWeb -url $url
	$web.AssociatedOwnerGroup = get-spGroup -url $web -GroupName $owners
	$web.AssociatedMemberGroup = get-spGroup -url $web -GroupName $members
	$web.AssociatedVisitorGroup = get-spGroup -url $web -GroupName $visitors
	$web.Update()
	$web.Dispose()
}
