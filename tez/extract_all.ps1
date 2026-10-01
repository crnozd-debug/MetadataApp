Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead('c:\metadataapp\tez\tezbeta.docx')
$filesToExtract = @('word/styles.xml', 'word/footer1.xml', 'word/numbering.xml', 'word/settings.xml', '[Content_Types].xml', 'word/_rels/document.xml.rels')
foreach($e in $zip.Entries){
    if($filesToExtract -contains $e.FullName){
        $stream = $e.Open()
        $reader = New-Object System.IO.StreamReader($stream)
        $content = $reader.ReadToEnd()
        $reader.Close()
        $stream.Close()
        $safeName = $e.FullName -replace '/', '_' -replace '\[', '' -replace '\]', ''
        $xml = [xml]$content
        $sw = New-Object System.IO.StringWriter
        $xw = New-Object System.Xml.XmlTextWriter($sw)
        $xw.Formatting = [System.Xml.Formatting]::Indented
        $xml.WriteTo($xw)
        $xw.Flush()
        $sw.ToString() | Out-File -FilePath "c:\metadataapp\tez\extracted_$safeName" -Encoding UTF8
        Write-Host "Extracted $($e.FullName)"
    }
}
$zip.Dispose()
