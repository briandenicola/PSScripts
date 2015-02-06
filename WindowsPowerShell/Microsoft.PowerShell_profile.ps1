Import-Module PsReadLine
Import-Module PsGet
Import-Module PsUrl

Set-Variable -Name sp -Option AllScope
Set-Variable -Name apps -Option AllScope
Set-Variable -Name xenapp -Option AllScope
Set-Variable -name GithubRepo -Value "D:\Code\PSScripts"

function Resize-Screen 
{
	param (
		[int] $width,
        [int] $height
	)

	$h = get-host
	$win = $h.ui.rawui.windowsize
	$buf = $h.ui.rawui.buffersize

	$win.width = $width 
    $win.height = $height

	$buf.width = $width
    $buf.Height = $height * 3

	$h.ui.rawui.set_buffersize($buf)
	$h.ui.rawui.set_windowsize($win)
}

function Set-SharePointServers
{
	Write-Output ("{0} - Getting SharePoint servers stored in `$sp variable" -f $(Get-Date))

	$sp = New-Object PSObject -Property @{
		Servers = (Get-SharePointServersWS -version 2007) + (Get-SharePointServersWS -version 2010) 
	}
	$sp | Add-Member -MemberType ScriptMethod -Name Filter -Value { 
		param( 
			[string] $farm = ".*",
			[string] $env = ".*",
			[string] $name = ".*"
		)
		
		$this.Servers | ? { $_.Farm -imatch $farm -and $_.Environment -imatch $env -and $_.SystemName -imatch $name } | Select -Expand SystemName
	}
	$sp | Add-Member -MemberType ScriptMethod -Name CycleIIS -Value { 
		param( 
			[string] $farm = ".*",
			[string] $env = ".*",
			[string] $name = ".*"
		)
		
		$computers = $this.Servers | ? { $_.Farm -imatch $farm -and $_.Environment -imatch $env -and $_.SystemName -imatch $name } | Select -Expand SystemName 
		foreach( $computer in $computers ) {
			Write-Host "[ $(Get-Date) ] - Cycling IIS on $computer ..."
			iisreset $computer
		}
	}

	$sp | Add-Member -MemberType ScriptMethod -Name CycleService -Value { 
		param( 
			[string] $farm = ".*",
			[string] $env = ".*",
			[string] $name = ".*",
			[string] $service = "sptimerv4"
		)
		
		$computers = $this.Servers | ? { $_.Farm -imatch $farm -and $_.Environment -imatch $env -and $_.SystemName -imatch $name } | Select -Expand SystemName 
		foreach( $computer in $computers ) {
			Write-Host "[ $(Get-Date) ] - Cycling $service on $computer ..."
			sc.exe \\$computer stop $service
			Sleep 1
			sc.exe \\$computer start $service
			sc.exe \\$computer query $service
		}
	}
}

function Set-AppOpsServers 
{

    $url = ""
	Write-Output ("{0} - Getting AppOps servers stored in `$apps variable" -f $(Get-Date))
	
	$apps = New-Object PSObject -Property @{
		Servers = Get-SPListViaWebService -url $url -List AppServers
	}
	
	$apps | Add-Member -MemberType ScriptMethod -Name Filter -Value { 
		param( 
			[string] $name = ".*",
			[string] $env = ".*"
		)

		$this.Servers | ? { $_.Environment -imatch $env -and $_.SystemName -imatch $name } | Select -Expand SystemName
	}
}

function Set-CitrixServers 
{

    $url = ""
	Write-Output ("{0} - Getting Citrix servers stored in `$citrix variable" -f $(Get-Date))
	
	$xenapp = New-Object PSObject -Property @{
		Servers = Get-SPListViaWebService -url $url -List "Citrix Servers"
	}
	
	$xenapp | Add-Member -MemberType ScriptMethod -Name Filter -Value { 
		param( 
			[string] $name = ".*",
			[string] $version = ".*"
		)

		$this.Servers | ? { $_.Environment -imatch $env -and $_.SystemName -imatch $name } | Select -Expand SystemName
	}
}

