param (
	[Parameter(Mandatory=$True]
	[Alias('ref')]
	[string] $ReferenceComputerName,
	
	[Parameter(Mandatory=$True]
	[Alias('dif')]
	[string] $DifferenceComputerName
)	

$sb = { 
	. (Join-Path -Path $ENV:SCRIPTS_HOME -ChildPath "libraries\standard_functions.ps1" )
	return( Get-GacAssembly )
}

#$rGac = get-SystemGAC -server $ref
#$dGac = get-SystemGAC -server $dif

$reference_gac = Invoke-Command -ComputerName $ReferenceComputerName -ScriptBlock $sb |
	Sort -Property Name | 
	Select -Property Name, Version, PublicKey
	
$difference_gac = Invoke-Command -ComputerName $DifferenceComputerName -ScriptBlock $sb |
	Sort -Property Name | 
	Select -Property Name, Version, PublicKey

Compare-Object -ReferenceObject $reference_gac -DifferenceObject $difference_gac -SyncWindow $reference_gac.Length -Property Name,PublicKey,Version
