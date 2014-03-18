function Set-Office365Creds {
    param ([string] $account )
	$SCRIPT:offic365_creds = Get-Credential $account
}

function Get-Office365Creds {
    param ( [string] $account )
	if( $SCRIPT:offic365_creds -eq $nul ) { Set-Office365Creds -account $account }
	return $SCRIPT:offic365_creds
}

Export-ModuleMember -Function Set-Office365Creds, Get-Office365Creds