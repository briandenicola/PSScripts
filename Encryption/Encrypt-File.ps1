<#
.SYNOPSIS
The script will encrypt a file using AES 256-bit encryption

.DESCRIPTION
Version - 1.0.0
The script will encrypt a file using AES 256-bit encryption

.EXAMPLE
.\Encrypt-File.ps1 -FileName .\test.text

.EXAMPLE
.\Encrypt-File.ps1 -FileName .\test.text -Key uGeZVn1cSkTdI633yyIZ4fmit4SwCpA0rFLgKYuFhMk= -Remove

.PARAMETER FileName
Name of file to encrypt

.PARAMETER Key 
(Optional) An AES key used to encrypt the file. If not passed then a key will be generated. 

.PARAMETER Remove
Switch to remove the source file after encryption

#>
param(
    [Parameter(Mandatory = $true)]
    [string] $fileName,

    [Parameter(Mandatory = $false)]	
    [string] $key,

    [Parameter(Mandatory = $false)]	
    [switch] $remove
)

$aes = New-Object "System.Security.Cryptography.AesManaged"
$aes.KeySize = 256

if ([string]::IsNullOrEmpty($key)) {
    $aes.GenerateKey()
}
else {
    $aes.Key = [System.Convert]::FromBase64String($key)
}

$encryptedFile = $fileName + ".enc"

$reader = New-Object System.IO.FileStream($fileName, [System.IO.FileMode]::Open)
$writer = New-Object System.IO.FileStream($encryptedFile, [System.IO.FileMode]::Create)

$aes.GenerateIV()
$encryptor = $aes.CreateEncryptor()
$stream = New-Object System.Security.Cryptography.CryptoStream($writer, $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
$reader.CopyTo($stream)

$stream.FlushFinalBlock()
$stream.Close()
$reader.Close()
$writer.Close()

if ($remove) { Remove-Item -Path $fileName -Force -Confirm:$false}

$opts = [ordered] @{
    OriginalFile  = $fileName
    EncryptedFile = $encryptedFile
    Key           = [System.Convert]::ToBase64String($aes.Key)
}
$result = New-Object psobject -Property $opts

return $result 