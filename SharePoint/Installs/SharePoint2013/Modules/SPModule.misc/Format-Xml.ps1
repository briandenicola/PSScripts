function Format-Xml
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [xml] $Document,
        
        [Parameter()]
        [Alias("IndentChar", "Char")]
        [char] $IndentationCharacter = [char]" ",
        
        [Parameter()]
        [int] $Indentation = 4,
        
        [Parameter()]
        [String] $Wrap = ""
    )
    
    Begin
    {
        if(-not ([String]::IsNullOrEmpty($Wrap)))
        {
            "<" + $Wrap + ">"
        }
    }
    
    Process
    {
        $stream = New-Object "System.IO.MemoryStream"
        $writer = New-Object "System.Xml.XmlTextWriter" ($stream, [System.Text.Encoding]::Unicode)
        
        $writer.Indentation = $Indentation
        $writer.IndentChar = $IndentationCharacter
        $writer.Formatting = [System.Xml.Formatting]::Indented
        
        $Document.WriteContentTo($writer)
        $writer.Flush()
        $stream.Flush()
        $stream.Position = 0
        
        $reader = New-Object "System.IO.StreamReader" $stream
        $reader.ReadToEnd()
    }
    
    End
    {
        if(-not ([String]::IsNullOrEmpty($Wrap)))
        {
            "</" + $Wrap + ">"
        }
    }
}