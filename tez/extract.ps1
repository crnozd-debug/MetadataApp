Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead('c:\metadataapp\tez\tezbeta.docx')
foreach($e in $zip.Entries){
    if($e.FullName -eq 'word/document.xml'){
        $stream = $e.Open()
        $reader = New-Object System.IO.StreamReader($stream)
        $content = $reader.ReadToEnd()
        $reader.Close()
        $stream.Close()
        # Pretty print the XML
        $xml = [xml]$content
        $sw = New-Object System.IO.StringWriter
        $xw = New-Object System.Xml.XmlTextWriter($sw)
        $xw.Formatting = [System.Xml.Formatting]::Indented
        $xml.WriteTo($xw)
        $xw.Flush()
        $sw.ToString() | Out-File -FilePath 'c:\metadataapp\tez\document_extracted.xml' -Encoding UTF8
        Write-Host "Extracted document.xml"
    }
}
$zip.Dispose()
