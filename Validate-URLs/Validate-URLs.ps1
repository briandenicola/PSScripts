[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [string] $cfg,
    [switch] $SaveReply
)

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

function Get-GTWebserviceRequest 
{
    param(
        [string] $url,
        [string] $Server
    )

    Set-Variable -Name AuthType -Value "NTLM"
    Set-Variable -Name timeout -Value 10
 
	$request = [System.Net.HttpWebRequest]::Create($url)
    $request.Headers.Add("X-FORMS_BASED_AUTH_ACCEPTED", "f");
    $request.Method = "GET"
    $request.Timeout = $timeout * 1000
    $request.AllowAutoRedirect = $false
    $request.ContentType = "application/x-www-form-urlencoded"
    $request.UserAgent = "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0; .NET CLR 1.1.4322)"
	$request.Credentials =  [System.Net.CredentialCache]::DefaultCredentials
	$request.Proxy = new-object -typename System.Net.WebProxy -argumentlist $Server
    
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
        Write-Verbose ("[{0}][REPLY] Network Connections = {1} . . ." -f $(Get-Date),  ([string]::join( ";", (nslookup $server | Foreach {netstat -an | findstr /i $_}))))
		Write-Verbose ("[{0}][REPLY] Total Time = {1} . . ." -f $(Get-Date), $timing_request.TotalSeconds)
	}
	catch [System.Net.WebException] {
		Write-Error ("The request failed with the following WebException - " + $_.Exception.ToString() )
	}

    return $data
	
}

$output = (Join-Path $PWD.Path (Join-Path "results" ("wgc-validation-run-{0}.log" -f $(Get-Date).ToString("yyyMMddhhmmss"))) )
$url_to_validate = Get-Content -Raw $cfg | ConvertFrom-Json

foreach( $url in $url_to_validate ) {
    foreach( $server in $url.servers.server ) {
        $results = Get-GTWebserviceRequest -url $url.url -Server $server 

        if( $saveReply ) {
            $url -imatch "http://([a-zA-Z0-9\-\.]+)" | Out-Null
            $uri = $matches[1]
            $results | Add-Content -Encoding Ascii (Join-Path $PWD.Path (Join-Path "results" ("{0}-{1}-{2}.log" -f $uri, $server, $(Get-Date).ToString("yyyMMddhhmmss"))) )
        }

        foreach( $rule in $url.rules ) {
            if( $rule.validation -eq "present" -and $results -notmatch  $rule.rule ) { 
                Log-Results -txt ("Present Rule Validation Failure on server - {0} - rule : {1} " -f $server, $rule.rule ) -error

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