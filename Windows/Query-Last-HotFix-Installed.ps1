param(
	[string[]] $computers = $(throw "Must supply an array of  computer")
)

$sb = { 
	$hotfixes = Get-WmiObject -Class win32_quickfixengineering | Select hotfixId, InstalledOn | Sort-Object -Property InstalledOn -Descending | Select -First 1
    $lastboot = Get-WmiObject -Class win32_operatingsystem 

    return ( New-Object PSObject -Property @{
        Computer = $env:COMPUTERNAME
        LastBootUp = $lastboot.ConvertToDateTime($lastboot.LastBootupTime)
        LastHotfix = $hotfixes.hotfixid
        LastPatchDate = $hotfixes.InstalledOn
    })
}


Invoke-Command -ComputerName $computers -ScriptBlock $sb | 
    Select Computer, LastBootUp, LastPatchDate, LastHotfix