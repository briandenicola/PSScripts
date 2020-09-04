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
        $differences = @()
        
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
    }
    process {		
        foreach ( $key in $fileHash.Keys ) 
        {
            if ( $fileHash[$key].Count -eq 1 ) {		
                $differences += New-FileDifference -FileObject $fileHash[$key][0]
            } 
            elseif (-not(Test-ForUniqueHash -FileHashes $fileHash[$key])) {
                $differences += foreach ( $diff in $fileHash[$key] ) {
                    New-FileDifference -FileObject $diff
                }
            }
        } 
    }
    end { 
        return $differences
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
$differences = $results | Group-Object -Property Path -AsHashTable | Reduce-Set
$differences 