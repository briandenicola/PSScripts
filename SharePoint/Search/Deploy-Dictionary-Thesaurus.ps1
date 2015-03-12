[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [ValidateScript({Test-Path $_})] 
	[Parameter(ParameterSetName="Dictionary",Mandatory=$true)][string] $DictionaryFile,	
	
    [ValidateScript({Test-Path $_})] 
    [Parameter(ParameterSetName="Thesaurus", Mandatory=$true)][string] $ThesaurusFile
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")

Set-Variable -Name now             -Value $(Get-Date).ToString("yyyyMMddhhmmss") -Option Constant
Set-Variable -Name dictionary_file -Value "custom0009.lex"                       -Option Constant
Set-Variable -Name thesaurus_file  -Value "tsenu.xml"                            -Option Constant

Set-Variable -Name dictionary_path        -Value "d$\SharePoint\14\14.0\Bin\"           -Option Constant 
Set-Variable -Name default_thesaurus_path -Value @("c$\Program Files\Microsoft Office Servers\14.0\Data\Office Server\Config",
		                                           "c$\Program Files\Microsoft Office Servers\14.0\Data\Config") -Option Constant
function Get-QueryComponents
{
	return( Get-SPServiceApplication | 
        Where { $_.TypeName -eq "Search Service Application" } | 
        Get-SPEnterpriseSearchQueryTopology  | 
        Where { $_.State -eq "Active" } |
        Select QueryComponents )
}

function DeployTo-SharePointALL 
{
    param(
        [string]   $new_file, 
        [string[]] $paths,
        [string]   $default_file 
    )

	foreach( $system in (Get-SPServer | Where { $_.Role -ne "Invalid" } | Select -ExpandProperty Address) ) {
		foreach( $path in $paths ) {
			$org_file =  "\\{0}\{1}\{2}" -f $system,$path, $default_file
			$backup_file = $org_file + "." + $now

			if( Test-Path $org_file ) {
				Copy -Path $org_file -Destination $backup_file -verbose
			}
			Copy Path $new_file -Destination $org_file -Force -verbose
		}
	}
}

function Restart-Search 
{
    Param ( [String[]] $systems )

	$sb = {
        $search_service = "OSearch14"
		if ( ( Get-Service -Name $search_service | Select -ExpandProperty Status ) -eq "Running" ) {
			Restart-Service -Name $search_service -Verbose
		}
	}
	Invoke-Command -ComputerName $systems -ScriptBlock $sb 
}

function Deploy-Dictionary 
{
    Param ( [string] $file )
	DeployTo-SharePointALL -new_file $file -paths $dictionary_path -default_file $dictionary_file
}

function Deploy-Thesaurus
{
    Param  ( [string] $file )
	DeployTo-SharePointALL -new_file $file -paths $default_thesaurus_path -default_file $thesaurus_file 
		
	foreach( $query_component in ($query_components.QueryComponents | Select ServerName, IndexLocation, Name ) ) {
		$org_file =  "\\{0}\{1}\{2}\Config\{3}" -f $query_components.ServerName, $query_components.IndexLocation.Replace(":\", "$\"), $query_components.Name, $thesaurus_file 
		$backup_file = $org_file + "." + $now
		
		Copy -Path $org_file -Destination $backup_file -verbose
		copy -Path $file -Destination $org_file -Force -verbose
	}
	
}

$query_components = Get-QueryComponents
switch ($PsCmdlet.ParameterSetName) { 
    "Dictionary" { Deploy-Dictionary -file $DictionaryFile }
    "Thesaurus"  { Deploy-Thesaurus  -file $ThesaurusFile  }
}	
Restart-Search ($query_components.QueryComponents | Select -Expand ServerName)