param (
	[string[]] $computers
)

$cmd="Enable-PSRemoting -force;Enable-WSmanCredSSP -role server -force"
$cmdBytes = [System.Text.Encoding]::Unicode.GetBytes($cmd)
$cmdEncoded = [Convert]::ToBase64String($cmdBytes)

$creds = Get-Credential -Credential "$ENV:UserDomain\$ENV:UserName"

$computers | % {
	psexec \\$_ -u $creds.UserName -p $creds.GetNetworkCredential().Password cmd /c "echo . | powershell -EncodedCommand $cmdEncoded"
}
