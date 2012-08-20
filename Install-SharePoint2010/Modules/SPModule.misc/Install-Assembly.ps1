# Requires -version 2.0

$SharePointServices = @("sptimerv4", "sptracev4", "spadminv4", "spusercodev4")

function Install-Assembly
{
	param
	(
		[Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]
		[String]$AssemblyPath
	)
	
	begin
	{
		if (-not (Test-Path $AssemblyPath))
		{
			throw [System.IO.FileNotFoundException]$AssemblyPath
		}
	
		Stop-SharePointServices
		Stop-IIS
	}
	
	process
	{
		Write-Warning "Only updating the GAC'd versions of the assembly..."
			
		$AssemblyName = Split-Path $AssemblyPath -Leaf
		
		$OldAssembly = Get-ChildItem -Path $env:WINDIR\assembly -Recurse -Filter $AssemblyName -ErrorAction SilentlyContinue
		
		if ($OldAssembly -eq $null)
		{
			throw [System.IO.FileNotFoundException]$AssemblyName
		}
		
		#Rename the old copy
		Rename-Item -Path $OldAssembly.FullPath -NewName ("{0}_{1}" -f $AssemblyName, (Get-Date -Format ddMMMyyyy-HHMMss))
		
		#Copy in the new version
		Copy-Item -Path $AssemblyPath -Destination (Split-Path $OldAssembly -Parent) -Force
		
	}
	
	end
	{
		Start-SharePointServices
		Start-IIS
	}
	
	
	
}

function Stop-SharePointServices
{
	foreach ($Service in $SharePointServices)
	{
		Stop-Service $Service -ErrorAction Inquire
	}
}

function Start-SharePointServices
{
	foreach ($Service in $SharePointServices)
	{
		Start-Service $Service -ErrorAction Inquire
	}
}

function Stop-IIS
{
	iisreset /noforce /stop | Out-Null
	
	if ($LASTEXITCODE -ne 0)
	{
		Write-Warning "Attemping to force stop..."
		iisreset /stop | Out-Null
	}
	
	if ($LASTEXITCODE -ne 0)
	{
		Write-Warning "Could not stop IIS"
	}
}

function Start-IIS
{
	iisreset /start | Out-Null
	
	if ($LASTEXITCODE -ne 0)
	{
		Write-Warning "Could not start IIS"
	}
}