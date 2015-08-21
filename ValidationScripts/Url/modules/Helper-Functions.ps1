Set-Variable -Name output -Value  (Join-Path $PWD.Path (Join-Path "results" ("validation-run-{0}.log" -f $(Get-Date).ToString("yyyMMddhhmmss"))) ) -Option Constant

function Get-Json
{
    param(
        [string] $Config
    )

    if( [convert]::toInt32($HOST.Version.Major) -le 2 ) {
        return ( Get-Content $Config | Out-String | PS2-ConvertFrom-Json )
    }
    else {
        return ( Get-Content -Raw $Config | ConvertFrom-Json )
    }
}

function Log-Results
{
    param(
        [Alias("LogMessage")][string] $txt,
        [switch] $error
    )

    if($error) { $color = "red" } else { $color = "green" }
    
    $log_text = "[{0}] - {1}" -f $(Get-Date), $txt
    Write-Host $log_text -ForegroundColor $color
    $log_text | Add-Content -Encoding Ascii $output
}

function Get-PSObjectProperties 
{
    param(
        [PSCustomObject] $object
    )

    return ( $object.psobject.Properties | Select -ExpandProperty Name )

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
        $script:startStringState = $false
        $script:valueState = $false
        $script:arrayState = $false	
        $script:saveArrayState = $false

        function scan-characters ($c) 
        {
            switch -regex ($c)
            {
                "{" { 
                    $script:saveArrayState = $script:arrayState
                    $script:valueState = $script:startStringState = $script:arrayState=$false				
                    return "(New-Object PSObject "
                }

                "}" { 
                    $script:arrayState=$script:saveArrayState 
                    return ")" 
                }

                '"' {
                    if( $script:startStringState -eq $false -and $script:valueState -eq $false -and $script:arrayState -eq $false ) {
                        $str = '| Add-Member -Passthru NoteProperty "'
                    }
                    else { 
                        $str = '"' 
                    }
                    $script:startStringState = $true
                    return $str
                    
                }

                "[a-z0-9A-Z/@.?()%=&\- ]" { return $c }

                ":" { 
                    if($script:valueState) { return $c } 
                    else { $script:valueState = $true; return " " }
                }

                "," {
                    if($script:arrayState) { return "," }
                    else { $script:valueState = $false; $script:startStringState = $false }
                }
                	
                "\[" { 
                    $script:arrayState = $true 
                    return "@("
                }
                
                "\]" { 
                    $script:arrayState = $false 
                    return ")"
                }
                
                "[\t\r\n]" {}
            }
        }
    	
        function parse($target)
        {
            $result = [string]::Empty
            foreach($c in $target.ToCharArray()) {	
                $result += scan-characters $c
            }
            return $result 	
        }
    }

    process { 
        $result = parse -target $json
    }

    end {
        return (Invoke-Expression $result)
    }
}

function Set-ObjectProperties
{
    param(
        [string] $Type,
        [string] $NameSpace,
        [PSCustomObject] $Parameters
    )
        
    $request_type = New-Object -TypeName ( "{0}.{1}" -f $namespace, $Type)

    foreach( $parameter in (Get-PSObjectProperties -object $Parameters)  ) {
        if($Parameters.$parameter  -is [PSCustomObject] ) {
            $request_type.$parameter = Set-ObjectProperties -Parameters $Parameters.$parameter.Parameters -Type $Parameters.$parameter.Type -NameSpace $namespace
        } 
        else {
            $request_type.$parameter = $Parameters.$parameter 
        }
    }

    return $request_type
}

function Get-GTWebserviceRequest 
{
    param(
        [string] $Url,
        [string] $Server,
        [PSCustomObject] $WebService
    )

    $sb = {
        param(
            [string] $Url,
            [PSCustomObject] $WebService,
            [string] $WorkingDirectory
        )

        Set-Location $WorkingDirectory
        . (Join-path -Path $PWD.Path         -ChildPath "Modules\Helper-Functions.ps1")

        Set-Variable -Name namespace -Value "WebServiceProxy"

        Write-Verbose ("[{0}][REQUEST] Getting $url ..." -f $(Get-Date))
	    try {

            $xml = New-WebServiceProxy -Uri $url -Namespace $namespace     
            $requestType = Set-ObjectProperties -Parameters $WebService.Parameters -Type $WebService.Type -NameSpace $namespace

		    $timing_request = Measure-Command { 
                $response = $xml.$($WebService.Name)($requestType) 
            }
		
		    Write-Verbose ("[{0}][REPLY] Response  = {1} " -f $(Get-Date), $response)
            Write-Verbose ("[{0}][REPLY] Total Time = {1} . . ." -f $(Get-Date), $timing_request.TotalSeconds)
	    }
	    catch [System.Net.WebException] {
		    Write-Error ("The request failed with the following WebException - " + $_.Exception.Message.ToString() )
	    }

        return $response
    }

    $response = Invoke-Command -ComputerName $env:COMPUTERNAME -ScriptBlock $sb -ArgumentList $url, $WebService, $PWD.Path

    return $response
	
}

function Get-GTWebRequest 
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
		Write-Error ("The request failed with the following WebException - " + $_.Exception.Message.ToString() )
	}

    return $data
	
}

function Validate-Results 
{
    param(
        $results,
        $rules
    )

    foreach( $rule in $rules ) {
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
        elseif( $rule.validation -eq "equals" -and $results.$($rule.rule) -ne $rule.value ) { 
            Log-Results -txt ("Equality Rule Validation Failure on server - {0} - rule : {1}" -f $server, $rule.rule) -Error
                
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

function Save-Reply 
{
    param (
        [string]   $url,
        [string]   $sever,
        [psobject] $Text
    )

    $url -imatch "http://([a-zA-Z0-9\-\.]+)" | Out-Null
    $uri = $matches[1]
    $Text | Out-File -Encoding Ascii (Join-Path $PWD.Path (Join-Path "results" ("{0}-{1}-{2}.log" -f $uri, $server, $(Get-Date).ToString("yyyMMddhhmmss"))) )
}