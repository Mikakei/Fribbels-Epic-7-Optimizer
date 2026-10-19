# Merges upstream changes into the maintenance branch and rebuilds only what changed (see MAINTENANCE.md).
param(
    [string]$Remote = 'origin',
    [string]$Branch = 'main'
)

$ErrorActionPreference = 'Continue'
$Root = $PSScriptRoot
$Toolchain = Join-Path $Root '.toolchain'
$Jdk = Join-Path $Toolchain 'jdk8u504-b01'
$Mvn = Join-Path $Toolchain 'apache-maven-3.9.9\bin\mvn.cmd'
$NodeDir = Join-Path $Toolchain 'node-v16.20.2-win-x64'
$Jar = 'data/jar/backend.jar'

$env:JAVA_HOME = $Jdk
$env:PATH = "$Jdk\bin;$NodeDir;$env:PATH"
$env:YARN_CACHE_FOLDER = Join-Path $Toolchain 'yarn-cache'

function Fail([string]$message) {
    Write-Host ""
    Write-Host "UPDATE STOPPED: $message" -ForegroundColor Red
    exit 1
}

function Step([string]$message) {
    Write-Host ""
    Write-Host "== $message" -ForegroundColor Cyan
}

function Invoke-Git {
    $output = & git -C $Root @args
    if ($LASTEXITCODE -ne 0) { Fail "git $($args -join ' ') failed" }
    return $output
}

foreach ($tool in @($Mvn, (Join-Path $NodeDir 'node.exe'), (Join-Path $Jdk 'bin\java.exe'))) {
    if (-not (Test-Path $tool)) { Fail "Missing toolchain file $tool" }
}

