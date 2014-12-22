function Log
{
    param(
        [string] $text
    )

    $logged_text = "[{0}] - {1} ... " -f $(Get-Date), $text
    Add-Content -Encoding Ascii -Value $logged_text -Path $global:log_file 
    Write-Verbose -Message $logged_text
}

function Get-MostRecentFile([string] $src )
{
	return ( Get-ChildItem $src | Where { $_.name -notmatch "rolledback" } | Sort LastWriteTime -desc | Select -first 1 | Select -ExpandProperty Name )
}

function Get-NewFileName( [string] $src ) 
{
    $now = $(Get-Date).ToString("yyyyMMddHHmmss")
    $file = Get-Item $src | Select BaseName, DirectoryName
    return ( Join-Path -Path $file.DirectoryName -ChildPath ("{0}.{1}" -f $file.BaseName, $now) ) 
}

function Update-ConfigFile
{ 
    param(
        [string] $config_file,
        [string] $line_to_update,
        [string] $new_line
    )

    $file = Get-Content -Path $config_file
    $file | Foreach { $_.Replace($line_to_update, $new_line) } | Set-Content -Encoding Ascii -Path $config_file

}

function DeleteFrom-ConfigFile
{
    param(
        [string] $config_file,
        [string] $line_to_delete
    )

    $file = Get-Content -Path $config_file 
    $file | Where { $_ -ne $line_to_delete } | Set-Content -Encoding Ascii -Path $config_file
}

function AddTo-ConfigFile 
{
    param(
        [string] $config_file,
        [string] $node,
        [string] $parent,
        [System.Xml.XmlDocument] $xml_update
    )

    $config = [xml] ( Get-Content -Path $config_file )
    $update = $config.ImportNode($xml_update.SelectSingleNode($node), $true)
    $config.SelectSingleNode($parent).AppendChild($update) | Out-Null
    $config.Save($config_file)
}