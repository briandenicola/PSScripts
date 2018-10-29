function Set-Creds { 
    #$SCRIPT:creds = Get-Credential ( $ENV:USERDOMAIN + "\" + $ENV:USERNAME ) 
    $SCRIPT:creds = Get-Credential -Message "Please enter your domain password" -UserName ("{0}\{1}" -f $ENV:USERDOMAIN, $ENV:USERNAME )
}

function Get-Creds {
    if ( $SCRIPT:creds -eq $nul ) { Set-Creds }
    $SCRIPT:creds
}

Export-ModuleMember -Function Set-Creds, Get-Creds