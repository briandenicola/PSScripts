[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[Parameter(Mandatory=$true)]
	[string[]] $servers,
	[switch] $set
)

Invoke-Command -ComputerName $servers -ScriptBlock { 
	param ( $set )
	
	Write-Host $ENV:COMPUTERNAME
	Get-ItemProperty -Path HKLM:\Software\Microsoft\MSDTC\Security 
	
	if( $set ) 
	{
		Set-ItemProperty -Path HKLM:\Software\Microsoft\MSDTC -name AllowOnlySecureRpcCalls -value 0
		Set-ItemProperty -Path HKLM:\Software\Microsoft\MSDTC -name TurnOffRpcSecurity -Value 1
		Set-ItemProperty -Path HKLM:\Software\Microsoft\MSDTC\Security -name LuTransactions -value 1
		Set-ItemProperty -Path HKLM:\Software\Microsoft\MSDTC\Security -name NetworkDtcAccess -value 1
		Set-ItemProperty -Path HKLM:\Software\Microsoft\MSDTC\Security -name NetworkDtcAccessAdmin -value 1
		Set-ItemProperty -Path HKLM:\Software\Microsoft\MSDTC\Security -name NetworkDtcAccessClients -value 1
		Set-ItemProperty -Path HKLM:\Software\Microsoft\MSDTC\Security -name NetworkDtcAccessInbound -value 1
		Set-ItemProperty -Path HKLM:\Software\Microsoft\MSDTC\Security -name NetworkDtcAccessOutbound -value 1
		Set-ItemProperty -Path HKLM:\Software\Microsoft\MSDTC\Security -name NetworkDtcAccessTransactions -value 1
		Set-ItemProperty -Path HKLM:\Software\Microsoft\MSDTC\Security -name XaTransactions -value 1
		Get-ItemProperty -Path HKLM:\Software\Microsoft\MSDTC\Security 
		Stop-Service msdtc -Verbose
		Start-Service msdtc -Verbose
		Set-Service msdtc -StartupType Automatic -Verbose
	}

} -ArgumentList $set
