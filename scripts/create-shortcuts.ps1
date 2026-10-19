# Creates the three entry shortcuts (start, update, importer check) with the app icon.
# By default they go into the repo root; -Desktop and -StartMenu also place them there.
param(
    [switch]$Desktop,
    [switch]$StartMenu
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Icon = Join-Path $Root 'resources\icon.ico'
$Electron = Join-Path $Root 'node_modules\electron\dist\electron.exe'

$entries = @(
    @{ Name = 'Fribbels 配装器'; Target = $Electron; Arguments = 'app'; Description = '启动 Fribbels E7 配装器' },
    @{ Name = '更新配装器'; Target = (Join-Path $PSScriptRoot 'update-optimizer.cmd'); Arguments = ''; Description = '合并原仓库的更新并按需重新编译' },
    @{ Name = '检测导入环境'; Target = (Join-Path $PSScriptRoot 'check-importer.cmd'); Arguments = ''; Description = '检查自动导入需要的 Python、Npcap 和网卡' }
)

$folders = @($Root)
if ($Desktop) { $folders += [Environment]::GetFolderPath('Desktop') }
if ($StartMenu) {
    $menuFolder = Join-Path ([Environment]::GetFolderPath('Programs')) 'Fribbels 配装器'
    New-Item -ItemType Directory -Force $menuFolder | Out-Null
    $folders += $menuFolder
}

$shell = New-Object -ComObject WScript.Shell
foreach ($folder in $folders) {
    foreach ($entry in $entries) {
        $path = Join-Path $folder ($entry.Name + '.lnk')
        $shortcut = $shell.CreateShortcut($path)
        $shortcut.TargetPath = $entry.Target
        $shortcut.Arguments = $entry.Arguments
        $shortcut.WorkingDirectory = $Root
        $shortcut.IconLocation = "$Icon,0"
        $shortcut.Description = $entry.Description
        $shortcut.Save()
        Write-Host "已创建：$path"
    }
}
