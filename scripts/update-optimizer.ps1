# Merges the original repo's changes into the current branch and rebuilds only what changed (see MAINTENANCE.md).
param(
    # Defaults to "upstream" when that remote exists (fork setup), otherwise "origin"
    [string]$Remote = '',
    [string]$Branch = 'main',
    # Wait up to 60 s for the optimizer to finish closing (used by the in-app Tools menu)
    [switch]$WaitForApp,
    # Start the optimizer again when done
    [switch]$Relaunch,
    # Close the window by itself after success, wait for Enter after a failure
    [switch]$Interactive
)

$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent $PSScriptRoot
$Toolchain = Join-Path $Root '.toolchain'
$Jdk = Join-Path $Toolchain 'jdk8u504-b01'
$Mvn = Join-Path $Toolchain 'apache-maven-3.9.9\bin\mvn.cmd'
$NodeDir = Join-Path $Toolchain 'node-v16.20.2-win-x64'
$Electron = Join-Path $Root 'node_modules\electron\dist\electron.exe'
$Jar = 'data/jar/backend.jar'
$TaskNames = @{ deps = '安装依赖'; backend = '重新编译后端'; app = '重新编译前端' }

$env:JAVA_HOME = $Jdk
$env:PATH = "$Jdk\bin;$NodeDir;$env:PATH"
$env:YARN_CACHE_FOLDER = Join-Path $Toolchain 'yarn-cache'
try { $Host.UI.RawUI.WindowTitle = 'Fribbels 配装器 · 更新' } catch {}

$canRelaunch = $false

function Start-App {
    Write-Host ""
    Write-Host "正在重新打开配装器……" -ForegroundColor Green
    Start-Process -FilePath $Electron -ArgumentList 'app' -WorkingDirectory $Root
}

function Finish([bool]$ok) {
    if ($Relaunch -and ($ok -or $script:canRelaunch)) { Start-App }
    if ($Interactive) {
        Write-Host ""
        if ($ok) {
            Write-Host "窗口将在 5 秒后关闭。" -ForegroundColor DarkGray
            Start-Sleep -Seconds 5
        } else {
            Read-Host "按回车键关闭" | Out-Null
        }
    }
    if ($ok) { exit 0 } else { exit 1 }
}

function Fail([string]$message) {
    Write-Host ""
    Write-Host "更新未完成：$message" -ForegroundColor Red
    Finish $false
}

function Step([string]$message) {
    Write-Host ""
    Write-Host "→ $message" -ForegroundColor Cyan
}

function Invoke-Git {
    $output = & git -C $Root @args
    if ($LASTEXITCODE -ne 0) { Fail "git $($args -join ' ') 执行失败" }
    return $output
}

