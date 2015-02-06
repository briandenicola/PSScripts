param(
	[string] $config = ".\Configs\config.xml",
	[string] $setup = ".\Files\setup.exe"
)

Import-Module .\Modules\SPModule.misc
Import-Module .\Modules\SPModule.setup

Install-SharePoint -SetupExePath $setup -ConfigXMLPath $config -verbose