function Set-PSDrives 
{
	$computer = ""
	$repos = @(
		@{Name = "Repo"; Location="\SharePoint2010-Utils-Scripts"},
		@{Name = "SharePoint"; Location="\Installs\SharePoint" },
		@{Name = "NAS"; Location="\\"},
		@{Name = "Git"; Location=$GithubRepo}
	)
	
	if( !(Test-Connection $computer) ) {
		Write-Error ("Could reach out to {0}. Returning." -f $computer)
		return 
	}

	foreach( $repo in $repos ) {
	    if( Test-Path $repo.Location ) {
		    Write-Output ("{0} - Setting up {1} to {2}" -f $(Get-Date),$repo.Name, $repo.Location) 
		    New-PSdrive -name $repo.Name -psprovider FileSystem -root $repo.Location -Scope Global | Out-Null
	    }
    }
}

function Remove-OfficeLogs
{
	Remove-Item D:\*.log -ErrorAction SilentlyContinue
	Remove-Item C:\*.log -ErrorAction SilentlyContinue
}

function Remove-TempFolder
{
	Remove-Item -Recurse -Force $ENV:TEMP -ErrorAction SilentlyContinue
}

function Get-Profile
{
	ed $profile
}

function Add-QuestTools
{
	Write-Output ("{0} - Sourcing {1}" -f $(Get-Date),"Quest Tools")
	Add-PSSnapin Quest.*
}

function Add-PowerShellCommunityExtensions
{
	Write-Output ("{0} - Sourcing {1}" -f $(Get-Date),"PowerShell Extensions" )
	Import-Module pscx
}

function Add-SQLProviders
{
	Add-PSSnapin SqlServerCmdletSnapin100
	Add-PSSnapin SqlServerProviderSnapin100
}

function Edit-HostFile
{
	&$env:editor c:\Windows\System32\drivers\etc\hosts
}

function rsh 
{
	param ( [string] $computer )
	Enter-PSSession -ComputerName $computer -Credential (Get-Creds) -Authentication Credssp
}

function rexec
{
	param (
		[Parameter(Mandatory=$true)]
		[string[]] $computers = $ENV:ComputerName,
		
		[Parameter(ParameterSetName="ScriptBlock")]
		[ScriptBlock] $sb = {}, 
		
		[Parameter(ParameterSetName="FilePath")]
		[string] $file = [string]::empty,
		[Parameter(ParameterSetName="FilePath")]
		[Object[]] $args = @()
	)
	
	switch ($PsCmdlet.ParameterSetName)
    { 
		"FilePath" 		{ Invoke-Command -ComputerName $computers -Credential (Get-Creds) -Authentication Credssp -FilePath $file -ArgumentList $args }
		"ScriptBlock" 	{ Invoke-Command -ComputerName $computers -Credential (Get-Creds) -Authentication Credssp -ScriptBlock $sb }
	}
}

function Goto-Home
{
	Set-Location $home
}

function Goto-Code
{
	Set-Location $Code
}

function Goto-GitHub
{
	Set-Location $GithubRepo
}

function cd 
{
	param ( $location ) 

	if( $location -eq '-' ) 
	{
		pop-location
	}
	else
	{
		push-location $pwd.path
		Set-location $location
	}
}

function shorten-path([string] $path)
{ 
   $loc = $path.Replace($HOME, '~') 
   $loc = $loc -replace '^[^:]+::', '' 
   return ($loc -replace '\\(\.?)([^\\])[^\\]*(?=\\)','\$1$2') 
}

function prompt
{
	if($UserType -eq "Admin") {
    	$host.UI.RawUI.WindowTitle = "" + $(get-location) + " : Admin"
       	$host.UI.RawUI.ForegroundColor = "white"
    }
    else {
       $host.ui.rawui.WindowTitle = $(get-location)
    }
    "[$ENV:ComputerName] " + $(shorten-path (get-location)) + "> "
}

& {
    for ($i = 0; $i -lt 26; $i++) 
    { 
        $funcname = ([System.Char]($i+65)) + ':'
        $str = "function global:$funcname { set-location $funcname } " 
        invoke-expression $str 
    }
}