function Get-AppProcesses {
    # The running backend holds backend.jar open, so the app must be closed before rebuilding
    Get-CimInstance Win32_Process | Where-Object {
        ($_.ExecutablePath -and $_.ExecutablePath.StartsWith($Root + '\', [StringComparison]::OrdinalIgnoreCase)) -or
        ($_.Name -eq 'java.exe' -and $_.CommandLine -and $_.CommandLine.Contains($Root) -and $_.CommandLine.Contains('backend.jar'))
    }
}

Write-Host "Fribbels 配装器 · 更新" -ForegroundColor White
Write-Host "程序目录：$Root" -ForegroundColor DarkGray

foreach ($tool in @($Mvn, (Join-Path $NodeDir 'node.exe'), (Join-Path $Jdk 'bin\java.exe'))) {
    if (-not (Test-Path $tool)) { Fail "缺少编译工具 $tool" }
}

if ($WaitForApp) {
    $deadline = (Get-Date).AddSeconds(60)
    while ((Get-AppProcesses) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500 }
}
if (Get-AppProcesses) { Fail "配装器还开着。请先关闭它再更新。" }
$canRelaunch = $true

if (Invoke-Git status --porcelain --untracked-files=no) {
    Fail "有未提交的改动，请先提交或撤销（git status 查看）。"
}

if (-not $Remote) {
    $Remote = if (@(Invoke-Git remote) -contains 'upstream') { 'upstream' } else { 'origin' }
}

# Steps still owed from a merge are kept in the git dir, so a failed build is retried on the next run
$PendingFile = Join-Path ((Invoke-Git rev-parse --absolute-git-dir) | Select-Object -First 1) 'fribbels-update-pending'
$AllTasks = @('deps', 'backend', 'app')
$tasks = @()
if (Test-Path $PendingFile) {
    $tasks = @(Get-Content $PendingFile | Where-Object { $AllTasks -contains $_ })
    if ($tasks.Count) { Write-Host ("继续上次没完成的步骤：" + (($tasks | ForEach-Object { $TaskNames[$_] }) -join '、')) -ForegroundColor Yellow }
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

Step "获取 $Remote/$Branch 的更新"
& git -C $Root fetch --quiet $Remote $Branch
if ($LASTEXITCODE -ne 0) { Fail "无法连接 GitHub，请检查网络后重试。" }

$incoming = @(Invoke-Git log --oneline "HEAD..$Remote/$Branch")
$dataChanged = $false
if ($incoming.Count) {
    Write-Host ("有 {0} 个新提交：" -f $incoming.Count)
    $incoming | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }

    $before = (Invoke-Git rev-parse HEAD) | Select-Object -First 1

    Step "合并"
    & git -C $Root merge --quiet --no-edit "$Remote/$Branch"
    if ($LASTEXITCODE -ne 0) {
        $conflicts = @(Invoke-Git diff --name-only --diff-filter=U)
        if ($conflicts.Count -eq 1 -and $conflicts[0] -eq $Jar) {
            # Both sides changed the binary jar; it is rebuilt from the merged source below anyway
            Write-Host "只有 backend.jar 冲突，接下来会用合并后的源码重新编译。"
            Invoke-Git checkout --theirs -- $Jar | Out-Null
            Invoke-Git add -- $Jar | Out-Null
            Invoke-Git commit --no-edit | Out-Null
            $tasks += 'backend'
        } else {
            & git -C $Root merge --abort
            Fail ("合并冲突，需要手动处理：" + ($conflicts -join ', '))
        }
    }

    $changed = @(Invoke-Git diff --name-only $before HEAD)
    if ($changed | Where-Object { $_ -match '^(app/)?(package\.json|yarn\.lock)$' }) { $tasks += 'deps', 'app' }
    if ($changed | Where-Object { $_ -match '^backend/(src/|pom\.xml)' -or $_ -eq $Jar }) { $tasks += 'backend' }
    if ($changed | Where-Object { $_ -match '^(app|configs|internals)/' -and $_ -notmatch '^app/(js|assets|css|locales)/' }) { $tasks += 'app' }
    $dataChanged = [bool]($changed | Where-Object { $_ -match '^data/(cache|cachedimages|locales)/' })
} elseif (-not $tasks.Count) {
    Write-Host ""
    Write-Host "√ 已经是最新版本。" -ForegroundColor Green
    Finish $true
}

# Keep a fixed order and drop duplicates
$tasks = @($AllTasks | Where-Object { $tasks -contains $_ })
$ran = @($tasks)
Save-Pending

if ($tasks -contains 'deps') {
    Step $TaskNames['deps']
    Push-Location $Root
    & yarn install --non-interactive --silent --network-timeout 600000
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -ne 0) { Fail "安装依赖失败。再运行一次更新会从这一步继续。" }
    if (Invoke-Git status --porcelain --untracked-files=no -- yarn.lock app/yarn.lock) {
        Invoke-Git add -- yarn.lock app/yarn.lock | Out-Null
        Invoke-Git commit -m "Update yarn.lock after merging upstream" | Out-Null
    }
    Complete-Task 'deps'
}

if ($tasks -contains 'backend') {
    Step $TaskNames['backend']
    Push-Location (Join-Path $Root 'backend')
    & $Mvn -q -B package "-Dmaven.repo.local=$(Join-Path $Toolchain 'm2')"
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -ne 0) { Fail "后端编译失败。再运行一次更新会从这一步继续。" }
    Copy-Item -Force (Join-Path $Root 'backend\target\backend.jar') (Join-Path $Root $Jar)
    if (Invoke-Git status --porcelain --untracked-files=no -- $Jar) {
        Invoke-Git add -- $Jar | Out-Null
        Invoke-Git commit -m "Rebuild backend.jar after merging upstream" | Out-Null
    }
    Complete-Task 'backend'
}

if ($tasks -contains 'app') {
    Step $TaskNames['app']
    Push-Location $Root
    & yarn --silent build | Out-Null
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -ne 0) { Fail "前端编译失败（可运行 yarn build 查看详情）。再运行一次更新会从这一步继续。" }
    Complete-Task 'app'
}

# Upstream could reintroduce the two settings this branch turned off
$heroData = Get-Content -Raw (Join-Path $Root 'app\js\lib\heroData.js')
if ($heroData -match '(?m)^\s*global\.TEST\s*=\s*true') {
    Write-Host "注意：app/js/lib/heroData.js 又出现了 global.TEST = true，程序将不会从服务器拉取数据。" -ForegroundColor Yellow
}
$mainDev = Get-Content -Raw (Join-Path $Root 'app\main.dev.js')
if ($mainDev -match 'allowDowngrade\s*=\s*true') {
    Write-Host "注意：app/main.dev.js 又允许自动更新降级，官方旧版可能会覆盖这个版本。" -ForegroundColor Yellow
}

Write-Host ""
Write-Host ("√ 更新完成：合并了 {0} 个提交。" -f $incoming.Count) -ForegroundColor Green
if ($ran.Count) { Write-Host ("  执行的步骤：" + (($ran | ForEach-Object { $TaskNames[$_] }) -join '、')) }
if ($dataChanged) { Write-Host "  自带的英雄、神器数据或翻译有更新。" }
Finish $true
