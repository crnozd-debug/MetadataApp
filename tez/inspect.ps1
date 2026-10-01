Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead('c:\metadataapp\tez\tezbeta.docx')
foreach($e in $zip.Entries){
    Write-Host "$($e.FullName) $($e.Length)"
}
$zip.Dispose()
