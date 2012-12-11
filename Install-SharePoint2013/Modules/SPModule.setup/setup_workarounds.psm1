#Requires -version 2.0

#region Constants
$RegistryStrongName    = "HKLM:\SOFTWARE\Microsoft\StrongName\Verification"
$RegistryStrongNameWow = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\StrongName\Verification\"

$OfficePublicKeys = @("71e9bce111e9429c", "94de0004b6e3fcc5")
$SQLPublicKey    = "89845dcd8080cc91"
#endregion

#region exported functions
function Disable-OfficeSigningCheck
{	
	Write-Warning "Bypassing strong name check for all Office assemblies"
	foreach ($Key in $OfficePublicKeys)
	{
		Disable-SigningCheck -PublicKeyToken $Key
	}
}

function Disable-SQLSigningCheck
{	
	Write-Warning "Bypassing strong name check for SQL assemblies"
	Disable-SigningCheck -PublicKeyToken $SQLPublicKey
}

function Disable-AllSigningCheck
{
	Write-Warning "Bypassing strong name check for all assemblies"
	Disable-SigningCheck -PublicKeyToken "*"
}

function Enable-AllSigningCheck
{
	$AllBypassKeys = (Get-ChildItem -Path $RegistryStrongName) + (Get-ChildItem -Path $RegistryStrongNameWow)
	
	foreach ($Key in $AllBypassKeys)
	{
		Remove-RegistryKey $Key -Confirm -NoWarning
	}

}
#endregion

#region un-exported functions
function Disable-SigningCheck
{
	param
	(
		[Parameter(Mandatory=$true)]
		$PublicKeyToken
	)

	Write-Verbose ("Running bypass for public Key Token {0}" -f $PublicKeyToken )
	
	Set-RegistryKey -Node ("{0}\*,{1}" -f $RegistryStrongName, $PublicKeyToken) -OnlyKey
	Set-RegistryKey -Node ("{0}\*,{1}" -f $RegistryStrongNameWow, $PublicKeyToken) -OnlyKey
	
	#if running mul
	Stop-Service msiserver
}
#endregion 