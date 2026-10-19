# Builds release\FribbelsImporterDiagnose-<date>.zip for players: the capture diagnostic, bundled scapy and instructions.
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Name = 'FribbelsImporterDiagnose'
$Release = Join-Path $Root 'release'
$Stage = Join-Path $Release $Name
$Zip = Join-Path $Release ("{0}-{1}.zip" -f $Name, (Get-Date -Format 'yyyyMMdd'))

if (Test-Path $Stage) { Remove-Item -Recurse -Force $Stage }
if (Test-Path $Zip) { Remove-Item -Force $Zip }
New-Item -ItemType Directory -Force $Stage | Out-Null

Copy-Item (Join-Path $Root 'data\py\diagnose_capture.py') $Stage
Copy-Item (Join-Path $Root 'tools\diagnose-package\run-diagnose.cmd') $Stage
Copy-Item (Join-Path $Root 'data\py\LICENSE') (Join-Path $Stage 'LICENSE-scapy.txt')

# Notepad on older Windows needs a BOM to show the Chinese text correctly
$readme = Get-Content -Raw -Encoding UTF8 (Join-Path $Root 'tools\diagnose-package\README.txt')
[System.IO.File]::WriteAllText((Join-Path $Stage 'README.txt'), $readme, (New-Object System.Text.UTF8Encoding($true)))

# Bundled scapy without compiled caches
robocopy (Join-Path $Root 'data\py\scapy') (Join-Path $Stage 'scapy') /E /XD __pycache__ /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with code $LASTEXITCODE" }

# Add entries one by one: ZipFile.CreateFromDirectory on .NET Framework writes backslash paths
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open($Zip, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem -Recurse -File $Stage) {
        $entry = $Name + '/' + $file.FullName.Substring($Stage.Length + 1).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $entry,
            [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally {
    $archive.Dispose()
}
Remove-Item -Recurse -Force $Stage

$size = (Get-Item $Zip).Length
"Built {0} ({1:N1} MB)" -f $Zip, ($size / 1MB)
