param(
    [string]$SourceDir,
    [string]$ManagerInstallDir,
    [string]$CodexHome,
    [string]$RepoUrl = "https://github.com/V1rnn4r/CXH-ProviderManager.git"
)

# ============================================================
# CXH Downloader + Installer
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "       CXH Downloader + Installer           " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 检查 Git
# ============================================================

$git = Get-Command git -ErrorAction SilentlyContinue
if (!$git) {
    throw "未找到 git。请先安装 Git for Windows，然后重新运行本脚本。"
}

# ============================================================
# 1. 源码下载目录
# ============================================================

if ([string]::IsNullOrWhiteSpace($SourceDir)) {
    $DefaultSourceDir = Join-Path $env:USERPROFILE "CXH-ProviderManager"

    Write-Host "1/3 选择 Git 仓库源码目录" -ForegroundColor Cyan
    Write-Host "可以放在任意盘，例如：" -ForegroundColor DarkGray
    Write-Host "  D:\Tools\CXH-ProviderManager" -ForegroundColor DarkGray
    Write-Host "  E:\project\cxh" -ForegroundColor DarkGray
    Write-Host ""

    $answer = Read-Host "源码下载目录（直接回车使用 $DefaultSourceDir）"

    if ([string]::IsNullOrWhiteSpace($answer)) {
        $SourceDir = $DefaultSourceDir
    }
    else {
        $SourceDir = $answer
    }
}

$SourceDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SourceDir)

# ============================================================
# 2. Codex 数据目录
# ============================================================

if ([string]::IsNullOrWhiteSpace($CodexHome)) {
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        $DefaultCodexHome = $env:CODEX_HOME
    }
    else {
        $SavedCodexHome = [Environment]::GetEnvironmentVariable(
            "CODEX_HOME",
            [EnvironmentVariableTarget]::User
        )

        if (-not [string]::IsNullOrWhiteSpace($SavedCodexHome)) {
            $DefaultCodexHome = $SavedCodexHome
        }
        else {
            $DefaultCodexHome = Join-Path $env:USERPROFILE ".codex"
        }
    }

    Write-Host ""
    Write-Host "2/3 选择 Codex 数据目录" -ForegroundColor Cyan
    Write-Host "这里保存 config.toml、Provider 配置、Registry、Session 等。" -ForegroundColor DarkGray
    Write-Host "如果你的 Codex 数据本来就在 D/E 盘，请直接填写现有目录。" -ForegroundColor Yellow
    Write-Host "脚本不会搬迁或删除你已有的数据。" -ForegroundColor DarkGray
    Write-Host ""

    $answer = Read-Host "Codex 数据目录（直接回车使用 $DefaultCodexHome）"

    if ([string]::IsNullOrWhiteSpace($answer)) {
        $CodexHome = $DefaultCodexHome
    }
    else {
        $CodexHome = $answer
    }
}

$CodexHome = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($CodexHome)

# ============================================================
# 3. CXH 管理器目录
# ============================================================

if ([string]::IsNullOrWhiteSpace($ManagerInstallDir)) {
    $DefaultManagerDir = $CodexHome

    Write-Host ""
    Write-Host "3/3 选择 CXH 管理器安装目录" -ForegroundColor Cyan
    Write-Host "默认与 Codex 数据放在一起。" -ForegroundColor DarkGray
    Write-Host "也可以单独放，例如 D:\Tools\CXH。" -ForegroundColor DarkGray
    Write-Host ""

    $answer = Read-Host "CXH 管理器安装目录（直接回车使用 $DefaultManagerDir）"

    if ([string]::IsNullOrWhiteSpace($answer)) {
        $ManagerInstallDir = $DefaultManagerDir
    }
    else {
        $ManagerInstallDir = $answer
    }
}

$ManagerInstallDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ManagerInstallDir)

Write-Host ""
Write-Host "========== 安装计划 ==========" -ForegroundColor Cyan
Write-Host "源码目录：      $SourceDir"
Write-Host "Codex 数据目录：$CodexHome"
Write-Host "CXH 管理器目录：$ManagerInstallDir"

# ============================================================
# 下载 / 更新 Git 仓库
# ============================================================

if (Test-Path -LiteralPath $SourceDir) {
    $gitDir = Join-Path $SourceDir ".git"

    if (Test-Path -LiteralPath $gitDir) {
        Write-Host ""
        Write-Host "检测到已有 Git 仓库，正在更新..." -ForegroundColor Cyan

        git -C $SourceDir pull --ff-only

        if ($LASTEXITCODE -ne 0) {
            throw "git pull 失败。"
        }
    }
    else {
        $items = @(Get-ChildItem -LiteralPath $SourceDir -Force -ErrorAction SilentlyContinue)

        if ($items.Count -gt 0) {
            throw "目标目录已经存在且不是空 Git 仓库：$SourceDir`n请换一个目录，或手动清理后重试。"
        }

        Write-Host ""
        Write-Host "正在克隆 CXH..." -ForegroundColor Cyan

        git clone $RepoUrl $SourceDir

        if ($LASTEXITCODE -ne 0) {
            throw "git clone 失败。"
        }
    }
}
else {
    $parent = Split-Path -Parent $SourceDir

    if (![string]::IsNullOrWhiteSpace($parent) -and !(Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    Write-Host ""
    Write-Host "正在克隆 CXH..." -ForegroundColor Cyan

    git clone $RepoUrl $SourceDir

    if ($LASTEXITCODE -ne 0) {
        throw "git clone 失败。"
    }
}

# ============================================================
# 调用正式安装器
# ============================================================

$Installer = Join-Path $SourceDir "install.ps1"

if (!(Test-Path -LiteralPath $Installer)) {
    throw "仓库中找不到 install.ps1：$Installer"
}

Write-Host ""
Write-Host "开始安装 CXH..." -ForegroundColor Cyan

& $Installer `
    -CodexHome $CodexHome `
    -ManagerInstallDir $ManagerInstallDir

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "         下载 + 安装全部完成               " -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

Write-Host "源码目录：" -ForegroundColor Cyan
Write-Host "  $SourceDir"

Write-Host "Codex 数据目录：" -ForegroundColor Cyan
Write-Host "  $CodexHome"

Write-Host "CXH 管理器：" -ForegroundColor Cyan
Write-Host "  $(Join-Path $ManagerInstallDir 'CodexProviderManager.ps1')"

Write-Host ""
Write-Host "以后更新：" -ForegroundColor Cyan
Write-Host "  git -C `"$SourceDir`" pull"
Write-Host "  pwsh -File `"$Installer`" -CodexHome `"$CodexHome`" -ManagerInstallDir `"$ManagerInstallDir`""
Write-Host ""
