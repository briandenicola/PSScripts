. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
Import-Module -Name posh-git
Import-Module CredentialManager

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$MaximumHistoryCount=1024
$env:EDITOR = "C:\Program Files\Microsoft VS Code\Code.exe"
$pub_key_file = "C:\Users\brian\.ssh\id_rsa.pub"

New-Alias -name gh    -value Get-History 
New-Alias -name i     -Value Invoke-History
New-Alias -name ed    -Value $env:EDITOR
New-Alias -Name code  -Value $env:EDITOR

#Set-Location -Path $github_path 
Set-PSReadlineKeyHandler -Key Tab -Function Complete

function Get-VPNPassword 
{
  $vpn = ""
  $secure_password = Get-StoredCredential -Target $vpn | Select-Object -ExpandProperty Password
  Get-PlainTextPassword -password (ConvertFrom-SecureString $secure_password) | Set-Clipboard
  Write-Verbose -Message "Password sent to clip board"
}
Set-Alias -Name vpn -Value Get-VPNPassword

function Get-PublicKey 
{
  Get-Content -Path $pub_key_file | Set-Clipboard
}
Set-Alias -Name pubkey -Value Get-PublicKey

function Move-Images 
{
  $src = "D:\\Pictures\\InstaPic\\Saved\*"
  $dst = "E:\\Backups\\Photos\\Instagram"
  
  try {
    Move-Item -Path $src -Destination $dst -Verbose
  }
  catch {}
}

function Get-Profile
{
	ed $profile
}

function Edit-HostFile
{
	&$env:editor c:\Windows\System32\drivers\etc\hosts
}
Set-Alias -Name hf -Value Edit-HostFile

function Go-Home
{
	Set-Location -Path $home
}
Set-Alias -Name home -Value Go-Home

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
   $loc = $loc -replace '^[^:]+::', '' 
   return ($loc -replace '\\(\.?)([^\\])[^\\]*(?=\\)','\$1$2') 
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