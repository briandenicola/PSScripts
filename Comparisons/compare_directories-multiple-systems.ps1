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
	BEGIN { 
		$differences = @()
	}
	PROCESS {		
		Write-Host "Comparing Keys . . ."
		
		$ht = $_
		
		foreach ( $key in $ht.Keys )
		{
			if( $ht[$key].Count -eq 1 ) 
			{		
				$differences += (New-Object PSObject -Property @{
					File = $ht[$key] | Select -ExpandProperty Name
					System = $ht[$key] | Select -ExpandProperty System
					Hash = $ht[$key] | Select -ExpandProperty FileHash
				})
			} 
			elseif( ($ht[$key] | Select -Unique -ExpandProperty FileHash).Count -ne $null )
			{
				foreach( $diff in $ht[$key] )
				{
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
 
	. d:\Scripts\Libraries\Standard_Functions.ps1

	$files = @()
	$system = $ENV:COMPUTERNAME
	
	Write-Host "Working on - $system"
	dir $directory -Recurse | Where { $_.PSIsContainer -eq $false } | ForEach-Object { 
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
