# Builds the portable Windows zip: release\FribbelsE7Optimizer-<version>-win-x64.zip (see MAINTENANCE.md).
# The zip bundles a Java 8 JRE, so players only need Python and Npcap for the gear importer.
param(
    # Skip "yarn build" when app\main.prod.js is already up to date
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Toolchain = Join-Path $Root '.toolchain'
$NodeDir = Join-Path $Toolchain 'node-v16.20.2-win-x64'
$Jdk = Get-ChildItem $Toolchain -Directory -Filter 'jdk*' | Select-Object -First 1
$Version = (Get-Content -Raw (Join-Path $Root 'app\package.json') | ConvertFrom-Json).version
$ElectronVersion = (Get-Content -Raw (Join-Path $Root 'node_modules\electron\package.json') | ConvertFrom-Json).version
$Name = "FribbelsE7Optimizer-$Version-win-x64"
$BuildDir = Join-Path $Root 'release\build'
$Stage = Join-Path $Root "release\$Name"
$Zip = Join-Path $Root "release\$Name.zip"

if (-not $Jdk -or -not (Test-Path (Join-Path $Jdk.FullName 'jre\bin\java.exe'))) { throw "No JDK with a jre folder in $Toolchain" }
$env:PATH = "$NodeDir;$env:PATH"
Set-Location $Root

if (-not $SkipBuild) {
    Write-Host "== yarn build"
    & yarn --silent build | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "yarn build failed" }
}

Write-Host "== electron-builder (dir, Electron $ElectronVersion from node_modules)"
if (Test-Path $BuildDir) { Remove-Item -Recurse -Force $BuildDir }
& (Join-Path $Root 'node_modules\.bin\electron-builder.cmd') build --win dir --x64 --publish never `
    "-c.electronDist=node_modules/electron/dist" "-c.electronVersion=$ElectronVersion" `
    "-c.directories.output=release/build" "-c.npmRebuild=false"
if ($LASTEXITCODE -ne 0) { throw "electron-builder failed" }

Write-Host "== Staging $Name"
if (Test-Path $Stage) { Remove-Item -Recurse -Force $Stage }
Copy-Item -Recurse (Join-Path $BuildDir 'win-unpacked') $Stage
# OCR was removed upstream, so its model is unused; compiled Python caches are machine-specific
Remove-Item -Recurse -Force (Join-Path $Stage 'data\tessdata') -ErrorAction SilentlyContinue
Get-ChildItem -Recurse -Directory -Force (Join-Path $Stage 'data') -Filter '__pycache__' | Remove-Item -Recurse -Force
robocopy (Join-Path $Jdk.FullName 'jre') (Join-Path $Stage 'jre') /E /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "Copying the JRE failed" }
New-Item -ItemType Directory -Force (Join-Path $Stage 'scripts') | Out-Null
foreach ($script in 'check-importer.cmd', 'diagnose-importer.cmd') {
    Copy-Item (Join-Path $Root "scripts\$script") (Join-Path $Stage 'scripts')
}
# Notepad on older Windows needs a BOM to show the Chinese text correctly
$readme = Get-Content -Raw -Encoding UTF8 (Join-Path $Root 'tools\release-package\README.txt')
[System.IO.File]::WriteAllText((Join-Path $Stage 'README.txt'), $readme, (New-Object System.Text.UTF8Encoding($true)))

Write-Host "== Zipping"
if (Test-Path $Zip) { Remove-Item -Force $Zip }
# Add entries one by one: ZipFile.CreateFromDirectory on .NET Framework writes backslash paths
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open($Zip, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem -Recurse -File -Force $Stage) {
        $entry = $Name + '/' + $file.FullName.Substring($Stage.Length + 1).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $entry,
            [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally {
    $archive.Dispose()
}

$hash = (Get-FileHash -Algorithm SHA256 $Zip).Hash.ToLower()
"Built {0} ({1:N1} MB)" -f $Zip, ((Get-Item $Zip).Length / 1MB)
"SHA256 $hash"
