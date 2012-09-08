[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[Parameter(Mandatory=$true)]
	[string] $file,
	
	[Parameter(Mandatory=$true)]
	[ValidateSet("dictionary", "thesaurus")]
	[string] $deploy 
)

Add-PSSnapin Microsoft.SharePoint.PowerShell –erroraction SilentlyContinue

$now = $(Get-Date).ToString("yyyyMMddhhmmss")

function Get-QueryComponents()
{
	$query_topology = Get-SPServiceApplication | where { $_.TypeName -eq "Search Service Application" } | Get-SPEnterpriseSearchQueryTopology 
	return ( $query_topology | where { $_.State -eq "Active" } | Select QueryComponents )	
}

function DeployTo-SharePointALL ( [string] $new_file, [string[]] $path, [string] $default_file )
{
		Get-SPServer | where { $_.Role -ne "Invalid" } | % { 
			$system = $_.Address 
			$path | % {
				$org_file =  "\\" + $system  + "\" + $_ + "\" + $default_file
				$backup_file = $org_file + "." + $now

				if( Test-Path $org_file )
				{
					copy $org_file $backup_file -verbose
				}
				copy $new_file $org_file -Force -verbose
			}
		}
}

function Restart-Search ( [String[]] $systems )
{
	$sb = {
		if ( ( Get-Service -Name OSearch14 | Select -ExpandProperty Status ) -eq "Running" )
		{
			Restart-Service -Name OSearch14 -Verbose
		}
	}
	Invoke-Command -ComputerName $systems -ScriptBlock $sb 
}

function Deploy-Dictionary ( [string] $file )
{
	$dictionary_file = "custom0009.lex"
	$dictionary_path = "d$\SharePoint\14\14.0\Bin\"

	DeployTo-SharePointALL -new_file $file -path $dictionary_path -default_file $dictionary_file
	
	Restart-Search ( (Get-QueryComponents).QueryComponents | Select -Expand ServerName )
}

function Deploy-Thesaurus ( [string] $file )
{
	$thesaurus_file = "tsenu.xml"
	$default_thesaurus_path = @("c$\Program Files\Microsoft Office Servers\14.0\Data\Office Server\Config",
		"c$\Program Files\Microsoft Office Servers\14.0\Data\Config")

	DeployTo-SharePointALL -new_file $file -path $default_thesaurus_path -default_file $thesaurus_file 
		
	$query_components = Get-QueryComponents

	$servers = @()
	$query_components.QueryComponents | Select ServerName, IndexLocation, Name | % {
		$org_file =  "\\" + $_.ServerName + "\" + $_.IndexLocation.Replace(":\", "$\") + "\" + $_.Name + "\Config\" + $thesaurus_file 
		$backup_file = $org_file + "." + $now
		
		copy $org_file $backup_file -verbose
		copy $file $org_file -Force -verbose
		
		$servers += $_.ServerName
	}
	
	Restart-Search $servers
}

function main()
{
	if( -not ( Test-Path $file ) )
	{
		Write-Error $file " does not exist"
		return
	}

	if( $deploy.ToLower() -eq "dictionary" )
	{
		Deploy-Dictionary $file
	}
	
	if( $deploy.ToLower() -eq "thesaurus" )
	{
		Deploy-Thesaurus $file
	}
}
main
	