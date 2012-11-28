$src = ""

Write-Host "Installing Web Platform Installer v3 . . ."
msiexec /i (Join-Path $src "WebPlatformInstaller_3_10_amd64_en-US.msi") /qb

sleep 20

Write-Host "Installing Web Deploy 2.1 . . ."
msiexec /i (Join-Path $src "WebDeploy_2_10_amd64_en-US.msi") /qb

sleep 20

Write-Host "Installing Farm Framework 2.2 . . ."
msiexec /i (Join-Path $src "WebFarm2_x64.msi") /qb

sleep 20