# The running backend holds backend.jar open, so the app must be closed first
$running = Get-CimInstance Win32_Process | Where-Object {
    ($_.ExecutablePath -and $_.ExecutablePath.StartsWith($Root + '\', [StringComparison]::OrdinalIgnoreCase)) -or
    ($_.Name -eq 'java.exe' -and $_.CommandLine -and $_.CommandLine.Contains($Root) -and $_.CommandLine.Contains('backend.jar'))
}
if ($running) { Fail "The optimizer is running. Close it and run the update again." }

if (Invoke-Git status --porcelain --untracked-files=no) {
    Fail "There are uncommitted changes. Commit or discard them first (git status)."
}

# Steps still owed from a merge are kept in the git dir, so a failed build is retried on the next run
$PendingFile = Join-Path ((Invoke-Git rev-parse --absolute-git-dir) | Select-Object -First 1) 'fribbels-update-pending'
$AllTasks = @('deps', 'backend', 'app')
$tasks = @()
if (Test-Path $PendingFile) {
    $tasks = @(Get-Content $PendingFile | Where-Object { $AllTasks -contains $_ })
    if ($tasks.Count) { Write-Host "Resuming unfinished steps from the last update: $($tasks -join ', ')" }
}

function Save-Pending {
    if ($script:tasks.Count) {
        Set-Content -Path $PendingFile -Value $script:tasks -Encoding ascii
    } elseif (Test-Path $PendingFile) {
        Remove-Item $PendingFile
    }
}

function Complete-Task([string]$name) {
    $script:tasks = @($script:tasks | Where-Object { $_ -ne $name })
    Save-Pending
}

Step "Fetching $Remote/$Branch"
& git -C $Root fetch $Remote $Branch
if ($LASTEXITCODE -ne 0) { Fail "git fetch failed. Check the network connection to GitHub." }

$incoming = @(Invoke-Git log --oneline "HEAD..$Remote/$Branch")
$dataChanged = $false
if ($incoming.Count) {
    Write-Host "Incoming upstream commits:"
    $incoming | ForEach-Object { Write-Host "  $_" }

    $before = (Invoke-Git rev-parse HEAD) | Select-Object -First 1

    Step "Merging"
    & git -C $Root merge --no-edit "$Remote/$Branch"
    if ($LASTEXITCODE -ne 0) {
        $conflicts = @(Invoke-Git diff --name-only --diff-filter=U)
        if ($conflicts.Count -eq 1 -and $conflicts[0] -eq $Jar) {
            # Both sides changed the binary jar; it is rebuilt from the merged source below anyway
            Write-Host "Only $Jar conflicted; it will be rebuilt from the merged source."
            Invoke-Git checkout --theirs -- $Jar | Out-Null
            Invoke-Git add -- $Jar | Out-Null
            Invoke-Git commit --no-edit | Out-Null
            $tasks += 'backend'
        } else {
            & git -C $Root merge --abort
            Fail ("Merge conflicts need manual resolution: " + ($conflicts -join ', '))
        }
    }

    $changed = @(Invoke-Git diff --name-only $before HEAD)
    if ($changed | Where-Object { $_ -match '^(app/)?(package\.json|yarn\.lock)$' }) { $tasks += 'deps', 'app' }
    if ($changed | Where-Object { $_ -match '^backend/(src/|pom\.xml)' -or $_ -eq $Jar }) { $tasks += 'backend' }
    if ($changed | Where-Object { $_ -match '^(app|configs|internals)/' -and $_ -notmatch '^app/(js|assets|css|locales)/' }) { $tasks += 'app' }
    $dataChanged = [bool]($changed | Where-Object { $_ -match '^data/(cache|cachedimages|locales)/' })
} elseif (-not $tasks.Count) {
    Write-Host "Already up to date."
    exit 0
}

# Keep a fixed order and drop duplicates
$tasks = @($AllTasks | Where-Object { $tasks -contains $_ })
$ran = @($tasks)
Save-Pending

if ($tasks -contains 'deps') {
    Step "Installing JS dependencies"
    Push-Location $Root
    & yarn install --non-interactive --network-timeout 600000
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -ne 0) { Fail "yarn install failed. Run the update again to retry." }
    if (Invoke-Git status --porcelain --untracked-files=no -- yarn.lock app/yarn.lock) {
        Invoke-Git add -- yarn.lock app/yarn.lock | Out-Null
        Invoke-Git commit -m "Update yarn.lock after merging upstream" | Out-Null
    }
    Complete-Task 'deps'
}

if ($tasks -contains 'backend') {
    Step "Rebuilding backend.jar"
    Push-Location (Join-Path $Root 'backend')
    & $Mvn -q -B package "-Dmaven.repo.local=$(Join-Path $Toolchain 'm2')"
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -ne 0) { Fail "Maven build failed. Run the update again to retry." }
    Copy-Item -Force (Join-Path $Root 'backend\target\backend.jar') (Join-Path $Root $Jar)
    if (Invoke-Git status --porcelain --untracked-files=no -- $Jar) {
        Invoke-Git add -- $Jar | Out-Null
        Invoke-Git commit -m "Rebuild backend.jar after merging upstream" | Out-Null
    }
    Complete-Task 'backend'
}

if ($tasks -contains 'app') {
    Step "Building app"
    Push-Location $Root
    & yarn build
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -ne 0) { Fail "yarn build failed. Run the update again to retry." }
    Complete-Task 'app'
}

# Upstream could reintroduce the two settings this branch turned off
$heroData = Get-Content -Raw (Join-Path $Root 'app\js\lib\heroData.js')
if ($heroData -match '(?m)^\s*global\.TEST\s*=\s*true') {
    Write-Host "WARNING: app/js/lib/heroData.js sets global.TEST = true again; server data will not load." -ForegroundColor Yellow
}
$mainDev = Get-Content -Raw (Join-Path $Root 'app\main.dev.js')
if ($mainDev -match 'allowDowngrade\s*=\s*true') {
    Write-Host "WARNING: app/main.dev.js allows auto-update downgrade again; the official release may replace this build." -ForegroundColor Yellow
}

Step "Done"
Write-Host ("Merged {0} upstream commit(s)." -f $incoming.Count)
Write-Host ("Steps run: {0}" -f $(if ($ran.Count) { $ran -join ', ' } else { 'none needed' }))
Write-Host ("Bundled hero/artifact data or translations changed: {0}" -f $dataChanged)
