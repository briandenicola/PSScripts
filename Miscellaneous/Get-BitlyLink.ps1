param(
    [Parameter(Mandatory = $True)][string] $url,
    [switch] $copy_to_clipboard
)

Set-Variable -Name access_token -Value "" -Option Constant
$link = [string]::Format( "https://api-ssl.bitly.com/v3/user/link_save?access_token={0}&longUrl={1}", $access_token,  [system.web.httputility]::urlencode($url) )

$result = Invoke-RestMethod -Method Get -Uri $link

if( $result.status_code -ne 200 ) {
    throw ("Erorr Occured - " + $result.status_txt )
}

if( $copy_to_clipboard ) { 
    $result.data.link_save.link | Set-Clipboard
}

return $result.data.link_save.link 