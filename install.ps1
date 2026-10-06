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
# 环境检查
# ============================================================

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "当前 PowerShell 版本为 $($PSVersionTable.PSVersion)。推荐使用 PowerShell 7+。"
}

$codexCommand = Get-Command codex -ErrorAction SilentlyContinue
if (!$codexCommand) {
    Write-Warning "当前终端找不到 codex 命令。CXH 仍会安装，但使用前请先安装/修复 OpenAI Codex CLI。"
}
else {
    Write-Host "Codex CLI：" -ForegroundColor DarkGray
    Write-Host "  $($codexCommand.Source)" -ForegroundColor DarkGray
}

# ============================================================
# 路径
# ============================================================

$SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceManager = Join-Path $SourceDir "CodexProviderManager.ps1"

$CodexHome = Join-Path $env:USERPROFILE ".codex"
$TargetManager = Join-Path $CodexHome "CodexProviderManager.ps1"

if (!(Test-Path -LiteralPath $SourceManager)) {
    throw "找不到 CodexProviderManager.ps1：$SourceManager"
}

if (!(Test-Path -LiteralPath $CodexHome)) {
    New-Item -ItemType Directory -Force -Path $CodexHome | Out-Null
}

# ============================================================
# 备份旧管理器
# ============================================================

if (Test-Path -LiteralPath $TargetManager) {
    $BackupManager = "$TargetManager.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -LiteralPath $TargetManager -Destination $BackupManager -Force

    Write-Host ""
    Write-Host "已备份旧管理器：" -ForegroundColor Yellow
    Write-Host "  $BackupManager"
}

# ============================================================
# 安装管理器 + SHA256 校验
# ============================================================

Copy-Item -LiteralPath $SourceManager -Destination $TargetManager -Force

$SourceHash = (Get-FileHash -LiteralPath $SourceManager -Algorithm SHA256).Hash
$TargetHash = (Get-FileHash -LiteralPath $TargetManager -Algorithm SHA256).Hash

if ($SourceHash -ne $TargetHash) {
    throw "CodexProviderManager.ps1 复制后 SHA256 不一致，安装已中止。"
}

Write-Host ""
Write-Host "管理器已安装：" -ForegroundColor Green
Write-Host "  $TargetManager"
Write-Host "SHA256：" -ForegroundColor DarkGray
Write-Host "  $TargetHash" -ForegroundColor DarkGray

# ============================================================
# PowerShell Profile
# ============================================================

$ProfilePath = $PROFILE.CurrentUserAllHosts
$ProfileDir = Split-Path -Parent $ProfilePath

if (!(Test-Path -LiteralPath $ProfileDir)) {
    New-Item -ItemType Directory -Force -Path $ProfileDir | Out-Null
}

if (!(Test-Path -LiteralPath $ProfilePath)) {
    New-Item -ItemType File -Force -Path $ProfilePath | Out-Null
}

$BeginMarker = "# >>> CXH-PROVIDER-MANAGER"
$EndMarker   = "# <<< CXH-PROVIDER-MANAGER"

$LoaderBlock = @"
$BeginMarker
# CXH Provider Manager
`$cxhManager = Join-Path `$env:USERPROFILE ".codex\CodexProviderManager.ps1"

if (Test-Path -LiteralPath `$cxhManager) {
    try {
        . `$cxhManager
    }
    catch {
        Write-Warning "Codex Provider Manager 加载失败：`$(`$_.Exception.Message)"
    }
}
else {
    Write-Warning "找不到 Codex Provider Manager：`$cxhManager"
}
$EndMarker
"@

$ExistingProfile = Get-Content -Raw -ErrorAction SilentlyContinue -LiteralPath $ProfilePath
if ($null -eq $ExistingProfile) {
    $ExistingProfile = ""
}

$ManagedPattern = "(?ms)" +
    [regex]::Escape($BeginMarker) +
    ".*?" +
    [regex]::Escape($EndMarker)

if ([regex]::IsMatch($ExistingProfile, $ManagedPattern)) {
    $NewProfile = [regex]::Replace(
        $ExistingProfile,
        $ManagedPattern,
        [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $LoaderBlock }
    )

    $ProfileChanged = ($NewProfile -ne $ExistingProfile)
}
else {
    $prefix = $ExistingProfile.TrimEnd()

    if ([string]::IsNullOrWhiteSpace($prefix)) {
        $NewProfile = $LoaderBlock + [Environment]::NewLine
    }
    else {
        $NewProfile = $prefix +
            [Environment]::NewLine +
            [Environment]::NewLine +
            $LoaderBlock +
            [Environment]::NewLine
    }

    $ProfileChanged = $true
}

if ($ProfileChanged) {
    if ((Test-Path -LiteralPath $ProfilePath) -and (Get-Item -LiteralPath $ProfilePath).Length -gt 0) {
        $ProfileBackup = "$ProfilePath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $ProfilePath -Destination $ProfileBackup -Force

        Write-Host ""
        Write-Host "已备份 PowerShell Profile：" -ForegroundColor Yellow
        Write-Host "  $ProfileBackup"
    }

    Set-Content -LiteralPath $ProfilePath -Value $NewProfile -Encoding UTF8

    Write-Host ""
    Write-Host "已写入/更新 PowerShell Profile：" -ForegroundColor Green
    Write-Host "  $ProfilePath"
}
else {
    Write-Host ""
    Write-Host "PowerShell Profile 中的 CXH Loader 已是最新。" -ForegroundColor DarkGray
    Write-Host "  $ProfilePath" -ForegroundColor DarkGray
}

# ============================================================
# 当前终端立即加载并检查公开命令
# ============================================================

. $TargetManager

$RequiredCommands = @(
    "cx",
    "cxr",
    "cxh",
    "cxadd",
    "cximport",
    "cxsetkey",
    "cxlogin",
    "cxlist",
    "cxtest",
    "cxrepair",
    "cxinit"
)

$MissingCommands = @(
    foreach ($name in $RequiredCommands) {
        if (!(Get-Command $name -ErrorAction SilentlyContinue)) {
            $name
        }
    }
)

if ($MissingCommands.Count -gt 0) {
    throw "安装完成但以下命令未成功加载：$($MissingCommands -join ', ')"
}

# ============================================================
# 完成
# ============================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "              CXH 安装完成                  " -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

Write-Host "PowerShell Profile：" -ForegroundColor Cyan
Write-Host "  $ProfilePath"

Write-Host ""
Write-Host "立即可用：" -ForegroundColor Cyan
Write-Host "  cxlist"
Write-Host "  cx official"
Write-Host "  cxh official"

Write-Host ""
Write-Host "新增 Provider：" -ForegroundColor Cyan
Write-Host "  cxadd lumon https://www.lumoncode.com/v1 gpt-6-astra"

Write-Host ""
Write-Host "如果要使用 Codex 的 --remote 或 agents 等依赖 shared daemon 的模式，" -ForegroundColor DarkYellow
Write-Host "请优先在非管理员 PowerShell 中运行。" -ForegroundColor DarkYellow

Write-Host ""
Write-Host "关闭并重新打开 PowerShell 后，CXH 仍会通过 CurrentUserAllHosts Profile 自动加载。"
Write-Host ""
