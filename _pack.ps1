$ErrorActionPreference = "Stop"

$sourceRoot = $PSScriptRoot
$archivePath = Join-Path $sourceRoot "TacticalDisplay.zip"
$rootPrefix = "TacticalDisplay/"

$files = Get-ChildItem -LiteralPath $sourceRoot -File -Recurse -Force | Where-Object {
    $relativePath = $_.FullName.Substring($sourceRoot.Length).Replace('\', '/').TrimStart('/')
    $_.Name -notmatch '^[._]' -and
    $_.Extension -ine ".md" -and
    $_.Extension -ine ".zip" -and
    $relativePath -notmatch '(^|/)\.git(/|$)'
}

Add-Type -AssemblyName System.IO.Compression
$archiveStream = [System.IO.File]::Open(
    $archivePath,
    [System.IO.FileMode]::Create,
    [System.IO.FileAccess]::ReadWrite,
    [System.IO.FileShare]::None
)
$archive = [System.IO.Compression.ZipArchive]::new(
    $archiveStream,
    [System.IO.Compression.ZipArchiveMode]::Create
)

try {
    $null = $archive.CreateEntry($rootPrefix)

    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($sourceRoot.Length).TrimStart('\', '/')
        $entryPath = $rootPrefix + $relativePath.Replace('\', '/')
        $entry = $archive.CreateEntry($entryPath, [System.IO.Compression.CompressionLevel]::Optimal)
        $entryStream = $entry.Open()
        $inputStream = [System.IO.File]::OpenRead($file.FullName)

        try {
            $inputStream.CopyTo($entryStream)
        }
        finally {
            $inputStream.Dispose()
            $entryStream.Dispose()
        }
    }
}
finally {
    $archive.Dispose()
    $archiveStream.Dispose()
}

Write-Output "Created $archivePath"
