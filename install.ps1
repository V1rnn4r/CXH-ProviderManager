param(
    [string]$ManagerInstallDir,
    [string]$CodexHome
)

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
# 解析 Codex Home
# ============================================================

$CodexHomeWasExplicit = $PSBoundParameters.ContainsKey("CodexHome")

if ([string]::IsNullOrWhiteSpace($CodexHome)) {
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        $CodexHome = $env:CODEX_HOME
    }
    else {
        $SavedCodexHome = [Environment]::GetEnvironmentVariable(
            "CODEX_HOME",
            [EnvironmentVariableTarget]::User
        )

        if (-not [string]::IsNullOrWhiteSpace($SavedCodexHome)) {
            $CodexHome = $SavedCodexHome
        }
        else {
            $CodexHome = Join-Path $env:USERPROFILE ".codex"
        }
    }
}

$CodexHome = [System.IO.Path]::GetFullPath(
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
        $CodexHome
    )
)

if (!(Test-Path -LiteralPath $CodexHome)) {
    New-Item -ItemType Directory -Force -Path $CodexHome | Out-Null
}

# 如果用户显式指定了 CodexHome，则让 Codex CLI 和 CXH 都永久使用同一目录。
if ($CodexHomeWasExplicit) {
    [Environment]::SetEnvironmentVariable(
        "CODEX_HOME",
        $CodexHome,
        [EnvironmentVariableTarget]::User
    )

    $env:CODEX_HOME = $CodexHome

    Write-Host "已设置当前用户 CODEX_HOME：" -ForegroundColor Green
    Write-Host "  $CodexHome"
}
elseif ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
    # 用户级变量可能已存在，但当前 PowerShell 是旧会话。
    $SavedCodexHome = [Environment]::GetEnvironmentVariable(
        "CODEX_HOME",
        [EnvironmentVariableTarget]::User
    )

    if (-not [string]::IsNullOrWhiteSpace($SavedCodexHome)) {
        $env:CODEX_HOME = $SavedCodexHome
    }
}

# ============================================================
# 解析 CXH 管理器安装目录
# ============================================================

# 默认直接安装到 Codex Home。
# 如需源码、管理器、Codex 数据三者完全分离，可显式传入 -ManagerInstallDir。
if ([string]::IsNullOrWhiteSpace($ManagerInstallDir)) {
    $ManagerInstallDir = $CodexHome
}

$ManagerInstallDir = [System.IO.Path]::GetFullPath(
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
        $ManagerInstallDir
    )
)

if (!(Test-Path -LiteralPath $ManagerInstallDir)) {
    New-Item -ItemType Directory -Force -Path $ManagerInstallDir | Out-Null
}

# ============================================================
# 源文件
# ============================================================

$SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceManager = Join-Path $SourceDir "CodexProviderManager.ps1"
$TargetManager = Join-Path $ManagerInstallDir "CodexProviderManager.ps1"

if (!(Test-Path -LiteralPath $SourceManager)) {
    throw "找不到 CodexProviderManager.ps1：$SourceManager"
}

Write-Host ""
Write-Host "Codex 数据目录：" -ForegroundColor Cyan
Write-Host "  $CodexHome"

Write-Host "CXH 管理器目录：" -ForegroundColor Cyan
Write-Host "  $ManagerInstallDir"

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

$EscapedTargetManager = $TargetManager.Replace("'", "''")
$EscapedCodexHome = $CodexHome.Replace("'", "''")

$LoaderBlock = @"
$BeginMarker
# CXH Provider Manager

# Keep this PowerShell session aligned with the Codex data directory
# selected during installation.
`$env:CODEX_HOME = '$EscapedCodexHome'

`$cxhManager = '$EscapedTargetManager'

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

    # Windows PowerShell 5.1 may parse UTF-8-without-BOM files as ANSI.
    # Always write the profile as UTF-8 with BOM so the same profile works
    # in both Windows PowerShell 5.1 and PowerShell 7+.
    $Utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText(
        $ProfilePath,
        $NewProfile,
        $Utf8Bom
    )

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

$env:CODEX_HOME = $CodexHome
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

Write-Host "Codex 数据目录：" -ForegroundColor Cyan
Write-Host "  $CodexHome"

Write-Host "CXH 管理器：" -ForegroundColor Cyan
Write-Host "  $TargetManager"

Write-Host "PowerShell Profile：" -ForegroundColor Cyan
Write-Host "  $ProfilePath"

Write-Host ""
Write-Host "立即可用：" -ForegroundColor Cyan
Write-Host "  cxlist"
Write-Host "  cx official"
Write-Host "  cxh official"

Write-Host ""
Write-Host "关闭并重新打开 PowerShell 后，CODEX_HOME 与 CXH 都会自动加载。"
Write-Host ""
