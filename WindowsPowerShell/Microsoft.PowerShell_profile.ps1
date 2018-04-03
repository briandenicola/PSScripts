﻿. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
Import-Module -Name posh-git

$MaximumHistoryCount=1024
$github_path = ""
$download_path = ""
$working_path = ""
$env:EDITOR = ""
$pub_key_file = "C:\Users\brdenico\OneDrive\Documents\Keys\Putty\ssh_openssh_version_pub.txt"

New-Alias -name gh -value Get-History 
New-Alias -name i -value Invoke-History
New-Alias -name ed -value $env:EDITOR

Set-Location -Path $github_path 
Set-PSReadlineKeyHandler -Key Tab -Function Complete

function Get-PublicKey 
{
  Get-Content -Path $pub_key_file | Set-Clipboard
}

function Move-Images 
{
  $src = "D:\\Pictures\\InstaPic\\Saved\*"
  $dst = "E:\\Backups\\Photos\\Instagram"
  
  try {
    Move-Item -Path $src -Destination $dst -Verbose
  }
  catch {}
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

function Set-Downloads
{
    Set-Location -Path $download_path 
}
New-Alias -Name downloads -Value Set-Downloads

function Set-GitHub
{
    Set-Location -Path $github_path 
}
New-Alias -Name github -Value Set-GitHub

function Set-Working
{
    Set-Location -Path $working_path 
}
New-Alias -Name working -Value Set-Working

function Get-Profile
{
	ed $profile
}

function Edit-HostFile
{
  ed (Join-Path -Path $ENV:SystemRoot -ChildPath "System32\drivers\etc\hosts")
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

function Set-Home
{
	Set-Location -Path $home
}
Set-Alias -Name home -Value Set-Home

function Set-Scripts
{
	Set-Location -Path $ENV:SCRIPTS_HOME
}
Set-Alias -Name scripts -Value Set-Scripts 

Remove-Item alias:cd
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

function Shorten-Path([string] $path) { 
   $loc = $path.Replace($HOME, '~') 
   $loc = $loc -replace '^[^:]+::', '' 
   return ($loc -replace '\\(\.?)([^\\])[^\\]*(?=\\)','\$1$2') 
}

& {
    for ($i = 0; $i -lt 26; $i++) 
    { 
        $funcname = ([System.Char]($i+65)) + ':'
        $str = "function global:$funcname { set-location $funcname } " 
        Invoke-Expression $str 
    }
}

Remove-Item alias:ls
Set-Alias ls Get-ChildItemColor
 
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
# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}
