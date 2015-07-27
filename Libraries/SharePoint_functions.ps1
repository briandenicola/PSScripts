#Load Sharepoint .NET assemblies 
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint")
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Office.Server.Search") 
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Office.Server") 

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

Set-Variable -Name url -Value "http://webapp/site/web" -Option Constant

function Decode-SPListViewUrl 
{
    param(
        [string] $url
    )

    if( $url -inotmatch "ViewEdit.aspx") {
        throw "Not Valid SharePoint ViewEdit Url"
    }

    $url_space = "%20"
    $ascii_space = " "

    $url_components = $url.Split("&")

    $list_id   = [string]::Format("{0}{1}{2}", "{",([system.web.httputility]::UrlDecode($url_components[0].Split("=")[1])).ToUpper(),"}")
    $view_id   = [system.web.httputility]::UrlDecode($url_components[1].Split("=")[1])
    $source_id = ([system.web.httputility]::UrlDecode($url_components[2].Split("=")[1]) ) -replace $url_space, $ascii_space
    
    return ( New-Object -TypeName PSObject -Property @{ 
        ListId   = $list_id
        ViewId   = $view_id
        SourceId = $source_id
        Url      = $url
    })
}

function Get-SharePointServersWS
{
	#param(
	#	[string] $version = "2010"
	#)
	
	#if( $version -eq "2010" ) { $view = '{}' } else { $view = '{}' }

    #return(	Get-SPListViaWebService -Url $url -list Servers -View $view | Select SystemName, Farm, Environment, ApplicationName)

    $view = '{}'
    return(	Get-SPListViaWebService -Url $url -list Servers -View $view | Select SystemName, Farm, Environment, ApplicationName)
}

function Get-SharePointCentralAdmins
{
    $view = '{}'
	return(	Get-SPListViaWebService -Url $url -list Servers -view $url | Select SystemName, Farm, Environment, "Central Admin Address" )
}

function Get-LatestLog
{
    [CmdletBinding()]
	param(
		[Parameter(Mandatory=$True,ValueFromPipeline=$True)]
		[string] $computer
    )

	begin {
		$log_path = "\Logs\Trace\"
	}
	process {
		$src = Join-Path ("\\$computer" ) $log_path
		$latest_file =  ( dir $src | sort LastWriteTime -desc | select -first 1 | Select -ExpandProperty Name )
		
		Copy-Item (Join-Path $src $latest_file) $PWD.Path -verbose
	}
	end {
	}
}

function Get-SharePointSolutions
{
	return (Get-SPFarm | Select -Expand Solutions | Select Name, Deployed, DeployedWebApplications, DeployedServers, ContainsGlobalAssembly, ContainsCasPolicy, SolutionId, LastOperationEndTime)
}

function Get-WebServiceURL
{
    param( [String] $url )

	$listWebService = "_vti_bin/Lists.asmx?WSDL"
	
	if( -not $url.EndsWith($listWebService) ) {
		return $url.Substring( 0, $url.LastIndexOf("/") ) + "/" + $listWebService
	} 
    else {
		return $url
	}

}

