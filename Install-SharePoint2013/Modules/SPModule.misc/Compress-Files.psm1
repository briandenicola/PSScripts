

function Compress-ToZip
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true)][ValidateNotNull()]
		$ZipFile,

		[Parameter(Mandatory=$true)][ValidateNotNull()]
		$FileName
	)

        Add-Type -ReferencedAssemblies "Windowsbase" -Type @"
using System;
using System.IO;
using System.IO.Packaging;

namespace SPModule
{
    public static class ZipFile
    {
        private const long BUFFER_SIZE = 4096;
        
        public static void AddFileToZip(string zipFilename, string fileToAdd)
        {
            using (Package zip = System.IO.Packaging.Package.Open(zipFilename, FileMode.OpenOrCreate))
            {
                string destFilename = ".\\" + Path.GetFileName(fileToAdd);
                Uri uri = PackUriHelper.CreatePartUri(new Uri(destFilename, UriKind.Relative));
                if (zip.PartExists(uri))
                {
                    zip.DeletePart(uri);
                }
                PackagePart part = zip.CreatePart(uri, "",CompressionOption.Normal);
                using (FileStream fileStream = new FileStream(fileToAdd, FileMode.Open, FileAccess.Read))
                {
                    using (Stream dest = part.GetStream())
                    {
                        CopyStream(fileStream, dest);
                    }
                }
            }
        }
        
        private static void CopyStream(System.IO.FileStream inputStream, System.IO.Stream outputStream)
        {
            long bufferSize = inputStream.Length < BUFFER_SIZE ? inputStream.Length : BUFFER_SIZE;
            byte[] buffer = new byte[bufferSize];
            int bytesRead = 0;
            long bytesWritten = 0;
            while ((bytesRead = inputStream.Read(buffer, 0, buffer.Length)) != 0)
            {
                outputStream.Write(buffer, 0, bytesRead);
                bytesWritten += bufferSize;
            }
        }
    }
}

"@
    $allfiles = dir $FileName -Recurse
    $totalnumfiles = $allfiles.Count
    $currentFile = 0
    dir $FileName | %{[SPModule.ZipFile]::AddFileToZip($ZipFile, $_.FullName);$currentFile++;Write-Progress "Compressing $_" "Saving $currentFile of $totalnumfiles files" -id 0 -percentComplete (($currentFile/$totalnumfiles)*100)}
}
