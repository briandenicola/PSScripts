Set-Variable -Name pingdom_api -Value "" -Option Constant
Set-Variable -Name pingdom_user -Value "" -Option Constant
Set-Variable -Name pingdom_credentials -Value $null

$pingdom_urls = New-Object PSObject -Property @{
    Checks="https://api.pingdom.com/api/2.0/checks/{0}"
}

$pingdom_output = New-Object PSObject -Property @{
}

$pingdom_error_data = New-Object PSObject -Property @{   
}

function __ConvertFrom-Json
{
    param(
        [Parameter(ValueFromPipeline=$true,Position=0)]
        [string] $json
    )

    begin {
        $state = New-Object PSObject -Property @{
            ValueState = $false
            ArrayState = $false
            StringStart = $false
            SaveArray = $false
        }

        $json_state = New-Object PSObject -Property @{
            Space = " "
            Comma = ","
            Quote = '"'
            NewObject = "(New-Object PSObject "
            OpenParenthesis = "@("
            CloseParenthesis = ")"
            NewProperty = '| Add-Member -Passthru NoteProperty "'
        }

        function Convert-Character
        {
            param( [string] $c )

            switch -regex ($c) {
                '{' { 
                    $state.SaveArray = $state.ArrayState
                    $state.ValueState = $state.StringStart = $state.ArrayState = $false				
                    return  $json_state.NewObject
                }

                '}' { 
                    $state.ArrayState  = $state.SaveArray 
                    return $json_state.CloseParenthesis
                }

                '"' {
                    if( !$state.StringStart -and !$state.ValueState -and !$state.ArrayState ) {
                        $str = $json_state.NewProperty
                    }
                    else { 
                        $str = $json_state.Quote
                    }
                    $state.StringStart = $true
                    return $str
                    
                }

                ':' { 
                    if($state.ValueState) { return $c } 
                    else { $state.ValueState = $true; return $json_state.Space }
                }

                ',' {
                    if($state.ArrayState) { return $json_state.Comma }
                    else { $state.ValueState = $state.StringStart = $false }
                }
                	
                '\[' { 
                    $state.ArrayState = $true
                    return $json_state.OpenParenthesis
                }
                
                '\]' { 
                    $state.ArrayState = $false 
                    return $json_state.CloseParenthesis
                }
                
                "[a-z0-9A-Z/@.?()%=&\- ]" { return $c }
                "[\t\r\n]" {}
            }
        }
    	
    }

    process { 
        $result = New-Object -TypeName "System.Text.StringBuilder"
        foreach($c in $json.ToCharArray()) { 
            [void] $result.Append((Convert-Character $c))
        }
    }

    end {
        return (Invoke-Expression $result)
    }
}

function __Get-PingdomWebClient
{
    $web_client = New-Object System.Net.WebClient
    $web_client.Headers.Add("App-Key", $pingdom_api)

    if(!$pingdom_credentials) {
        $pingdom_credentials = Get-Credential $pingdom_user 
    }
    $web_client.Credentials = $pingdom_credentials
    
    return $web_client
}

function __Update-PingdomAppMonitoring
{
    param(
        [Parameter(Mandatory=$true)]
        [string] $id,
        [Parameter(Mandatory=$true)]
        [string] $state
    )

    if( $id -eq 0 ) { return }
    
    Write-Verbose "[ $(Get-Date) ] - Setting Pingdom URL Monitoring for Application Id - $id - to $state . . ."

    $wc = __Get-PingdomWebClient
   	$monitoring_info = New-Object System.Collections.Specialized.NameValueCollection 
	$monitoring_info.Add("paused", $state)
	$result = $wc.UploadValues($pingdom_urls.Deployment, "PUT", $monitoring_info) 
    return ( [System.Text.Encoding]::ASCII.GetString($result) )
}

function Enable-PingdomAppMonitoring
{
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string] $id
    )

    begin {
        Set-Variable -Name state -Value "true" -Option Constant
        Set-Variable -Name result 
    }
    process {
        $result = __Update-PingdomAppMonitoring -id $id -state $state
    }
    end {
        Write-Verbose -Message ("Return Result - {0}" -f $result)
    }
}

function Disable-PingdomAppMonitoring
{
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string] $id
    )

    begin {
        Set-Variable -Name state -Value "false" -Option Constant
        Set-Variable -Name result 
    }
    process {
        $result = __Update-PingdomAppMonitoring -id $id -state $state
    }
    end {
        Write-Verbose -Message ("Return Result - {0}" -f $result)
    }
}

Export-ModuleMember -Function Enable-PingdomAppMonitoring, Disable-PingdomAppMonitoring