# ============================================================
# CXH Provider Manager Installer
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "       CXH Provider Manager Installer       " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""


# ============================================================
# 检查 PowerShell
# ============================================================

if ($PSVersionTable.PSVersion.Major -lt 7) {

    Write-Warning "推荐使用 PowerShell 7+。"

    Write-Host ""
    Write-Host "当前版本：" `
        $PSVersionTable.PSVersion
}


# ============================================================
# 路径
# ============================================================

$SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$SourceManager = Join-Path `
    $SourceDir `
    "CodexProviderManager.ps1"

$CodexHome = Join-Path `
    $env:USERPROFILE `
    ".codex"

$TargetManager = Join-Path `
    $CodexHome `
    "CodexProviderManager.ps1"


# ============================================================
# 检查源文件
# ============================================================

if (!(Test-Path $SourceManager)) {

    throw "找不到 CodexProviderManager.ps1：$SourceManager"

}


# ============================================================
# 创建 ~/.codex
# ============================================================

if (!(Test-Path $CodexHome)) {

    New-Item `
        -ItemType Directory `
        -Force `
        -Path $CodexHome |
        Out-Null

}


# ============================================================
# 备份旧管理器
# ============================================================

if (Test-Path $TargetManager) {

    $BackupManager =
        $TargetManager +
        ".bak-" +
        (Get-Date -Format "yyyyMMdd-HHmmss")

    Copy-Item `
        $TargetManager `
        $BackupManager `
        -Force

    Write-Host "已备份旧管理器：" -ForegroundColor Yellow
    Write-Host "  $BackupManager"

}


# ============================================================
# 安装管理器
# ============================================================

Copy-Item `
    $SourceManager `
    $TargetManager `
    -Force

Write-Host ""
Write-Host "管理器已安装：" -ForegroundColor Green
Write-Host "  $TargetManager"


# ============================================================
# PowerShell Profile
# ============================================================

$ProfilePath = $PROFILE.CurrentUserAllHosts
$ProfileDir = Split-Path -Parent $ProfilePath

if (!(Test-Path $ProfileDir)) {

    New-Item `
        -ItemType Directory `
        -Force `
        -Path $ProfileDir |
        Out-Null

}

if (!(Test-Path $ProfilePath)) {

    New-Item `
        -ItemType File `
        -Force `
        -Path $ProfilePath |
        Out-Null

}


# ============================================================
# 自动加载语句
# ============================================================

$BeginMarker = "# >>> CXH-PROVIDER-MANAGER"
$EndMarker   = "# <<< CXH-PROVIDER-MANAGER"

$LoaderBlock = @"

$BeginMarker

# CXH Provider Manager
`$cxhManager = "`$env:USERPROFILE\.codex\CodexProviderManager.ps1"

if (Test-Path `$cxhManager) {
    . `$cxhManager
}

$EndMarker

"@

$ExistingProfile = Get-Content `
    -Raw `
    -ErrorAction SilentlyContinue `
    $ProfilePath

if ($ExistingProfile -notmatch [regex]::Escape($BeginMarker)) {

    Add-Content `
        -Path $ProfilePath `
        -Value $LoaderBlock `
        -Encoding UTF8

    Write-Host ""
    Write-Host "已写入 PowerShell Profile：" -ForegroundColor Green
    Write-Host "  $ProfilePath"

}
else {

    Write-Host ""
    Write-Host "PowerShell Profile 已包含 CXH Loader。" `
        -ForegroundColor DarkGray

}


# ============================================================
# 当前终端加载
# ============================================================

. $TargetManager


# ============================================================
# 完成
# ============================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "           CXH 安装完成                     " -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green

Write-Host ""
Write-Host "可以立即运行：" -ForegroundColor Cyan

Write-Host ""
Write-Host "  cxlist"
Write-Host "  cx official"

Write-Host ""
Write-Host "新增 Provider 示例："

Write-Host ""
Write-Host "  cxadd lumon https://www.lumoncode.com/v1 gpt-6-astra"

Write-Host ""
Write-Host "关闭并重新打开 PowerShell 后也会自动加载 CXH。"
Write-Host ""