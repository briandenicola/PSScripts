[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[Parameter(Mandatory=$true)] [string[]] $computers,
	[Parameter(Mandatory=$true)] [string] $path,
    [switch] $ShowAllFiles,
	[string] $out
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")

function Reduce-Set
{
	PARAM (
		[Parameter(ValueFromPipeline=$true)]
   		[object] $ht
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
						Hash = $diff.FileHash
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
	foreach( $file in (Get-ChildItem $directory -Recurse | Where { $_.PSIsContainer -eq $false } ) ) {
		$files += New-Object PSObject -Property @{
            Name = $file.FullName
			System = $system
            FileHash = (Get-Hash1 $file.FullName)
		}
	}
	return $files
} 

function main
{
	$results = Invoke-Command -ComputerName $computers -ScriptBlock $map -ArgumentList $path | Select Name, FileHash, System 

    if( !$ShowAllFiles ) {
        $results = $results | Group-Object -Property Name -AsHashTable | Reduce-Set
    }
	
	if( ![string]::IsNullOrEmpty($out) ) {
		$results | Export-Csv -Encoding Ascii -NoTypeInformation $out
		Invoke-Item $out
	}
	else {
		return $results
	}
}
main
