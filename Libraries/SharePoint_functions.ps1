#Load Sharepoint .NET assemblies 
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint")
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Office.Server.Search") 
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Office.Server") 
<<<<<<< HEAD
#[void][System.Reflection.Assembly]::LoadFrom("D:\Scripts\Libraries\Lists.dll")
=======

. .\Standard_Variables.ps1
>>>>>>> Major updates for fit and finish

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

<<<<<<< HEAD

function Get-SharePointServersWS()
=======
function Get-SharePointServersWS
>>>>>>> Major updates for fit and finish
{
	param(
		[string] $version = "2010"
	)
	
	if( $version -eq "2007" ) {
<<<<<<< HEAD
		return(	get-SPListViaWebService -Url http://teamadmin.gt.com/sites/ApplicationOperations/ -list Servers -View '{17029C2D-ABD2-45F8-9FE5-17A5F3C0DCBC}' | Select SystemName, Farm, Environment)
	} else { 
		return(	get-SPListViaWebService -Url http://teamadmin.gt.com/sites/ApplicationOperations/ -list Servers  | Select SystemName, Farm, Environment)
	}
}

function Get-SharePointCentralAdmins()
{
	return(	get-SPListViaWebService -Url http://teamadmin.gt.com/sites/ApplicationOperations/ -list Servers -view "{3ADCF3C7-5CCE-459C-89A8-D361B7C71CB1}" | Select SystemName, Farm, Environment, "Central Admin Address" )
}

function Get-LatestLog()
=======
		return(	get-SPListViaWebService -Url $global:SharePoint_url -list Servers -View $global:SharePoint_2007_View  | Select SystemName, Farm, Environment )
	} else { 
		return(	get-SPListViaWebService -Url $global:SharePoint_url -list Servers  | Select SystemName, Farm, Environment )
	}
}

function Get-SharePointCentralAdmins
{
	return(	get-SPListViaWebService -Url $global:SharePoint_url -list Servers -view $global:SharePoint_Central_Admin_View | Select SystemName, Farm, Environment, "Central Admin Address" )
}

function Get-LatestLog
>>>>>>> Major updates for fit and finish
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

<<<<<<< HEAD

function Get-SharePointSolutions()
=======
function Get-SharePointSolutions
>>>>>>> Major updates for fit and finish
{
	return (Get-SPFarm | Select -Expand Solutions | Select Name, Deployed, DeployedWebApplications, DeployedServers, ContainsGlobalAssembly, ContainsCasPolicy, SolutionId, LastOperationEndTime)
}

function Get-WebServiceURL( [String] $url )
{
	$listWebService = "_vti_bin/Lists.asmx?WSDL"
	
<<<<<<< HEAD
	if( -not $url.EndsWith($listWebService) )
	{
		return $url.Substring( 0, $url.LastIndexOf("/") ) + "/" + $listWebService
	} else
	{
		return $url
	}

}

function Get-SPListViaWebService([string] $url, [string] $list, [string] $view = $null )
{
	begin {
		$listData = @()
		
		$service = New-WebServiceProxy (Get-WebServiceURL -url $url) -Namespace List -UseDefaultCredential
		
		$FieldsWS = $service.GetList( $list )
		$Fields = $FieldsWS.Fields.Field | where { $_.Hidden -ne "TRUE"} | Select DisplayName, StaticName -Unique
	
=======
	if( -not $url.EndsWith($listWebService) ) {
		return $url.Substring( 0, $url.LastIndexOf("/") ) + "/" + $listWebService
	}
	else {
		return $url
	}
}

function Get-SPListViaWebService( [string] $url, [string] $list, [string] $view = $null )
{
	begin {
		$listData = @()	
		$service = New-WebServiceProxy (Get-WebServiceURL -url $url) -Namespace List -UseDefaultCredential
		$FieldsWS = $service.GetList( $list )
		$Fields = $FieldsWS.Fields.Field | where { $_.Hidden -ne "TRUE"} | Select DisplayName, StaticName -Unique
>>>>>>> Major updates for fit and finish
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

<<<<<<< HEAD

=======
>>>>>>> Major updates for fit and finish
function Update-SPListViaWebService ( [String] $url, [String] $list, [int] $id, [HashTable] $Item, [String] $TitleField )
{
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
			$listItem += ("<Field Name='{0}'>{1}</Field>`n" -f $key,$value)   
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
	end {
		
	}
}

<<<<<<< HEAD
function Get-MOSSProfileDetails([string]$SiteURL, [string]$UserLogin) 
{ 
    [Void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Office.Server.UserProfiles")

    $site = Get-SPSite - url $SiteURL

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

function Get-SSPSearchContext( )
=======
function Get-SSPSearchContext
>>>>>>> Major updates for fit and finish
{
	$context = [Microsoft.Office.Server.ServerContext]::Default
 	$searchContext = [Microsoft.Office.Server.Search.Administration.SearchContext]::GetContext($context)
	$content = [Microsoft.Office.Server.Search.Administration.Content]$searchContext
	
	return $content
}

<<<<<<< HEAD
function Get-SSPSearchContentSources ( )
=======
function Get-SSPSearchContentSources
>>>>>>> Major updates for fit and finish
{
 	return $(Get-SSPSearchContext).ContentSources
}

function Start-SSPFullCrawl( [String] $name, [switch] $force )
{
	$idle = [Microsoft.Office.Server.Search.Administration.CrawlStatus]::Idle
	
	$ContentSource = Get-SSPSearchContentSources | where { $_.Name -eq $name }
	
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
	
	$ContentSource = Get-SSPSearchContentSources | where { $_.Name -eq $name }
	
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
<<<<<<< HEAD
=======

>>>>>>> Major updates for fit and finish
function Get-CrawlHistory
{
    $serverContext = [Microsoft.Office.Server.ServerContext]::Default
    $searchContext = [Microsoft.Office.Server.Search.Administration.SearchContext]::GetContext($serverContext)
    
	return ( [Microsoft.Office.Server.Search.Administration.CrawlHistory]$searchContext )
}

function Get-LastCrawlStatus( [String] $name )
{
	$history = Get-CrawlHistory	
	$contentSource = Get-SSPSearchContentSources | where { $_.Name -eq $name } 
	return ( $history.GetLastCompletedCrawlHistory($contentSource.Id) | Select CrawlId, @{Name="CrawlTimeInHours";Expression={($_.EndTime - $_.StartTime).TotalHours}}, EndTime, WarningCount, ErrorCount, SuccessCount )
}
 
function Get-FullCrawlAverage( [string] $name, [int] $days = 7)
{
	$history = Get-CrawlHistory
	$contentSource = Get-SSPSearchContentSources | where { $_.Name -eq $name } 
	return $history.GetNDayAvgStats($contentSource, 1, $days)
}

function Set-SPReadOnly ([bool] $state )
{
	begin{
	}
	process{
		Write-Host "Setting Read-Only flag on Site Collection " $_.ToString() " to " $state
		$site = Get-SPSite -url $_.ToString()
		$site.ReadOnly = $state
		$site.Dispose()
	}
	end{
	}
}

<<<<<<< HEAD
function Get-SPAudit( ) 
=======
function Get-SPAudit
>>>>>>> Major updates for fit and finish
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

function Get-SPWebApplication( [string] $name )
{
	$WebServiceCollection = new-object microsoft.sharepoint.administration.SpWebServiceCollection( Get-SPFarm )
	$WebServiceCollection | % { $WebApplications += $_.WebApplications }
	
	return ( $webApplications | where { $_.Name.ToLower() -like "*"+$name.ToLower()+"*" } | select -Unique )
}

<<<<<<< HEAD
function Get-SPFarm()
{
	return [microsoft.sharepoint.administration.spfarm]::local
}
=======
function Get-SPFarm
{
	return [microsoft.sharepoint.administration.spfarm]::local
}

>>>>>>> Major updates for fit and finish
function Get-SPSite ( [String] $url )
{
	return new-object Microsoft.SharePoint.SPSite($url)
}

function Get-SPSiteCollections( [Object] $webApp )
{
	return ( $webApp.Sites )
}

function Get-SPWebCollections( [Object] $sc )
{
	return ( $sc.AllWebs )
}

function Get-SPWeb( [String] $url )
{
	$site = new-object Microsoft.SharePoint.SPSite($url)
	return ( $site.OpenWeb() )
}

<<<<<<< HEAD
function UploadTo-Sharepoint {
=======
function UploadTo-Sharepoint 
{
>>>>>>> Major updates for fit and finish
	param ( 
		[string] $lib,
		[string] $file
	)

	$wc = new-object System.Net.WebClient
	$wc.Credentials = [System.Net.CredentialCache]::DefaultCredentials
	$uploadname = $lib + $(split-path -leaf $file)
	$wc.UploadFile($uploadname,"PUT", $file) 
}

<<<<<<< HEAD
function Update-SPListEntry([String] $url, [string] $list, [int] $entryID, [HashTable] $entry)
=======
function Update-SPListEntry( [String] $url, [string] $list, [int] $entryID, [HashTable] $entry )
>>>>>>> Major updates for fit and finish
{
	$web = Get-SPWeb -url $url
	
	$splist = $web.Lists[$list]	
	$item = $splist.GetItemByID($entryID)
	
	$entry.Keys.GetEnumerator() | % {
		$item[$_] = $entry[$_]
	}
	
	$item.Update()
	$web.Dispose()
}

<<<<<<< HEAD
function Add-ToSPList ( [String] $url, [string] $list, [HashTable] $entry)
=======
function Add-ToSPList( [String] $url, [string] $list, [HashTable] $entry )
>>>>>>> Major updates for fit and finish
{
	$web = Get-SPWeb -url $url
	
	$splist = $web.Lists[$list]
	$newitem = $splist.items.Add() 

	$entry.Keys.GetEnumerator() | % {
		$newitem[$_] = $entry[$_]
	}
	
	$newitem.update() 
	$web.Dispose()
}

<<<<<<< HEAD
function Get-SPList ( [string] $url, [string] $list, [string] $filter="all")
=======
function Get-SPList( [string] $url, [string] $list, [string] $filter="all" )
>>>>>>> Major updates for fit and finish
{
	begin{
		$rtList = @()
		$web = Get-SPWeb -url $url
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

function Remove-SPGroupRole( [object] $role )
{
	$role.RoleDefinitionBindings | % { 
		Write-Host "Removing " $_.ToString()
		$role.RoleDefinitionBindings.Remove($_) 
	}
	$role.Update()
}

function Remove-AllSPGroupFromSite( [String] $url )
{
	$web = Get-SPWeb -url $url
	$siteGroups = $web.RoleAssignments
	$web.RoleAssignments | % { remove-spGroupRole( $_ ) }
}

function Get-SPGroup( [String] $Url, [string] $GroupName ) 
{
	$web = Get-SPWeb -url $url
	$siteGroups = $web.SiteGroups
	
	return ( $siteGroups | where { $_.Name -like $GroupName } )
}
	
<<<<<<< HEAD
function Get-SPUser ( [String] $url, [string] $User ) 
=======
function Get-SPUser( [String] $url, [string] $User ) 
>>>>>>> Major updates for fit and finish
{
	$web = Get-SPWeb -url $url
	if( $user.Contains("\") ) { $loginName = $user } else { $loginName = "*\$user" }
	return ( $web.AllUsers | where { $_.LoginName -like $loginName } )
}

<<<<<<< HEAD
function Add-SPGroupPermission( [String] $url, [string] $GroupName, [string] $perms)
=======
function Add-SPGroupPermission( [String] $url, [string] $GroupName, [string] $perms )
>>>>>>> Major updates for fit and finish
{
	$web = Get-SPWeb -url $url
	
	$spRoleAssignment = New-Object Microsoft.SharePoint.spRoleAssignment((Get-spGroup -url $web -GroupName $groupName))
	$spRoleDefinition = $web.RoleDefinitions[$perms]
	
	$spRoleAssignment.RoleDefinitionBindings.Add($spRoleDefinition)
	$web.RoleAssignments.Add($spRoleAssignment)
	$web.Update()
	
	$web.Dispose()
}

<<<<<<< HEAD
function Add-MemberToSPGroup (  [String] $url, [string] $LoginName , [string] $GroupName) 
=======
function Add-MemberToSPGroup( [String] $url, [string] $LoginName , [string] $GroupName ) 
>>>>>>> Major updates for fit and finish
{
	$web = Get-SPWeb -url $url
	$spGroup = Get-spGroup -url $web -GroupName $GroupName
	$spGroup.Users.Add($LoginName,$nul,$nul,$nul)
	
	$web.Dispose()
}

function Add-SPUser( [string] $url, [string] $User )
{
	$web = Get-SPWeb -url $url

	$spRoleAssignment = New-Object Microsoft.SharePoint.spRoleAssignment($User, $nul, $nul, $nul)
	$spRoleDefinition = $web.RoleDefinitions["Read"]
	
	$spRoleAssignment.RoleDefinitionBindings.Add($spRoleDefinition)
	$web.RoleAssignments.Add($spRoleAssignment)
	
	$web.Update()
	$web.Dispose()
}

function Add-SPGroup( [string] $url, [string] $GroupName, [string] $owner, [string] $description)
{
	$web = Get-SPWeb -url $url
	$siteGroups = $web.SiteGroups
	
	$spUser = Get-spUser -Url $web -User $owner 
	if( $spUser -eq $null ) { 
		add-spUser -SiteCollectionUrl $SiteCollectionUrl -User $owner 
		$spUser = Get-spUser -Url $web -User $owner 
	}
		
	$rtValue = $siteGroups.Add( $GroupName, $spUser, $spUser, $description)
	
	$web.Dispose()
}

<<<<<<< HEAD
function Add-SPWeb([string] $url, [string]$WebUrl, [string]$Title, [string]$Description, [string]$Template, [bool] $Inherit) 
{
    # Create our SPSite object
    $spsite = Get-SPSite $url

	# Add a site
    $web = $spsite.Allwebs.Add($WebUrl, $Title, $Description ,[int]1033, $siteTypes.Item($Template), $Inherit, $false)
	
=======
function Add-SPWeb( [string] $url, [string]$WebUrl, [string]$Title, [string]$Description, [string]$Template, [bool] $Inherit ) 
{
    $spsite = Get-SPSite $url
    $web = $spsite.Allwebs.Add($WebUrl, $Title, $Description ,[int]1033, $siteTypes.Item($Template), $Inherit, $false)
>>>>>>> Major updates for fit and finish
	$spsite.Dispose()
	
	return $web	
}

<<<<<<< HEAD
function Set-AccessRequestEmail([String] $url, [string] $email)
=======
function Set-AccessRequestEmail( [String] $url, [string] $email )
>>>>>>> Major updates for fit and finish
{
	$web = Get-SPWeb -url $url
	$web.RequestAccessEmail = $email
	$web.RequestAccessEnabled = $true
	$web.Update()
	$web.Dispose()
}

<<<<<<< HEAD
function Set-Inheritance( [String] $url, [bool] $unique)
=======
function Set-Inheritance( [String] $url, [bool] $unique )
>>>>>>> Major updates for fit and finish
{
	$web = Get-SPWeb -url $url
	$web.HasUniquePerm = $unique
	$web.Update()
	$web.Dispose()
}

<<<<<<< HEAD
function Set-SharedNavigation( [String] $url, [bool] $shared)
=======
function Set-SharedNavigation( [String] $url, [bool] $shared )
>>>>>>> Major updates for fit and finish
{
	$web = Get-SPWeb -url $url
	$web.Navigation.UseShared = $shared
	$web.Update()
	$web.Dispose()
}

<<<<<<< HEAD
function Set-spAssociatedGroups( [String] $url, [string] $owners, [string] $members, [string] $visitors)
=======
function Set-SPAssociatedGroups( [String] $url, [string] $owners, [string] $members, [string] $visitors )
>>>>>>> Major updates for fit and finish
{
	$web = Get-SPWeb -url $url
	$web.AssociatedOwnerGroup = Get-spGroup -url $web -GroupName $owners
	$web.AssociatedMemberGroup = Get-spGroup -url $web -GroupName $members
	$web.AssociatedVisitorGroup = Get-spGroup -url $web -GroupName $visitors
	$web.Update()
	$web.Dispose()
<<<<<<< HEAD
}
function Get-LookupFieldData
{
param
(
[String] $field
)
	$fieldarray = $field.split(";")
	[String[]] $out = @()
			$re = [regex]'^#\D'
            Foreach($fieldline in $fieldarray)
			{
                if ($re.Match($fieldline.toString()).success -eq $true)
				{
					$out += $fieldline.substring(1,($fieldline.length -1))
				}
			}
	
	return $out
}
Function Get-Servers
{
param
(
[String] $env = $(throw 'Please Enter an environment'),
[String[]] $exclude,
[String] $list = "Web"
)
Switch ($list)
{
"Web"{
		$view = '''{8B5CF22A-914F-47DE-9722-133CCFBAF14C}'''
		$listurl = '''http://teamadmin.gt.com/sites/ApplicationOperations/applicationsupport/'''
		$listname = '''appservers'''
	}

}
$filter = '$_.Updates -eq ''1'' -and $_.Environment -eq '''+$env+'''' 
if ($exclude -ne $null)
{
foreach ($ex in $exclude)
{
$filter = $filter+' -and $_.Application -notlike ''*'+$ex+''''
}

}
$exclusion = $executioncontext.invokecommand.NewScriptBlock($filter)
$appinfo = Get-SPListViaWebService -url $listurl -list $listname -view $view  | Where  [ScriptBlock]::Create($filter)  
if ($exclude -ne $null)
{
foreach ($ex in $exclude)
{
$filter = $filter+' -and $_.Application -notlike ''*'+$ex+''''
}
}
$a = @()
$b = @()
Foreach ($server in $appinfo)
{
if (-not (ping $server."SystemName"))
{
$a += $server
}
else
{
$application = Get-LookupFieldData -field $server.Application
$b += $server.SystemName+","+$application
}
$a | out-file ".\NoLongerAlive.txt"
$b | Out-File ".\ServerstoPatch.txt"
}
}

=======
}
>>>>>>> Major updates for fit and finish
