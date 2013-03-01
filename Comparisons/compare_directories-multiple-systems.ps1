[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[Parameter(Mandatory=$true)]
	[string[]] $computers,
	
	[Parameter(Mandatory=$true)]
	[string] $path,
	
	[Parameter(Mandatory=$true)]
	[string] $out
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")

function Reduce-Set
{
	PARAM (
		[Parameter(ValueFromPipeline=$true)]
   		[string] $ht
	)
	
	BEGIN { 
		$differences = @()
	}
	PROCESS {		
		Write-Verbose "Comparing Keys . . ."				
		foreach ( $key in $ht.Keys ) {
			if( $ht[$key].Count -eq 1 ) {		
				$differences += (New-Object PSObject -Property @{
					File = $ht[$key] | Select -ExpandProperty Name
					System = $ht[$key] | Select -ExpandProperty System
					Hash = $ht[$key] | Select -ExpandProperty FileHash
				})
			} 
			elseif( ($ht[$key] | Select -Unique -ExpandProperty FileHash).Count -ne 1 )	{
				foreach( $diff in $ht[$key] ) {
					$differences += (New-Object PSObject -Property @{
						File =  $diff.Name
						System = $diff.System
						Hash = $diff.fileHash
					})
				}
			}
		}
		
	}
	END { 
		return $differences
	}
}

$map = {
	param ( [string] $directory )
 	
	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
	$files = @()
	$system = $ENV:COMPUTERNAME
	
	Write-Verbose "Working on - $system"
	Get-ChildItem $directory -Recurse | Where { $_.PSIsContainer -eq $false } | ForEach-Object { 
		$name = $_.FullName
		$files += New-Object PSObject -Property @{
            Name = $name
			System = $system
		    FileHash = (get-hash1 $name)
		}
	}
	return $files
} 

Invoke-Command -ComputerName $computers -ScriptBlock $map -ArgumentList $path |
	Select Name, FileHash, System |
	Group-Object -Property Name -AsHashTable | 
	Reduce-Set |
	Export-Csv -Encoding Ascii -NoTypeInformation $out

Invoke-Item $out
