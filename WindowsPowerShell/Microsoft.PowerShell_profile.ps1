dir (Join-PATH $ENV:SCRIPTS_HOME "Libraries") -filter *.ps1 | % { Write-Host $(Get-Date) " - Sourcing " $_.FullName -foreground green ; . $_.FullName }
dir (Join-PATH $ENV:SCRIPTS_HOME "Libraries") -filter *.psm1 | % { Write-Host $(Get-Date) " - Import Module " $_.FullName -foreground green ; Import-Module $_.FullName }

Write-Host $(Get-Date) " - Getting SharePoint servers stored in `$sp variable" -foreground green
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

$MaximumHistoryCount=1024 
$SCRIPTS = "$HOME\scripts"
$CODE = "$HOME\code"
$env:EDITOR = (Join-PATH $ENV:SCRIPTS_HOME "NotePad++\notepad++.exe")

New-Alias -name gh -value Get-History 
New-Alias -name i -value Invoke-History
New-Alias -name ed -value $env:EDITOR

if( (Test-Connection ent-nas-fs01) -and (Test-Path \\ent-nas-fs01.us.gt.com\app-ops) )
{
	Write-Host $(Get-Date) " - Setting up Repo to \\ent-nas-fs01.us.gt.com\app-ops" -foreground green
	New-PSdrive -name Repo -psprovider FileSystem -root \\ent-nas-fs01.us.gt.com\app-ops | Out-Null
}

function Resize-Screen
{
	param (
		[int] $width
	)
	$h = get-host
	$win = $h.ui.rawui.windowsize
	$buf = $h.ui.rawui.buffersize
	$win.width = $width # change to preferred width
	$buf.width = $width
	$h.ui.rawui.set_buffersize($buf)
	$h.ui.rawui.set_windowsize($win)
}

function Get-Profile
{
	ed $profile
}

function Add-IISFunctions
{
	$lib = (Join-PATH $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")
	Write-Host $(Get-Date) " - Sourcing $lib"
	. $lib
}
New-Alias -Name iis -Value Add-IISFunctions

function Remove-TempFolder
{
	rm.exe -rf $ENV:TEMP
}

function Add-Azure
{
	Write-Host $(Get-Date) " - Importing Azure Module"
	Push-Location $PWD.Path
	cd  "C:\Program Files (x86)\Microsoft SDKs\Windows Azure\PowerShell\"
	Import-Module "C:\Program Files (x86)\Microsoft SDKs\Windows Azure\PowerShell\Microsoft.WindowsAzure.Management.psd1"
	Pop-Location 
}
New-Alias -Name Azure-Tools -Value Add-Azure

function Add-QuestTools
{
	Write-Host $(Get-Date) " - Adding Quest Snappin" -foreground green
	Add-PSSnapin Quest.*
}
New-Alias -Name Quest -Value Add-QuestTools

function Add-PowerShellCommunityExtensions
{
	Write-Host $(Get-Date) " - Adding PowerShell Community Extensions Module" -foreground green
	Import-Module pscx
}
New-Alias -Name pscx -Value Add-PowerShellCommunityExtensions

function Add-SQLProviders
{
	Add-PSSnapin SqlServerCmdletSnapin100
	Add-PSSnapin SqlServerProviderSnapin100
}
New-Alias -Name sql -Value Add-SQLProviders

function Edit-HostFile
{
	&$env:editor c:\Windows\System32\drivers\etc\hosts
}
Set-Alias -Name hf -Value Edit-HostFile

function rsh 
{
	param ( [string] $computer )
	Enter-PSSession -ComputerName $computer -Credential (Get-Creds) -Authentication Credssp
}

function rexec
{
	param ( [string[]] $computers = "localhost", [Object] $sb )
	Invoke-Command -ComputerName $computers -Credential (Get-Creds) -Authentication Credssp -ScriptBlock $sb
}

function Remove-OfficeLogs
{
	Remove-Item D:\*.log -ErrorAction SilentlyContinue
	Remove-Item C:\*.log -ErrorAction SilentlyContinue
}
Remove-OfficeLogs

function Go-Home
{
	cd $home
}
Set-Alias -Name home -Value Go-Home

function Go-Code
{
	cd $Code\Scripts-Production
}
Set-Alias -Name code -Value Go-Code

remove-item alias:cd
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

function shorten-path([string] $path) { 
   $loc = $path.Replace($HOME, '~') 
   # remove prefix for UNC paths 
   $loc = $loc -replace '^[^:]+::', '' 
   # make path shorter like tabs in Vim, 
   # handle paths starting with \\ and . correctly 
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

remove-item alias:ls
set-alias ls Get-ChildItemColor
 
function Get-ChildItemColor {
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

$p = "01000000d08c9ddf0115d1118c7a00c04fc297eb010000008472d4720c6bd04e8012a5900bf3f68d0000000002000000000003660000c0000000100000000d4ae7c5added9bbecc4a05db0fc00480000000004800000a00000001000000017a65532dd8bd8eda2551db1eee32ff4300000004ef279701445e89bd1e8a68bdf08e9232ddb5bf0a182615ccd8660f02e38fc247c9494c35d35dd997d0aa19d4138bf8514000000638fe960622e2daa49173628362b876b0234a433"
Set-Creds (New-Object System.Management.Automation.PSCredential $ENV:USERNAME, (ConvertTo-SecureString $p))



