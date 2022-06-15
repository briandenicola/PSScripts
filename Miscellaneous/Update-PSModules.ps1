function Get-PSModuleDirectory { 
    return  (Get-EnvironmentVariable -Key PSModulePath).Split(";")[0]
}

function Find-LatestGithubReleaseVersion {
    param(
        [string] $Url
    )

    $release = Invoke-RestMethod $url 

    return @{
        Name    = $release.assets.name
        ZipUri  = $release.assets.browser_download_url
        Version = $release.zipball_url.Split("/")[-1]
    }
}

function Get-LatestGithubReleaseVersion {
    param(
        [HashTable] $Release
    )

    $OutputLocation = Join-Path $ENV:TEMP -ChildPath $Release.Name
    Invoke-WebRequest -Uri $Release.ZipUri -OutFile $OutputLocation | Out-Null
    
    return $OutputLocation
}

function Install-Release {
    param(
        [string] $ModuleName,
        [string] $ModuleVersion,
        [string] $ZipLocation
    )

    $RootModule = Get-PSModuleDirectory
    $ModulePath = Join-Path -Path $RootModule -ChildPath $ModuleName

    $ExpandedPath = Join-Path -Path $RootModule -ChildPath ("{0}\{1}" -f $ModuleName,$ModuleName)
    $ProperPath = Join-Path -Path $RootModule -ChildPath ("{0}\{1}" -f $ModuleName,$ModuleVersion)

    New-Item -Type Directory -Path $ModulePath -Force | Out-Null
    Expand-Archive -Path $ZipLocation -DestinationPath $ModulePath -Force
    Move-Item -Path $ExpandedPath -Destination $ProperPath -Force | Out-Null
    Remove-Item -Path $ZipLocation -Force -Confirm:$false
}

$modules = @(
    @{ Name = "bjd.Common.Functions"; Uri = "https://api.github.com/repos/briandenicola/psscripts/releases/latest" }
    @{ Name = "bjd.Azure.Functions"; Uri = "https://api.github.com/repos/briandenicola/azure/releases/latest" }
)

  
foreach( $module in $modules ) {
    $release = Find-LatestGithubReleaseVersion -Url $module.Uri
    $location = Get-LatestGithubReleaseVersion -Release $release

    Install-Release -ModuleName $module.Name -ModuleVersion $release.Version -ZipLocation $location
    Get-Module -Name $module.Name -ListAvailable | Format-Table -Property Name, Version, ModuleBase
}  