function Get-SPListViaWebService
{
    param ([string] $url, [string] $list, [string] $view = $null )

	begin {
		$listData = @()
		
		$service = New-WebServiceProxy (Get-WebServiceURL -url $url) -Namespace List -UseDefaultCredential
		
		$FieldsWS = $service.GetList( $list )
		$Fields = $FieldsWS.Fields.Field | where { $_.Hidden -ne "TRUE"} | Select DisplayName, StaticName -Unique
		$data = $service.GetListItems( $list, $view, $null, $null, $null, $null, $null )
	}
	process {
		$ErrorActionPreference = "silentlycontinue"
		foreach( $item in $data.data.row ) {
			$t = new-object System.Object
			foreach( $field in $Fields ) {
				$StaticName = "ows_" + $field.StaticName
				$DisplayName = $field.DisplayName
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

function Get-FarmAccount
{
    param ( [string[]] $Computername )

	$farmAccounts = @()
	foreach( $computer in $ComputerName ) {
		$farmAccounts += (gwmi Win32_Process -Computer $computer | Where { $_.Caption -eq "owstimer.exe"} ).GetOwner() | Select @{Name="System";Expression={$computer}}, Domain, User
	}

	return $farmAccounts
}

function WriteTo-SPListViaWebService 
{
    param( [String] $url, [String] $list, [HashTable] $Item, [String] $TitleField )

	begin {
		$service = New-WebServiceProxy (Get-WebServiceURL -url $url) -Namespace List -UseDefaultCredential
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
			$listItem += ("<Field Name='{0}'>{1}</Field>`n" -f $key, [system.net.webutility]::htmlencode($value) )
		}   
  
		$batch = [xml]($xml -f $listInfo.View.Name,$listItem)   			
		$response = $service.UpdateListItems($listInfo.List.Name, $batch)   
		$code = [int]$response.result.errorcode   
	
 		if ($code -ne 0 ) {   
			Write-Warning "Error $code - $($response.result.errortext)"     
		}
	}
	end { }
}


function Update-SPListViaWebService 
{
    param ( [String] $url, [String] $list, [int] $id, [HashTable] $Item, [String] $TitleField )

	begin {
		$service = New-WebServiceProxy (Get-WebServiceURL -url $url) -Namespace List -UseDefaultCredential
		$listItem = [String]::Empty
	}
	process {

		$xml = @"
			<Batch OnError='Continue' ListVersion='1' ViewName='{0}'>  
				<Method ID='{1}' Cmd='Update'>
				<Field Name='ID'>{1}</Field>
					{2}
				</Method>  
			</Batch>  
"@   

		$listInfo = $service.GetListAndView($list, "")   

		foreach ($key in $item.Keys) {
			$value = $item[$key]
			if( -not [String]::IsNullOrEmpty($TitleField) -and $key -eq $TitleField ) {
				$key = "Title"
			}
			$listItem += ("<Field Name='{0}'>{1}</Field>`n" -f $key,[system.net.webutility]::htmlencode($value))  
		}   
  
		$xml = ($xml -f $listInfo.View.Name,$id, $listItem)
  
		#Write-Host "XML output - $($xml) ..."
  
		$batch = [xml] $xml
		try { 		
			$response = $service.UpdateListItems($listInfo.List.Name, $batch)   
			$code = [int]$response.result.errorcode   
	
			if ($code -ne 0) {   
				Write-Warning "Error $code - $($response.result.errortext)"     
			} 
		}
		catch [System.Exception] {
			Write-Error ("Update failed with - " +  $_.Exception.ToString() )
		}
	}
	end {}
}

function Get-MOSSProfileDetails
{ 
    param ([string]$SiteURL, [string]$UserLogin) 
    
    [Void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Office.Server.UserProfiles")

    $site = Get-SPSite -url $SiteURL

    $srvContext = [Microsoft.Office.Server.ServerContext]::GetContext($site) 
    
    Write-Host "Status", $srvContext.Status 
    $userProfileManager = new-object Microsoft.Office.Server.UserProfiles.UserProfileManager($srvContext) 

    Write-Host "Profile Count:", $userProfileManager.Count 

    if( ![string]::IsNullOrEmpty($UserLogin ) ) {
        $UserProfile = $userProfileManager.GetUserProfile($UserLogin) 
        
        Write-Host "SID :", $UserProfile["SID"].Value 
        Write-Host "Name :", $UserProfile["PreferredName"].Value 
        Write-Host "Email :", $UserProfile["WorkEmail"].Value 
        Write-Host "Logon Name :", $UserProfile["AccountName"].Value 
        Write-Host "SID :", $UserProfile["SID"].Value 
        Write-Host "Name :", $UserProfile["PreferredName"].Value 
        Write-Host "Job Title :", $UserProfile["Title"].Value 
        Write-Host "Department :", $UserProfile["Department"].Value 
        Write-Host "SIP Address :", $UserProfile["WorkEmail"].Value 
        Write-Host "Picture :", $UserProfile["PictureURL"].Value 
        Write-Host "About Me :", $UserProfile["AboutMe"].Value 
        Write-Host "Country :", $UserProfile["Country"].Value
    }

    $site.Dispose() 
} 

function Get-SSPSearchContext
{
	$context = [Microsoft.Office.Server.ServerContext]::Default
 	$searchContext = [Microsoft.Office.Server.Search.Administration.SearchContext]::GetContext($context)
	$content = [Microsoft.Office.Server.Search.Administration.Content]$searchContext	
	return $content
}

function Get-SSPSearchContentSources
{
 	return $(Get-SSPSearchContext).ContentSources
}

function Start-SSPFullCrawl
{
    param ( [String] $name, [switch] $force )

	$idle = [Microsoft.Office.Server.Search.Administration.CrawlStatus]::Idle
	
	$ContentSource = Get-SSPSearchContentSources | where { $_.Name -eq $name }
	
	if( $force ) { Stop-SSPCrawl -name $name }
	
	if( $ContentSource.CrawlStatus -eq $idle ) {
		$ContentSource.StartFullCrawl()
	} 
    else {
	 	throw "Invalid Crawl state - " +  $ContentSource.CrawlStatus
	}
}

function Stop-SSPCrawl
{
    param ( [String] $name )

	$idle = [Microsoft.Office.Server.Search.Administration.CrawlStatus]::Idle
	
	$ContentSource = Get-SSPSearchContentSources | where { $_.Name -eq $name }
	if( $ContentSource.CrawlStatus -ne $idle ) {
		$ContentSource.StopCrawl()
	} 
	
	$count = 0
	while ( $ContentSource.CrawlStatus -ne $idle -or $count -eq 30 ) {
		Sleep -Seconds 1
		$count++
	} 

	if( $ContentSource.CrawlStatus -ne "Idle" )	{
		throw "Invalid Crawl State. Crawl should be idle but is not"
	}
}

function Get-CrawlHistory
{
    $serverContext = [Microsoft.Office.Server.ServerContext]::Default
    $searchContext = [Microsoft.Office.Server.Search.Administration.SearchContext]::GetContext($serverContext)
	return ( [Microsoft.Office.Server.Search.Administration.CrawlHistory]$searchContext )
}

function Get-LastCrawlStatus
{
    param ( [String] $name )
	$history = Get-CrawlHistory	
	$contentSource = Get-SSPSearchContentSources | where { $_.Name -eq $name } 
	return ( $history.GetLastCompletedCrawlHistory($contentSource.Id) | Select CrawlId, @{Name="CrawlTimeInHours";Expression={($_.EndTime - $_.StartTime).TotalHours}}, EndTime, WarningCount, ErrorCount, SuccessCount )
}
 
function Get-FullCrawlAverage
{
    param ( [string] $name, [int] $days = 7)
	$history = Get-CrawlHistory
	$contentSource = Get-SSPSearchContentSources | where { $_.Name -eq $name } 
	return $history.GetNDayAvgStats($contentSource, 1, $days)
}

function Set-SPReadOnly
{
    [CmdletBinding()]
    param  (
    	[Parameter(Mandatory=$True,ValueFromPipeline=$True)]
		[string] $site,
        [bool] $state
    )

	begin{
	}
	process{
		Write-Verbose ("Setting Read-Only flag on Site Collection " + $site.ToString() + " to " + $state)
		$sp_site = Get-SPSite -url $site.ToString()
		$sp_site.ReadOnly = $state
		$sp_site.Dispose()
	}
	end{
	}
}

function Get-SPAudit
{	
	param(
    	[Parameter(Mandatory=$True,ValueFromPipeline=$True)]
		[string] $site,
		[Object] $obj
	)
	begin{	
	}
	process{
		$flags = $site.Audit.AuditFlags.value__
		$Audit = [string]::Empty
			
		foreach( $key in ($auditTypes.Keys.GetEnumerator()) ){
			if( $auditTypes[$key] -band $flags ) {
				$Audit += $key + "|"
			}
		}
		if( [string]::IsNullOrEmpty($Audit) ) { $Audit = "No Audits Set" }
		
		$a = new-object System.Object
		$a | add-member -type NoteProperty -name "SiteName" -value $site.RootWeb.Title
		$a | add-member -type NoteProperty -name "URL" -value $site.RootWeb.ServerRelativeURL
		$a | add-member -type NoteProperty -name "Audit" -value $Audit.TrimEnd("|")
		
	}
	end {
        return $a
	}
}

function Get-SPWebApplication
{
    param ( [string] $url )
	$WebServiceCollection = new-object microsoft.sharepoint.administration.SpWebServiceCollection( Get-SPFarm )
	$webApplications = $WebServiceCollection | Select -Expand WebApplications
	
    foreach( $app in $WebApplications ) {
        $urls = $app.AlternateUrls | Select -Expand IncomingUrl
        if( $urls -contains $url ) { return $app }
	}
    
    return $null
}

function Get-SPFarm
{
	return [microsoft.sharepoint.administration.spfarm]::local
}

function Get-SPSite 
{
    param( [String] $url )
	return new-object Microsoft.SharePoint.SPSite($url)
}

function Get-SPSiteCollections
{
    param ( [Object] $webApp )
	return $webApp.Sites
}

function Get-SPWebCollections
{
    param ( [Object] $sc )
	return $sc.AllWebs 
}

function Get-SPWeb
{
    param( [String] $url )
	$site = new-object Microsoft.SharePoint.SPSite($url)
	return $site.OpenWeb()
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

function Update-SPListEntry
{
    param ([String] $url, [string] $list, [int] $entryID, [HashTable] $entry)

	$web = Get-SPWeb -url $url
	
	$splist = $web.Lists[$list]	
	$item = $splist.GetItemByID($entryID)
	
	foreach( $key in ($entry.Keys.GetEnumerator()) ){
		$item[$key] = $entry[$key]
	}
	
	$item.Update()
	$web.Dispose()
}

function Add-ToSPList 
{
    param ( [String] $url, [string] $list, [HashTable] $entry)

	$web = Get-SPWeb -url $url
	
	$splist = $web.Lists[$list]
	$newitem = $splist.items.Add() 

	foreach( $key in ($entry.Keys.GetEnumerator()) ) {
		$newitem[$key] = $entry[$key]
	}
	
	$newitem.update() 
	$web.Dispose()
}

function Get-SPList 
{
    param ( [string] $url, [string] $list, [string] $filter="all")

	begin{
		$rtList = @()
		$web = Get-SPWeb -url $url
		$splist = $web.Lists[$list]
		$Fields = $splist.Fields | where { $_.Hidden -eq $false } | Select Title -Unique
	}

	process{
		$ErrorActionPreference = "silentlycontinue"
		$i=0
		foreach( $item in $splist.Items ) {
			write-progress -activity "Searching List" -status "Progress:" -percentcomplete ($i/$splist.Items.Count*100)
			$t = new-object System.Object
			foreach( $field in $Fields ) {
				$t | add-member -type NoteProperty -name $field.Title.ToString() -value $item[$field.Title]
			}
			$i++ 	
			$rtList += $t
		}
		
		$web.Dispose()
	}
	end {
		if( $filter -eq "all" ) {
			return $rtList
		} 
        else  {
			$key,$value = $filter.Split(":")
			return ( $rtList | where { $_.$key -like $value } )
		}
	}
}

function Remove-SPGroupRole
{
    param ( 
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
        [object] $role 
    )

    begin{}
    process {
	    foreach( $binding in $role.RoleDefinitionBindings ) {
		    Write-Host ("Removing " + $binding.ToString())
		    $role.RoleDefinitionBindings.Remove($binding) 
	    }
	    $role.Update()
    }
    end {}
}

function Remove-AllSPGroupFromSite( [String] $url )
{
	$web = Get-SPWeb -url $url
	$siteGroups = $web.RoleAssignments
	$web.RoleAssignments| Remove-SPGroupRole
}

function Get-SPGroup
{
    param ( [String] $Url, [string] $GroupName ) 
	$web = Get-SPWeb -url $url
	$siteGroups = $web.SiteGroups
	
	return ( $siteGroups | where { $_.Name -like $GroupName } )
}
	
function Get-SPUser 
{
    param ( [String] $url, [string] $User ) 
	$web = Get-SPWeb -url $url
	if( $user.Contains("\") ) { $loginName = $user } else { $loginName = "*\$user" }
	return ( $web.AllUsers | where { $_.LoginName -like $loginName } )
}

function Add-SPGroupPermission
{
    param ( [String] $url, [string] $GroupName, [string] $perms)

	$web = Get-SPWeb -url $url
	$spRoleAssignment = New-Object Microsoft.SharePoint.spRoleAssignment((Get-spGroup -url $web -GroupName $groupName))
	$spRoleDefinition = $web.RoleDefinitions[$perms]
	$spRoleAssignment.RoleDefinitionBindings.Add($spRoleDefinition)
	$web.RoleAssignments.Add($spRoleAssignment)
	$web.Update()
	
	$web.Dispose()
}

function Add-MemberToSPGroup  
{
    param (  [String] $url, [string] $LoginName , [string] $GroupName)
	$web = Get-SPWeb -url $url
	$spGroup = Get-spGroup -url $web -GroupName $GroupName
	$spGroup.Users.Add($LoginName,$nul,$nul,$nul)
	
	$web.Dispose()
}

function Add-SPUser
{
    param ( [string] $url, [string] $User )
	$web = Get-SPWeb -url $url

	$spRoleAssignment = New-Object Microsoft.SharePoint.spRoleAssignment($User, $nul, $nul, $nul)
	$spRoleDefinition = $web.RoleDefinitions["Read"]
	
	$spRoleAssignment.RoleDefinitionBindings.Add($spRoleDefinition)
	$web.RoleAssignments.Add($spRoleAssignment)
	
	$web.Update()
	$web.Dispose()
}

function Add-SPGroup
{
    param ( [string] $url, [string] $GroupName, [string] $owner, [string] $description)
	$web = Get-SPWeb -url $url
	$siteGroups = $web.SiteGroups
	
	$spUser = Get-spUser -Url $web -User $owner 
	if( $spUser -eq $null ) { 
		Add-SPUser -SiteCollectionUrl $SiteCollectionUrl -User $owner 
		$spUser = Get-spUser -Url $web -User $owner 
	}
		
	$rtValue = $siteGroups.Add( $GroupName, $spUser, $spUser, $description)
	$web.Dispose()
}

function Add-SPWeb 
{
    param ([string] $url, [string]$WebUrl, [string]$Title, [string]$Description, [string]$Template, [bool] $Inherit)

    $spsite = Get-SPSite $url
    $web = $spsite.Allwebs.Add($WebUrl, $Title, $Description ,[int]1033, $siteTypes.Item($Template), $Inherit, $false)	
	$spsite.Dispose()
	
	return $web	
}

function Set-AccessRequestEmail
{
    param ([String] $url, [string] $email)
	$web = Get-SPWeb -url $url
	$web.RequestAccessEmail = $email
	$web.RequestAccessEnabled = $true
	$web.Update()
	$web.Dispose()
}

function Set-Inheritance
{
    param ( [String] $url, [bool] $unique)
	$web = Get-SPWeb -url $url
	$web.HasUniquePerm = $unique
	$web.Update()
	$web.Dispose()
}

function Set-SharedNavigation
{
    param ( [String] $url, [bool] $shared)
	$web = Get-SPWeb -url $url
	$web.Navigation.UseShared = $shared
	$web.Update()
	$web.Dispose()
}

function Set-spAssociatedGroups
{
    param ( [String] $url, [string] $owners, [string] $members, [string] $visitors)
	$web = Get-SPWeb -url $url
	$web.AssociatedOwnerGroup = Get-spGroup -url $web -GroupName $owners
	$web.AssociatedMemberGroup = Get-spGroup -url $web -GroupName $members
	$web.AssociatedVisitorGroup = Get-spGroup -url $web -GroupName $visitors
	$web.Update()
	$web.Dispose()
}

function Get-LookupFieldData
{
    param ( [string] $field )

	$fieldarray = $field.split(";")
	[String[]] $out = @()
    $re = [regex]'^#\D'

    foreach($fieldline in $fieldarray) {
        if ($re.Match($fieldline.toString()).success -eq $true) {
		    $out += $fieldline.substring(1,($fieldline.length -1))
	    }
	}
	
	return $out
}