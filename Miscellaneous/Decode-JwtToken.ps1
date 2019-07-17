#https://gallery.technet.microsoft.com/JWT-Token-Decode-637cf001
param (
    [string] $Token
)

function Convert-FromBase64StringWithNoPadding {
    param( [string]$data )
    $data = $data.Replace('-', '+').Replace('_', '/')
    switch ($data.Length % 4) {
        0 { break }
        2 { $data += '==' }
        3 { $data += '=' }
        default { throw New-Object ArgumentException('data') }
    }
    return [System.Convert]::FromBase64String($data)
}

$parts = $Token.Split('.');
$headers = [System.Text.Encoding]::UTF8.GetString( (Convert-FromBase64StringWithNoPadding -data $parts[0]) )
$claims = [System.Text.Encoding]::UTF8.GetString( (Convert-FromBase64StringWithNoPadding -data $parts[1]) )
$signature = (Convert-FromBase64StringWithNoPadding -data $parts[2])

$customObject = [PSCustomObject] @{
    headers   = ($headers | ConvertFrom-Json)
    claims    = ($claims | ConvertFrom-Json)
    signature = $signature
}

return $customObject