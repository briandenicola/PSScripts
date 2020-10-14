[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $true)] [String[]] $ComputerNames,
    [Parameter(Mandatory = $true)] [String] $Path
)

function Merge-FileHashSet {
    param (
        [Parameter(ValueFromPipeline = $true)]
        [HashTable] $FileHash
    )
    
    begin {
        $differences = [System.Collections.ArrayList]::new()
        
        function New-FileDifference {
            param(
                [PSCustomObject] $FileObject
            )

            return (New-Object PSObject -Property @{
                Path         = $FileObject.Path
                ComputerName = $FileObject.ComputerName
                Hash         = $FileObject.Hash
            })
        }

        function Test-ForUniqueHash {
            param(
                [Object[]] $FileHashes
            )
            return ($FileHashes | Select-Object -Unique -ExpandProperty Hash).Count -eq 1
        }

        function Update-FileDifferences {
            param(
                [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
                [Object[]] $InputObject
            )
            begin {
                foreach($Object in $InputObject) {
                    $t = New-FileDifference -FileObject $Object
                    $differences.Add($t) | Out-Null
                }
            }
        }
    }
    process {		
        foreach ( $key in $fileHash.Keys ) 
        {
            if ( $fileHash[$key].Count -eq 1 ) {		
                Update-FileDifferences -InputObject $fileHash[$key][0]
            } 
            elseif (-not(Test-ForUniqueHash -FileHashes $fileHash[$key])) {
                Update-FileDifferences -InputObject $FileHash[$key]
            }
        } 
    }
    end { 
        return $differences | Sort-Object -Property Path -Descending
    }
}

$map = {
    param ( [string] $directory )
 	
    $files =  Get-ChildItem $directory -Recurse | 
                Where-Object { -not $_.PSIsContainer } | 
                Foreach-Object -Parallel { Get-FileHash -Path $_.FullName -Algorithm MD5 } |
                Select-Object Path, Hash, @{N="ComputerName";E={$ENV:COMPUTERNAME}}
    return $files
} 

$results = Invoke-Command -ComputerName $computers -ScriptBlock $map -ArgumentList $path | Select-Object Path, Hash, ComputerName
$differences = $results | Group-Object -Property Path -AsHashTable | Merge-FileHashSet
$differences 
