param(
    [string] $computer,
    [string] $application,
	[string] $file
)

$sb = { 
    param(
        [string] $application
    )

    Add-PSSnapIn Citrix.Common.Commands -EA SilentlyContinue
    Add-PSSnapin Citrix.XenApp.Commands -EA SilentlyContinue

    $details = Get-XAApplication $application | Get-XAAccount | Select AccountDisplayName, AccountType, SearchPath

    return $details
}

if($computer) {
    $details = Invoke-Command -ComputerName $computer -ScriptBlock $sb -ArgumentList $application
}
else {
    $sb.Invoke()
}

if( -not [String]::IsNullOrEmpty($file) ) {
    $details | Export-Csv -Encoding ascii -NoTypeInformation $file
}
else {
    $details | Format-Table -AutoSize
}
