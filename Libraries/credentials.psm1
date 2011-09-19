function Set-Creds { 
	$SCRIPT:creds = Get-Credential ( $ENV:USERDOMAIN + "\" + $ENV:USERNAME ) 
}

function Get-Creds {
	 if( $SCRIPT:creds -eq $nul ) { Set-Creds }
	 $SCRIPT:creds
}

Export-ModuleMember -Function Set-Creds, Get-Creds
