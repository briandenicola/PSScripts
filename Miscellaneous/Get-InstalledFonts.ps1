[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
$objFonts = New-Object System.Drawing.Text.InstalledFontCollection
return $objFonts.Families