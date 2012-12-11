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

function Get-WebServiceURL( [String] $url )
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

function Get-SPListViaWebService([string] $url, [string] $list, [string] $view = $null )
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
		#$service = new-object Lists
		#$service.UseDefaultCredentials = $true                                                                                                      
		#$service.Url = get-WebServiceURL -url $url
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