function Get-ChildItemColor 
{
    $fore = $Host.UI.RawUI.ForegroundColor
 
    Invoke-Expression ("Get-ChildItem $args") |
    %{
      if ($_.GetType().Name -eq 'DirectoryInfo') {
        $Host.UI.RawUI.ForegroundColor = 'White'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
      } elseif ($_.Name -match '\.(zip|tar|gz|rar)$') {
        $Host.UI.RawUI.ForegroundColor = 'DarkGray'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
      } elseif ($_.Name -match '\.(exe|bat|cmd|py|pl|ps1|psm1|vbs|rb|reg)$') {
        $Host.UI.RawUI.ForegroundColor = 'DarkCyan'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
      } elseif ($_.Name -match '\.(txt|cfg|conf|ini|csv|sql|xml|config)$') {
        $Host.UI.RawUI.ForegroundColor = 'Cyan'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
      } elseif ($_.Name -match '\.(cs|asax|aspx.cs)$') {
        $Host.UI.RawUI.ForegroundColor = 'Yellow'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
       } elseif ($_.Name -match '\.(aspx|spark|master)$') {
        $Host.UI.RawUI.ForegroundColor = 'DarkYellow'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
       } elseif ($_.Name -match '\.(sln|csproj)$') {
        $Host.UI.RawUI.ForegroundColor = 'Magenta'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
	   } elseif ($_.Name -match '\.(docx|doc|xls|xlsx|pdf|mobi|epub|mpp|)$') {
        $Host.UI.RawUI.ForegroundColor = 'Gray'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
       }
        else {
        $Host.UI.RawUI.ForegroundColor = $fore
        echo $_
      }
    }
}

function Start-MyApplications 
{
	Start-Process outlook.exe
	Start-Process lync.exe
	& 'C:\Program Files (x86)\Mozilla Firefox\firefox.exe' -new-window http://usgt.kanbanize.com
	Start-Sleep -Seconds 4
	& 'C:\Program Files (x86)\Mozilla Firefox\firefox.exe' http://pingdom.com
	& 'C:\Program Files (x86)\Mozilla Firefox\firefox.exe' http://newrelic.com
	& 'C:\Program Files (x86)\Mozilla Firefox\firefox.exe' http://appops.gt.com
	& 'C:\Program Files (x86)\Mozilla Firefox\firefox.exe' http://appops.gt.com/sites
	& 'C:\Program Files (x86)\Internet Explorer\iexplore.exe' http://team.gt.com/sites/ApplicationOperations/
	& 'C:\Program Files\Microsoft System Center 2012 R2\Operations Manager\Console\Microsoft.EnterpriseManagement.Monitoring.Console.exe'
	Set-location $code
	tf.exe get
}

$MaximumHistoryCount=1024 
$CODE = "D:\Code\GT\Operations"
$env:EDITOR = "C:\Program Files (x86)\Notepad++\notepad++.exe"

Get-ChildItem (Join-PATH $ENV:SCRIPTS_HOME "Libraries") -filter *.ps1 | 
	Foreach { 
		Write-Output ("{0} - Sourcing {1}" -f $(Get-Date), $_.FullName)
		. $_.FullName 
	}
	
Get-ChildItem (Join-PATH $ENV:SCRIPTS_HOME "Libraries") | 
	Where { $_.Name -imatch "\.psm1|\.dll" } | 
	Foreach {
		Write-Output ("{0} - Import Module {1}" -f $(Get-Date), $_.FullName)
		Import-Module $_.FullName 
	}

Remove-Item alias:ls
Remove-Item alias:cd

Set-Alias -Name hf -Value Edit-HostFile
Set-Alias -Name ls -Value Get-ChildItemColor
Set-Alias -Name code -Value Goto-Code
Set-Alias -Name github -Value Goto-GitHub
Set-Alias -Name home -Value Goto-Home
Set-Alias -Name tp -value Test-Path

New-Alias -Name pscx -Value Add-PowerShellCommunityExtensions
New-Alias -Name sql -Value Add-SQLProviders
New-Alias -name gh -value Get-History 
New-Alias -name i -value Invoke-History
New-Alias -name ed -value $env:EDITOR
New-Alias -Name Quest -Value Add-QuestTools
New-Alias -Name go -Value Start-MyApplications 

Set-SharePointServers
Set-AppOpsServers
Set-CitrixServers
Set-PSDrives
Set-Creds -creds $cred
Resize-Screen -width 210 -height 65
Remove-OfficeLogs
Remove-TempFolder

Set-location $code


