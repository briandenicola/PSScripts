Set-Variable -Name results -Value @() -Option AllScope
Set-Variable -Name session -value $null -Option AllScope
Set-Variable -Name features -Value $null -Option AllScope

#Region - Create PS Remoting Object
function Create-PSRemoteSession {
    param (
        [string] $computer
    )
    $session = New-PSSession -Computer $computer 
}
#EndRegion

#Region - Delete PS Remoting Object and Reset Variables 
function Delete-PSRemoteSession {
    param (
        [string] $computer
    )
    $features = $null
    $session = $null
    Get-PSSession | Remove-PSSession
}
#EndRegion

#Region - Write Output for results object
function Write-Results {
    param (
        [switch] $log,
        [string] $log_file
    )

    Write-Verbose ("Log - " + $log.ToString() )
    Write-Verbose ("LogFile - " + $log_file )

    "=" * 20 
    Write-Host "== RESULTS =="

    foreach( $result in $results ) { 
        $out = "[{0}][{1}] - {2} [{3}]" -f $(Get-Date), $result.Computer, $result.text, $result.Result.ToString().ToUpper()
        if( $result.Result ) { Write-Host $out -ForegroundColor Green } else { Write-Warning $out }
    }

    if( $log ) { $results | Export-Csv -NoTypeInformation -Encoding Ascii $log_file }
}
#Region

#Region - Get All Features Installed on System
function Get-ServerFeatures {
    $features = Invoke-Command -Session $session -ScriptBlock { ImportSystemModules;return(Get-WindowsFeature | Where { $_.Installed -eq $true  } | Select Name) } | Select -ExpandProperty Name
}
#EndRegion

#Region - Test PowerShell Remoting
function Test-Remoting {
   param([string] $computer)
    Invoke-Command -ComputerName $computer { 1 }  -ErrorAction SilentlyContinue 
    return $? 
}
#EndRegion

#Region - Test PowerShell Remoting with CredSSP
function Test-CredSSP {
   param(
        [string] $computer,
        [Object] $rule
    )

    Write-Host ("[{0}] - Testing Rule - {1} . . ." -f $(Get-Date), $rule.Description)
    
    Invoke-Command -ComputerName $computer { 1 } -Credential (Get-Creds) -Authentication Credssp -ErrorAction SilentlyContinue 

    $result = $?
    $results += New-Object PSObject -Property @{
        Computer = $computer
        Text = $rule.Description
        Result = $result
    }

    Write-Verbose ("Result - " + $result.ToString().ToUpper())
    return $result
}
#EndRegion

#Region - Test A File Path
function Test-FilePath {
    param(
        [string] $computer,
        [Object] $rule 
    )

    Write-Host ("[{0}] - Testing Rule - {1} . . ." -f $(Get-Date), $rule.Description)

    $path = "\\" + $computer + "\" + $rule.Path.Replace(":","$") 

    $result = Test-Path $path
    $results += New-Object PSObject -Property @{
        Computer = $computer
        Text = $rule.Description
        Result = $result
    }

    Write-Verbose ("Result - " + $result.ToString().ToUpper())
    return $result
}
#EndRegion

#Region - Test Group Members
function Test-GroupMemberShip {
    param(
        [string] $computer,
        [Object] $rule 
    )
    
    Write-Host ("[{0}] - Testing Rule - {1} . . ." -f $(Get-Date), $rule.Description)

    $users = Get-LocalGroup -computer $computer -Group $rule.Group

    if( $rule.Present -eq $true  ) { 
        $result = $users -contains $rule.User
    }
    else {
        $result = $users -notcontains $rule.User
    }

    $results += New-Object PSObject -Property @{
        Computer = $computer
        Text = $rule.Description
        Result = $result
    }

    Write-Verbose ("Result - " + $result.ToString().ToUpper())
    return $result
}
#EndRegion

#Region - Environmental Variable
function Test-EnvVariable {
    param(
        [string] $computer,
        [Object] $rule 
    )
    
    Write-Host ("[{0}] - Testing Rule - {1} . . ." -f $(Get-Date), $rule.Description)

    $variable = Get-WmiObject -Class Win32_Environment -ComputerName $computer | Where { $_.Name -eq $rule.Name }  
    
    $result = ($variable -ne $null) -and ( $variable.VariableValue -eq $rule.Value )
    $results += New-Object PSObject -Property @{
        Computer = $computer
        Text = ( $rule.Description + " = " + $rule.Value)
        Result = $result
    }

    Write-Verbose ("Result - " + $result.ToString().ToUpper())
    return $result
}
#EndRegion

#Region - Test for the Existence of a Schedule Task
function Test-ScheduleTask {
    param(
        [string] $computer,
        [Object] $rule 
    )
    
    Write-Host ("[{0}] - Testing Rule - {1} . . ." -f $(Get-Date), $rule.Description)

    $task = Get-ScheduledTasks -server $computer | Where { $_.Name -eq $rule.Name } 
    
    $result = $task -ne $null
    $results += New-Object PSObject -Property @{
        Computer = $computer
        Text = $rule.Description
        Result = $result
    }

    Write-Verbose ("Result - " + $result.ToString().ToUpper())
    return $result
}
#EndRegion

#Region - Test for the Existence of a Windows Feature
function Test-WindowsFeature {
    param(
        [string] $computer,
        [Object] $rule
    )
    
    Write-Host ("[{0}] - Testing Rule - {1} . . ." -f $(Get-Date), $rule.Description)

    if( $features -eq $null ) { Get-ServerFeatures }

    $result = $features -contains $rule.Name 
    $results += New-Object PSObject -Property @{
        Computer = $computer
        Text = $rule.Description
        Result = $result
    }

    Write-Verbose ("Result - " + $result.ToString().ToUpper())
    return $result
}
#EndRegion

#Region - Test for the Existence of a Windows Share
function Test-Share {
    param(
        [string] $computer,
        [Object] $rule 
    )
    
    Write-Host ("[{0}] - Testing Rule - {1} . . ." -f $(Get-Date), $rule.Description)
    $shares = Get-WmiObject -Class Win32_Share -ComputerName $computer | Where { $_.Name -imatch $rule.ShareName }

    $result = $shares -ne $null
    $results += New-Object PSObject -Property @{
        Computer = $computer
        Text = $rule.Description
        Result = $result
    }

    Write-Verbose ("Result - " + $result.ToString().ToUpper())
    return $result
}
#EndRegion


#Region - Test The Version of PowerSHell
function Test-PSVersion {
    param(
        [string] $computer,
        [Object] $rule 
    )
    
    Write-Host ("[{0}] - Testing Rule - {1} . . ." -f $(Get-Date), $rule.Description)
    $version = Invoke-Command -Session $session -ScriptBlock {return ($psversiontable.PSVersion)}

    $result = $version.Major -ge $rule.Version
    $results += New-Object PSObject -Property @{
        Computer = $computer
        Text = $rule.Description
        Result = $result
    }


    Write-Verbose ("Result - " + $result.ToString().ToUpper())
    return $result
}
#EndRegion