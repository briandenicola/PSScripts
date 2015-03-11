[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [string] $cfg,
    [switch] $SaveReply
)

. (Join-path $env:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")

function Log-Results
{
    param(
        [string] $txt,
        [switch] $error
    )

    if($error) { $color = "red" } else { $color = "green" }
    
    $log_text = "[{0}] - {1}" -f $(Get-Date), $txt
    Write-Host $log_text -ForegroundColor $color
    $log_text | Add-Content -Encoding Ascii $output
}

#http://powershelljson.codeplex.com/SourceControl/latest?ProjectName=powershelljson
#Added processing for / and : in the text of the json
function PS2-ConvertFrom-Json
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
function Get-WebserviceRequest 
{
    param(
        [string] $url,
        [string] $Server
    )

    Set-Variable -Name AuthType -Value "NTLM"
    Set-Variable -Name timeout -Value 10
    Set-Variable -Name localhost -Value "localhost"
 
    if( $url -imatch $localhost ) { $url = $url.Replace($localhost, $Server) }

	$request = [System.Net.HttpWebRequest]::Create($url)
    $request.Headers.Add("X-FORMS_BASED_AUTH_ACCEPTED", "f");
    $request.Method = "GET"
    $request.Timeout = $timeout * 1000
    $request.AllowAutoRedirect = $false
    $request.ContentType = "application/x-www-form-urlencoded"
    $request.UserAgent = "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0; .NET CLR 1.1.4322)"
	$request.Credentials =  [System.Net.CredentialCache]::DefaultCredentials

    if( $url -inotmatch $Server ) { 
	    $request.Proxy = new-object -typename System.Net.WebProxy -argumentlist $Server
    }

    Write-Verbose ("[{0}][REQUEST] Getting $url ..." -f $(Get-Date))
	try {
		$timing_request = Measure-Command { $response = $request.GetResponse() }
		$stream = $response.GetResponseStream()
		$reader = New-Object System.IO.StreamReader($stream)
		$data = $reader.ReadToEnd()

		Write-Verbose ("[{0}][REPLY] Server = {1} " -f $(Get-Date), $response.Server)
        Write-Verbose ("[{0}][REPLY] Method = {1} . . ." -f $(Get-Date), $response.Method)
        Write-Verbose ("[{0}][REPLY] Cached = {1} . . ." -f $(Get-Date), $response.IsFromCache)
		Write-Verbose ("[{0}][REPLY] Status Code = {1} {2} . . ." -f $(Get-Date), $response.StatusCode, $response.StatusDescription)
		Write-Verbose ("[{0}][REPLY] Content Type = {1} . . ." -f $(Get-Date), $response.ContentType)
		Write-Verbose ("[{0}][REPLY] Content Length = {1} . . ." -f $(Get-Date), $response.ContentLength)
        Write-Verbose ("[{0}][REPLY] Network Connections = {1} . . ." -f $(Get-Date),  ([string]::join( ";", (Get-IPAddress $server | Foreach {netstat -an | select-string $_}))))
		Write-Verbose ("[{0}][REPLY] Total Time = {1} . . ." -f $(Get-Date), $timing_request.TotalSeconds)
	}
	catch [System.Net.WebException] {
		Write-Error ("The request failed with the following WebException - " + $_.Exception.ToString() )
	}

    return $data
	
}

$output = (Join-Path $PWD.Path (Join-Path "results" ("validation-run-{0}.log" -f $(Get-Date).ToString("yyyMMddhhmmss"))) )

if( [convert]::toInt32($HOST.Version.Major) -le 2 ) {
    $url_to_validate = Get-Content $cfg | Out-String | PS2-ConvertFrom-Json
}
else {
    $url_to_validate = Get-Content -Raw $cfg | ConvertFrom-Json
}

foreach( $url in $url_to_validate ) {
    foreach( $server in ($url.servers | Select -Expand server) ) {
        $results = Get-WebserviceRequest -url $url.url -Server $server 

        if( $saveReply ) {
            $url -imatch "http://([a-zA-Z0-9\-\.]+)" | Out-Null
            $uri = $matches[1]
            $results | Add-Content -Encoding Ascii (Join-Path $PWD.Path (Join-Path "results" ("{0}-{1}-{2}.log" -f $uri, $server, $(Get-Date).ToString("yyyMMddhhmmss"))) )
        }

        foreach( $rule in $url.rules ) {
            if( $rule.validation -eq "present" -and $results -notmatch  $rule.rule ) { 
                Log-Results -txt ("Present Rule Validation Failure on server - {0} - rule : {1} " -f $server, $rule.rule) -error

                if( $rule.level -eq "error" ) {
                    Log-Results -txt ("Skipping remainding rules for {0}" -f $server) -error
                    break;
                }
            }
            elseif( $rule.validation -eq "absent" -and $results -match  $rule.rule ) { 
                Log-Results -txt ("Absent Rule Validation Failure on server - {0} - rule : {1}" -f $server, $rule.rule) -Error
                
                if( $rule.level -eq "error" ) {
                    Log-Results -txt ("Skipping remainding rules for {0}" -f $server) -error
                    break;
                }
            }
            else {
                Log-Results -txt ("Rule Validation Pass on server - {0} - rule : {1} " -f $server, $rule.rule )
            }
        }
    }
}