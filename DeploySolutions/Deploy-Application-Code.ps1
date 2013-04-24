param ( 
	[Parameter(Mandatory=$true)]
	[string] $src,
	[Parameter(Mandatory=$true)]
	[string] $url,

    [string] $app,

	[switch] $record,

    [Parameter(ParameterSetName='interactive')]
    [switch]$interactive,

    [Parameter(ParameterSetName='auto')]
    [switch] $auto,

    [Parameter(ParameterSetName='auto',Mandatory=$true)]
    [ValidateSet("deploy-solutions", "enable-features", "deploy-configs", "install-msi", "uninstall-msi", "copy-to-gac")]
    [string[]] $ops
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

$global:deploy_steps = @()

Set-Variable -Name log_home -Value "D:\Logs" -Option Constant
Set-Variable -Name deploy_home -Value "D:\Deploy\AppSource" -Option Constant
Set-Variable -Name team_site -Value "http://team.example.com" -Option Constant
Set-Variable -Name team_list -Value "Deployment Tracker" -Option Constant
Set-Variable -Name team_view -Value '{4CB38665-FBC7-48DC-86A9-6ABF8B289EE6}' -Option Constant
Set-Variable -Name deploy_solutions -Value (Join-Path $ENV:SCRIPTS_HOME "DeploySolutions\Deploy-Sharepoint-Solutions.ps1") -Option Constant
Set-Variable -Name deploy_configs -Value (Join-Path $ENV:SCRIPTS_HOME "DeployConfig\DeployConfigs.ps1") -Option Constant
Set-Variable -Name enable_features -Value (Join-Path $ENV:SCRIPTS_HOME "DeploySolutions\Enable-Features.ps1") -Option Constant

$menu = @"
This script will deploy code for $app  . . .
`t1) Deploy $app Solutions
`t2) Enable $app Features
`t3) Deploy $app Web Config Files
`t4) Install MSI Files
`t5) Uninstall MSI Files
`t6) Install Files to GAC
`tQ) Quit
"@

function Get-SPUserViaWS( [string] $url, [string] $name )
{
	$service = New-WebServiceProxy ($url + "_vti_bin/UserGroup.asmx?WSDL") -Namespace User -UseDefaultCredential
	$user = $service.GetUserInfo("i:0#.w|$name")
	
	if( $user ) {
		return ( $user.user.id + ";#" + $user.user.Name )
	} 
}

function Record-Deployment { 
	param( 
		[string] $deploy_directory
	)
	
	Write-Host "============================"
	Write-Host "Here were the steps taken"
	$global:deploy_steps 
	Write-Host "============================"
	
	$code_version = Read-Host "Please enter the Code Version - example: $app-2010-3.1.0"
	$code_number = Read-Host "Please enter the Code Version Number- example: 11"
	
	$deploys = Get-SPListViaWebService -url $team_site -list $team_list -View $team_view 
	$existing_deploy = $deploys | where { $_.CodeVersion -eq $code_version -and $_.VersionNumber -eq $code_number } | Select -First 1

    $steps = @"
        $ENV:COMPUTERNAME Steps- 
        Automated with $MyInvocation.ScriptName. 
        Steps Taken include - $global:deploy_steps
"@
	
	if( ! $existing_deploy ) {
		$deploy = @{
			Title = "Automated WGC Deployment for $url"
			CodeLocation = $src
			DeploymentSteps = $steps
			CodeVersion = $code_version
			VersionNumber = $code_number
			Notes = "Deployed on $ENV:COMPUTERNAME from $deploy_directory . . .<BR/>"
		}
		
		$date = $(Get-Date).ToString("yyyy-MM-ddThh:mm:ssZ")
		$user = Get-SPUserViaWS -url $team_site -name ($ENV:USERDOMAIN + "\" + $ENV:USERNAME)
		
		if( $url -imatch "-uat" ) {
			$deploy.Add( 'UAT_x0020_Deployment', $date )
			$deploy.Add( 'UAT_x0020_Deployer', $user )
		} 
		else {
			$deploy.Add( 'Prod_x0020_Deployment', $date )
			$deploy.Add( 'Prod_x0020_Deployer', $user ) 
		}
	
		WriteTo-SPListViaWebService -url $team_site -list $team_list -Item $deploy
	}
	else { 
		$existing_deploy.Notes += "Deployed on $ENV:COMPUTERNAME from $deploy_directory . . .<BR/>"
		$existing_deploy.DeploymentSteps += $steps
		Update-SPListViaWebService -url $team_site -list $team_list -Item (Convert-ObjectToHash $existing_deploy) -Id  $existing_deploy.Id	
	}
}

function Deploy-Solutions {
	param( 
		[string] $deploy_directory
	)
	
	if($record) {
		$global:deploy_steps += "$deploy_solutions -web_application $url -deploy_directory $deploy_directory -noupgrade"
		$global:deploy_steps += "$deploy_configs -operation backup -url $url"
	}
	
	cd ( Join-Path $ENV:SCRIPTS_HOME "DeploySolutions" )
	&$deploy_solutions -web_application $url -deploy_directory $deploy_directory -noupgrade
	
	cd (Join-Path $ENV:SCRIPTS_HOME "DeployConfig" )
	&$deploy_configs -operation backup -url $url				
}

function Deploy-Config {
	
	if($record) {
		$global:deploy_steps += "$deploy_configs -operation deploy -url $url"
		$global:deploy_steps += "$deploy_configs -operation validate -url $url"
	}
	
	Write-Host "[ $(Get-Date) ] - Deploying Solutions for $url . . ."
	
	cd (Join-Path $ENV:SCRIPTS_HOME "DeployConfig" )
	&$deploy_configs -operation deploy -url $url
	&$deploy_configs -operation validate -url $url 
}

function Enable-Features {

	if($record) {
		$global:deploy_steps += "$enable_features -webApp $url"		
	}
	
	Write-Host "[ $(Get-Date) ] - Enabling Features for $url . . ."
	
	cd (Join-Path $ENV:SCRIPTS_HOME  "DeploySolutions" )
	&$enable_features -webApp $url			
}

function Install-MSIFile {
	param( 
		[string] $deploy_directory
	)

	if($record) {
		$global:deploy_steps += "dir $deploy_directory -filter *.msi | % { Start-Process -FilePath msiexec.exe -ArgumentList /i, $_.FullName -Wait  }"
	}
	
	dir $deploy_directory -Filter *.msi | % { 
		Write-Host "[ $(Get-Date) ] - Installing MSI - $($_.FullName)  . . ."
		Start-Process -FilePath msiexec.exe -ArgumentList /i, $_.FullName -Wait  
	} 
}

function Uninstall-MSIFile { 
	param( 
		[string] $deploy_directory
	)

	if($record) {
		$global:deploy_steps += "Get-Content (Join-Path $deploy_directory uninstall.txt) | % { Start-Process -FilePath msiexec.exe -ArgumentList /x,$_,/qn -Wait  }"
	}

	Get-Content (Join-Path $deploy_directory "uninstall.txt") | % { 
		Write-Host "[ $(Get-Date) ] - Removing MSI with ID - $_  . . ."
		Start-Process -FilePath msiexec.exe -ArgumentList /x,$_,/qn -Wait  
	} 
}

function DeployTo-GAC {

	param( 
		[string] $deploy_directory
	)

    $ans = [String]::Empty

	if($record) {
		$global:deploy_steps += "(Join-Path $ENV:SCRIPTS_HOME Misc-SPScripts\Install-Assemblies-To-GAC.ps1) -src $deploy_directory"
	}

    if( $interactive ) { 
        $ans = Read-Host "Type 'sp' to deploy to the GAC on all SharePoint WFE or hit enter to deploy locally"
    }

	$sb = {
		param( [string] $src ) 
		Write-Host "[ $(Get-Date) ] - Deploying to the GAC on $ENV:COMPUTER from $src . . ."
		$gac_script = (Join-Path $ENV:SCRIPTS_HOME "Misc-SPScripts\Install-Assemblies-To-GAC.ps1")
		&$gac_script -dir $src -verbose
	}
	
	if( $ans -match "sp" ) {
		Add-PSSnapin Microsoft.SharePoint.Powershell
		$type = "Microsoft SharePoint Foundation Web Application" 
		$servers = Get-SPServiceInstance | 
				Where { $_.TypeName -eq $type -and $_.Status -eq "Online" } | 
				Select -Expand Server | 
				Select -Expand Address 
		$cred = Get-Credential ($ENV:USERDOMAIN + "\" + $ENV:USERNAME)
		Invoke-Command -Computer $servers -Authentication CredSSP -Credential $cred -ScriptBlock $sb -ArgumentList $deploy_directory
	} else {
		&$sb -src $deploy_directory
	}
}

function Display-Menu {
    $ans = Read-Host "Do you want to copy files from $src to $deploy_home ? (y/n)"
	$deploy_directory = (Join-Path $deploy_home (Get-Item $src | Select -Expand Name))

	if( $ans -match "Y|y" ) {
		if( Test-Path $deploy_directory ) { move $deploy_directory ( $deploy_directory + "." +  $(Get-Date).ToString("yyyyMMddhhmmss") ) -Verbose }
		xcopy /e/v/f/s $src "$deploy_directory\"
	} 
	else { 
		$deploy_directory = $src
	}

	Write-Host "============================"
	Write-Host "Deployment Source Directory - $deploy_directory"
	Write-Host "Deployment URL - $url"
	
	do
	{
		Write-Host "============================"
		Write-Host $menu
		Write-Host "============================"
	
		$ans = Read-Host "Select 1-6"
		
		switch($ans.ToLower())
		{
			1 { Deploy-Solutions $deploy_directory; break }
			2 { Enable-Features; break } 
			3 { Deploy-Config; break }
			4 { Install-MSIFile $deploy_directory; break }
			5 { Uninstall-MSIFile $deploy_directory; break }
			6 { DeployTo-GAC $deploy_directory; break }
			q { if($record) { Record-Deployment $deploy_directory } ; break }
			default { 
				Write-Host "Invalid selection"
				break
			}
		}
	} while ( $ans -ne "q" )

}

function main 
{
	if( $url -notmatch "http://" ) {
		$url = $url.Insert( 0, "http://" )
	}

	$log = Join-Path $log_home ("Deploy-For-" + ( $url -replace "http://") + "-From-" + $ENV:COMPUTERNAME + "-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".log")
	&{Trap{continue};Start-Transcript -Append -Path $log}

	if( $interactive ) { Display-Menu }

    if( $auto ) { 
        foreach( $op in $ops ) {
            if( $op -eq "deploy-solutions" ) { Deploy-Solutions -deploy_directory $src }
            if( $op -eq "enable-features" ) { Enable-Features }
            if( $op -eq "deploy-configs" ) { Deploy-Config }
            if( $op -eq "install-msi" ) { Install-MSIFile -deploy_directory $src }
            if( $op -eq "uninstall-msi" ) { UnInstall-MSIFile -deploy_directory $src }
            if( $op -eq "copy-to-gac" ) { DeployTo-GAC -deploy_directory $src } 
        }
    } 
    
	Stop-Transcript
}
main