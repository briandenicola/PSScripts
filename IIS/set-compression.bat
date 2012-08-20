@echo off

CSCRIPT.EXE //H:CSCRIPT

set ADSUTIL=c:\Inetpub\AdminScripts\adsutil.vbs

Echo Using %ADSUTIL%

Echo Enabling Compression
%ADSUTIL% SET W3Svc/Filters/Compression/DEFLATE/HcDoStaticCompression "TRUE"

Echo Setting Compression Levels
%ADSUTIL% SET W3Svc/Filters/Compression/GZIP/HcDynamicCompressionLevel "9" 				
%ADSUTIL% SET W3Svc/Filters/Compression/DEFLATE/HcDynamicCompressionLevel "9"				
%ADSUTIL% SET W3Svc/Filters/Compression/DEFLATE/HcOnDemandCompLevel "9"
%ADSUTIL% SET W3Svc/Filters/Compression/Gzip/HcOnDemandCompLevel "9"


Echo Settting HCFileExtensions
%ADSUTIL% SET W3Svc/Filters/Compression/GZIP/HcFileExtensions "htm" "htm" "txt" "js" "css" "htc" "doc" "docx" "xls" "xlsx" "ppt" "pptx" "pdf"
%ADSUTIL% SET W3Svc/Filters/Compression/DEFLATE/HcFileExtensions "htm" "htm" "txt" "js" "css" "htc" "doc" "docx" "xls" "xlsx" "ppt" "pptx" "pdf"

Echo Settting HCScriptFileExtensions
%ADSUTIL% SET W3Svc/Filters/Compression/GZIP/HcScriptFileExtensions "asp" "aspx" "asmx" "dll" "exe"
%ADSUTIL% SET W3Svc/Filters/Compression/DEFLATE/HcScriptFileExtensions "asp" "aspx" "asmx" "dll" "exe"
