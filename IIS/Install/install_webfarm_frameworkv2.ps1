$url = "http://go.microsoft.com/fwlink/?LinkID=145505"
$installer = "D:\Utils\WebPi\Webpi_installer.exe"
$cmdline = "D:\Utils\WebPI\WebpiCmdLine.exe"

$wc = New-Object System.Net.WebClient
$wc.DownloadFile($url, $installer)

&$installer

Sleep 5

Stop-Process (Get-Process "WebPlatformInstaller").Id

&$cmdline /Products:WebFarmFrameworkv2 /AcceptEula /SuppressReboot