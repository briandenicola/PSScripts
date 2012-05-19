#Requires -version 2.0

function Enable-VerboseMsiLogging
{
	[CmdletBinding()]
	param()
	
	begin
	{
	}
	
	process
	{
	
	}
	
	end
	{
		Set-RegistryKey -Node "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Key "Logging" -Value "voicewarmup" -ValueType String 
		Set-RegistryKey -Node "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Key "debug" -Value 7 -ValueType DWord
		
		Set-RegistryKey -Node HKLM:\Software\Microsoft\Office\12.0\Common\VerboseSetupLogging -OnlyKey 
		Set-RegistryKey -Node HKLM:\Software\Microsoft\Office\14.0\Common\VerboseSetupLogging -OnlyKey
	}
}