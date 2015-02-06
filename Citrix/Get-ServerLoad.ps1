param(
    [string] $computer,
	[string] $file
)

$sb = { 
    Add-PSSnapin Citrix.XenApp.Commands
    $load = Get-XAServerLoad
    return $load
}

if($computer) {
    $load = Invoke-Command -ComputerName $computer -ScriptBlock $sb 
}
else {
    $sb.Invoke()
}

if( -not [String]::IsNullOrEmpty($file) ) {
    $load | Export-Csv -Encoding ascii -NoTypeInformation $file
}
else {
    $load | Sort ServerName | Select ServerName, Load | Format-Table -AutoSize 
}
