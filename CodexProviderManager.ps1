$script:CxHome     = Join-Path $env:USERPROFILE ".codex"
$script:CxConfig   = Join-Path $script:CxHome "config.toml"
$script:CxRegistry = Join-Path $script:CxHome "providers.json"


function ConvertTo-CxSafeId {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    $id = $Name.ToLower() -replace '[^a-z0-9_-]', '-'
    $id = $id.Trim('-')

    if ([string]::IsNullOrWhiteSpace($id)) {
        throw "API 名称无效。"
    }

    return $id
}


function Escape-CxToml {
    param(
        [string]$Text
    )

    if ($null -eq $Text) {
        return ""
    }

    return $Text.Replace('\', '\\').Replace('"', '\"')
}

function Expand-CxRegistryValue {
    param(
        $Value
    )

    if ($null -eq $Value) {
        return
    }

    if ($Value -is [System.Array]) {
        foreach ($item in $Value) {
            Expand-CxRegistryValue $item
        }

        return
    }

    $propertyNames = @(
        $Value.PSObject.Properties |
        ForEach-Object { $_.Name }
    )

    # Provider Record
    if ($propertyNames -contains "profile") {
        Write-Output $Value
        return
    }

    foreach ($property in $Value.PSObject.Properties) {
        $child = $property.Value

        if ($null -eq $child) {
            continue
        }

        if ($child -is [System.Array]) {
            Expand-CxRegistryValue $child
            continue
        }

        $childProperties = @(
            $child.PSObject.Properties |
            ForEach-Object { $_.Name }
        )

        if ($childProperties -contains "profile") {
            Write-Output $child
        }
    }
}


function Get-CxRegistry {
    if (!(Test-Path $script:CxRegistry)) {
        return
    }

    $raw = Get-Content `
        -Raw `
        -Encoding UTF8 `
        $script:CxRegistry

    if ([string]::IsNullOrWhiteSpace($raw)) {
        return
    }

    try {
        $parsed = $raw | ConvertFrom-Json
    }
    catch {
        Write-Warning "providers.json 无法解析，将忽略旧 Registry。"
        return
    }

    Expand-CxRegistryValue $parsed
}

function Save-CxRegistry {
    param(
        [object[]]$Items
    )

    $map = [ordered]@{}

    foreach ($item in @($Items)) {
        foreach ($record in @(Expand-CxRegistryValue $item)) {

            if ($null -eq $record) {
                continue
            }

            if ([string]::IsNullOrWhiteSpace($record.profile)) {
                continue
            }

            $map[$record.profile] = [ordered]@{
                name        = $record.name
                profile     = $record.profile
                provider    = $record.provider
                base_url    = $record.base_url
                env_key     = $record.env_key
                model       = $record.model
                reasoning   = $record.reasoning
                service_tier = $record.service_tier
                auth        = $record.auth
                launch      = $record.launch
                resume_last = $record.resume_last
                history     = $record.history
            }
        }
    }

    $json = $map |
        ConvertTo-Json -Depth 10

    Set-Content `
        -Path $script:CxRegistry `
        -Value $json `
        -Encoding UTF8
}


function Get-CxRecord {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    return @(
        Get-CxRegistry |
        Where-Object {
            $_.profile  -eq $Name -or
            $_.provider -eq $Name -or
            $_.name     -eq $Name
        }
    ) |
    Select-Object -First 1
}


function Resolve-CxProfile {
    param(
        [string]$Name
    )

    if (
        [string]::IsNullOrWhiteSpace($Name) -or
        $Name -eq "official" -or
        $Name -eq "openai"
    ) {
        return $null
    }

    $profilePath = Join-Path `
        $script:CxHome `
        "$Name.config.toml"

    if (Test-Path $profilePath) {
        return $Name
    }

    $record = Get-CxRecord $Name

    if ($record) {
        return $record.profile
    }

    throw "没有找到 Codex Profile：$Name"
}


function Get-CxProfileInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Profile
    )

    $profilePath = Join-Path `
        $script:CxHome `
        "$Profile.config.toml"

    if (!(Test-Path $profilePath)) {
        throw "找不到 Profile：$profilePath"
    }

    $text = Get-Content `
        -Raw `
        -Encoding UTF8 `
        $profilePath

    $providerMatch = [regex]::Match(
        $text,
        '(?m)^\s*model_provider\s*=\s*"([^"]+)"'
    )

    if (!$providerMatch.Success) {
        throw "$Profile.config.toml 中找不到 model_provider"
    }

    $modelMatch = [regex]::Match(
        $text,
        '(?m)^\s*model\s*=\s*"([^"]+)"'
    )

    $reasoningMatch = [regex]::Match(
        $text,
        '(?m)^\s*model_reasoning_effort\s*=\s*"([^"]+)"'
    )

    $tierMatch = [regex]::Match(
        $text,
        '(?m)^\s*service_tier\s*=\s*"([^"]+)"'
    )

    return [pscustomobject]@{
        profile      = $Profile
        provider     = $providerMatch.Groups[1].Value

        model        = if ($modelMatch.Success) {
            $modelMatch.Groups[1].Value
        }
        else {
            ""
        }

        reasoning    = if ($reasoningMatch.Success) {
            $reasoningMatch.Groups[1].Value
        }
        else {
            ""
        }

        service_tier = if ($tierMatch.Success) {
            $tierMatch.Groups[1].Value
        }
        else {
            ""
        }
    }
}


function Get-CxProviderInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Provider
    )

    if (!(Test-Path $script:CxConfig)) {
        throw "找不到 $script:CxConfig"
    }

    $config = Get-Content `
        -Raw `
        -Encoding UTF8 `
        $script:CxConfig

    $escaped = [regex]::Escape($Provider)

    $pattern =
        "(?ms)^\[model_providers\.$escaped\]\s*\r?\n" +
        "(?<body>.*?)(?=^\[|\z)"

    $section = [regex]::Match(
        $config,
        $pattern
    )

    if (!$section.Success) {
        return $null
    }

    $body = $section.Groups["body"].Value

    $nameMatch = [regex]::Match(
        $body,
        '(?m)^\s*name\s*=\s*"([^"]+)"'
    )

    $baseMatch = [regex]::Match(
        $body,
        '(?m)^\s*base_url\s*=\s*"([^"]+)"'
    )

    $envMatch = [regex]::Match(
        $body,
        '(?m)^\s*env_key\s*=\s*"([^"]+)"'
    )

    return [pscustomobject]@{
        provider = $Provider

        name = if ($nameMatch.Success) {
            $nameMatch.Groups[1].Value
        }
        else {
            $Provider
        }

        base_url = if ($baseMatch.Success) {
            $baseMatch.Groups[1].Value
        }
        else {
            ""
        }

        env_key = if ($envMatch.Success) {
            $envMatch.Groups[1].Value
        }
        else {
            ""
        }
    }
}


# ============================================================
# API Key
# ============================================================

function Read-CxSecret {
    param(
        [string]$Prompt = "请输入 API Key"
    )

    Write-Host ""
    Write-Host "$Prompt（输入内容不会显示）：" `
        -ForegroundColor Cyan

    $secure = Read-Host -AsSecureString

    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
        $secure
    )

    try {
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
            $ptr
        )
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR(
            $ptr
        )
    }

    if ([string]::IsNullOrWhiteSpace($plain)) {
        throw "API Key 不能为空。"
    }

    return $plain
}


function Set-CxApiKeyValue {
    param(
        [Parameter(Mandatory=$true)]
        [string]$EnvName,

        [Parameter(Mandatory=$true)]
        [string]$Value
    )

    # 永久保存到 Windows 用户环境变量
    [Environment]::SetEnvironmentVariable(
        $EnvName,
        $Value,
        "User"
    )

    # 当前 PowerShell 立即可用
    Set-Item `
        -Path "Env:$EnvName" `
        -Value $Value
}


# ============================================================
# 将 Windows 用户环境变量同步到当前 PowerShell
#
# 这样即使 VS Code 是设置 Key 之前启动的，
# cx lumon-other 也能自动拿到新的 API Key。
# ============================================================

function Sync-CxApiKeyToProcess {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    $record = Get-CxRecord $Name

    if (!$record) {
        $profilePath = Join-Path `
            $script:CxHome `
            "$Name.config.toml"

        if (Test-Path $profilePath) {
            cximport $Name | Out-Null
            $record = Get-CxRecord $Name
        }
    }

    if (!$record) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($record.env_key)) {
        return
    }

    $value = [Environment]::GetEnvironmentVariable(
        $record.env_key,
        "User"
    )

    if ([string]::IsNullOrWhiteSpace($value)) {
        throw @"
没有配置环境变量：

$($record.env_key)

请运行：

cxsetkey $($record.profile)

然后粘贴 API Key。
"@
    }

    Set-Item `
        -Path "Env:$($record.env_key)" `
        -Value $value
}


# ============================================================
# cxadd
#
# 新增一个 API Provider
#
# 示例：
#
# cxadd lumon-other https://www.lumoncode.com/v1 gpt-6-astra
# ============================================================

function cxadd {
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Name,

        [Parameter(Mandatory=$true, Position=1)]
        [string]$BaseUrl,

        [Parameter(Position=2)]
        [string]$Model = "gpt-6-astra",

        [ValidateSet(
            "minimal",
            "low",
            "medium",
            "high",
            "xhigh"
        )]
        [string]$Reasoning = "xhigh",

        [string]$ServiceTier = "default"
    )

    if (!(Test-Path $script:CxConfig)) {
        throw "找不到 $script:CxConfig"
    }

    $id = ConvertTo-CxSafeId $Name

    if (
        $id -eq "openai" -or
        $id -eq "official"
    ) {
        throw "openai / official 是保留名称。"
    }

    $base = $BaseUrl.TrimEnd('/')

    $envName =
        "CODEX_" +
        (($id.ToUpper()) -replace '-', '_') +
        "_API_KEY"

    $key = Read-CxSecret "$Name API Key"

    Set-CxApiKeyValue `
        -EnvName $envName `
        -Value $key

    $displayName = Escape-CxToml $Name
    $baseToml    = Escape-CxToml $base
    $modelToml   = Escape-CxToml $Model

    $config = Get-Content `
        -Raw `
        -Encoding UTF8 `
        $script:CxConfig

    $startMarker =
        "# >>> CODEX-PROVIDER-MANAGER:$id"

    $endMarker =
        "# <<< CODEX-PROVIDER-MANAGER:$id"

    $block = @"
$startMarker
[model_providers.$id]
name = "$displayName"
base_url = "$baseToml"
wire_api = "responses"
env_key = "$envName"
requires_openai_auth = false
$endMarker
"@

    $managedPattern =
        "(?ms)^" +
        [regex]::Escape($startMarker) +
        "\r?\n.*?^" +
        [regex]::Escape($endMarker) +
        "\r?\n?"

    if ([regex]::IsMatch(
        $config,
        $managedPattern
    )) {
        $config = [regex]::Replace(
            $config,
            $managedPattern,
            $block + "`r`n"
        )
    }
    else {
        $manualPattern =
            "(?m)^\[model_providers\." +
            [regex]::Escape($id) +
            "\]\s*$"

        if ([regex]::IsMatch(
            $config,
            $manualPattern
        )) {
            throw @"
config.toml 中已经存在：

[model_providers.$id]

如果它本来就是已有 API，请使用：

cximport $id

而不是重复 cxadd。
"@
        }

        $config =
            $config.TrimEnd() +
            "`r`n`r`n" +
            $block +
            "`r`n"
    }

    Set-Content `
        -Path $script:CxConfig `
        -Value $config `
        -Encoding UTF8

    # 创建 Profile
    $profilePath = Join-Path `
        $script:CxHome `
        "$id.config.toml"

    $profile = @"
model_provider = "$id"
model = "$modelToml"
model_reasoning_effort = "$Reasoning"
service_tier = "$ServiceTier"

approval_policy = "never"
sandbox_mode = "danger-full-access"
"@

    Set-Content `
        -Path $profilePath `
        -Value $profile `
        -Encoding UTF8

    # Registry
    $items = @(
        Get-CxRegistry |
        Where-Object {
            $_.profile  -ne $id -and
            $_.provider -ne $id
        }
    )

    $items += [pscustomobject]@{
        name         = $Name
        profile      = $id
        provider     = $id
        base_url     = $base
        env_key      = $envName
        model        = $Model
        reasoning    = $Reasoning
        service_tier = $ServiceTier
        auth         = "Windows User Environment Variable: $envName"
        launch       = "cx $id"
        resume_last  = "cxr $id"
        history      = "cxh $id"
    }

    Save-CxRegistry $items

    Write-Host ""
    Write-Host "=========================================" `
        -ForegroundColor Green
    Write-Host "Codex API 已添加：$Name" `
        -ForegroundColor Green
    Write-Host "=========================================" `
        -ForegroundColor Green

    Write-Host "Profile   : $id"
    Write-Host "Provider  : $id"
    Write-Host "Model     : $Model"
    Write-Host "Reasoning : $Reasoning"
    Write-Host "API Base  : $base"
    Write-Host "Key Env   : $envName"

    Write-Host ""
    Write-Host "启动：" -ForegroundColor Cyan
    Write-Host "  cx $id"

    Write-Host ""
    Write-Host "继续最近对话：" -ForegroundColor Cyan
    Write-Host "  cxr $id"

    Write-Host ""
    Write-Host "历史：" -ForegroundColor Cyan
    Write-Host "  cxh $id"

    Write-Host ""
    Write-Host "测试 API：" -ForegroundColor Cyan
    Write-Host "  cxtest $id"

    Write-Host ""
}


# ============================================================
# cximport
#
# 把已经存在的 *.config.toml Profile 登记到管理器
# ============================================================

function cximport {
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Profile
    )

    $profileInfo = Get-CxProfileInfo $Profile

    $providerInfo = Get-CxProviderInfo `
        $profileInfo.provider

    if (!$providerInfo) {
        throw @"
主 config.toml 中找不到 Provider：

[model_providers.$($profileInfo.provider)]
"@
    }

    $items = @(
        Get-CxRegistry |
        Where-Object {
            $_.profile -ne $Profile
        }
    )

    $items += [pscustomobject]@{
        name         = $Profile
        profile      = $Profile
        provider     = $profileInfo.provider
        base_url     = $providerInfo.base_url
        env_key      = $providerInfo.env_key
        model        = $profileInfo.model
        reasoning    = $profileInfo.reasoning
        service_tier = $profileInfo.service_tier

        auth = if ($providerInfo.env_key) {
            "Windows User Environment Variable: $($providerInfo.env_key)"
        }
        else {
            "See config.toml"
        }

        launch       = "cx $Profile"
        resume_last  = "cxr $Profile"
        history      = "cxh $Profile"
    }

    Save-CxRegistry $items

    Write-Host "已导入 Profile：$Profile" `
        -ForegroundColor Green
}


# ============================================================
# cxsetkey
#
# 给已有 API 设置 / 更换 API Key
#
# 示例：
# cxsetkey lumon-other
# ============================================================

function cxsetkey {
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Name
    )

    $record = Get-CxRecord $Name

    if (!$record) {
        $profilePath = Join-Path `
            $script:CxHome `
            "$Name.config.toml"

        if (Test-Path $profilePath) {
            cximport $Name | Out-Null
            $record = Get-CxRecord $Name
        }
    }

    if (!$record) {
        throw "没有找到 API/Profile：$Name"
    }

    if ([string]::IsNullOrWhiteSpace(
        $record.env_key
    )) {
        throw "$Name 没有配置 env_key。"
    }

    $key = Read-CxSecret "$Name API Key"

    Set-CxApiKeyValue `
        -EnvName $record.env_key `
        -Value $key

    Write-Host ""
    Write-Host "API Key 已保存。" `
        -ForegroundColor Green

    Write-Host "Environment Variable:"
    Write-Host "  $($record.env_key)"

    Write-Host ""
    Write-Host "当前 PowerShell 已立即生效。"
}


# ============================================================
# cx
#
# 新建对话
#
# cx official
# cx lumon
# cx lumon-other
# ============================================================

function cx {
    param(
        [Parameter(Position=0)]
        [string]$Name = "official",

        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$Rest
    )

    if (
        $Name -eq "official" -or
        $Name -eq "openai"
    ) {
        & codex @Rest
        return
    }

    $profile = Resolve-CxProfile $Name

    Sync-CxApiKeyToProcess $profile

    & codex -p $profile @Rest
}


# ============================================================
# cxr
#
# 恢复最近一次对话
# ============================================================

function cxr {
    param(
        [Parameter(Position=0)]
        [string]$Name = "official"
    )

    if (
        $Name -eq "official" -or
        $Name -eq "openai"
    ) {
        & codex resume --last
        return
    }

    $profile = Resolve-CxProfile $Name

    Sync-CxApiKeyToProcess $profile

    & codex `
        -p $profile `
        resume `
        --last
}


# ============================================================
# cxh
#
# 查看 / 选择历史对话
# ============================================================

function cxh {
    param(
        [Parameter(Position=0)]
        [string]$Name = "official"
    )

    if (
        $Name -eq "official" -or
        $Name -eq "openai"
    ) {
        & codex resume --all
        return
    }

    $profile = Resolve-CxProfile $Name

    Sync-CxApiKeyToProcess $profile

    & codex `
        -p $profile `
        resume `
        --all
}


# ============================================================
# cxlogin
# ============================================================

function cxlogin {
    param(
        [Parameter(Position=0)]
        [string]$Name = "official"
    )

    if (
        $Name -eq "official" -or
        $Name -eq "openai"
    ) {
        & codex login
        return
    }

    $record = Get-CxRecord $Name

    if (!$record) {
        $profilePath = Join-Path `
            $script:CxHome `
            "$Name.config.toml"

        if (Test-Path $profilePath) {
            cximport $Name | Out-Null
            $record = Get-CxRecord $Name
        }
    }

    if (!$record) {
        throw "找不到 API：$Name"
    }

    $value = ""

    if ($record.env_key) {
        $value = [Environment]::GetEnvironmentVariable(
            $record.env_key,
            "User"
        )
    }

    Write-Host ""
    Write-Host "Profile  : $($record.profile)"
    Write-Host "Provider : $($record.provider)"
    Write-Host "Base URL : $($record.base_url)"
    Write-Host "Env Key  : $($record.env_key)"
    Write-Host ""

    if ($value) {
        Write-Host "API Key：已配置" `
            -ForegroundColor Green
    }
    else {
        Write-Host "API Key：未配置" `
            -ForegroundColor Red

        Write-Host ""
        Write-Host "请运行："
        Write-Host "  cxsetkey $($record.profile)"
    }

    Write-Host ""
    Write-Host "启动："
    Write-Host "  cx $($record.profile)"
}


# ============================================================
# cxlist
# ============================================================

function cxlist {
    $rows = @()

    $rows += [pscustomobject]@{
        Name     = "OpenAI 官方"
        Profile  = "official"
        Provider = "openai"
        Model    = "主 config.toml"
        Launch   = "cx official"
        Resume   = "cxr official"
    }

    foreach ($p in @(Get-CxRegistry)) {

        if ($null -eq $p) {
            continue
        }

        $rows += [pscustomobject]@{
            Name     = $p.name
            Profile  = $p.profile
            Provider = $p.provider
            Model    = $p.model
            Launch   = $p.launch
            Resume   = $p.resume_last
        }
    }

    $rows |
        Format-Table `
            Name,
            Profile,
            Provider,
            Model,
            Launch,
            Resume `
            -AutoSize
}


# ============================================================
# cxtest
#
# 测试 API 的 /v1/models
# ============================================================

function cxtest {
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Name
    )

    $record = Get-CxRecord $Name

    if (!$record) {
        $profilePath = Join-Path `
            $script:CxHome `
            "$Name.config.toml"

        if (Test-Path $profilePath) {
            cximport $Name | Out-Null
            $record = Get-CxRecord $Name
        }
    }

    if (!$record) {
        throw "providers.json 中没有记录 $Name"
    }

    if ([string]::IsNullOrWhiteSpace(
        $record.base_url
    )) {
        throw "$Name 没有记录 Base URL。"
    }

    Sync-CxApiKeyToProcess $record.profile

    $key = Get-Item `
        -Path "Env:$($record.env_key)" `
        -ErrorAction SilentlyContinue

    if (!$key) {
        throw "没有读取到 $($record.env_key)"
    }

    $url =
        $record.base_url.TrimEnd('/') +
        "/models"

    Write-Host ""
    Write-Host "GET $url" `
        -ForegroundColor Cyan

    Invoke-RestMethod `
        -Uri $url `
        -Headers @{
            Authorization =
                "Bearer $($key.Value)"
        } `
        -Method Get
}


# ============================================================
# cxrepair
#
# 重建 providers.json
#
# 自动扫描：
# ~/.codex/*.config.toml
#
# 不修改 API Key
# 不删除对话
# 不修改 Codex sessions
# ============================================================

function cxrepair {

    Write-Host ""
    Write-Host "正在重建 Provider Registry..." `
        -ForegroundColor Cyan

    if (Test-Path $script:CxRegistry) {
        $backup =
            $script:CxRegistry +
            ".bak-" +
            (Get-Date -Format "yyyyMMdd-HHmmss")

        Copy-Item `
            $script:CxRegistry `
            $backup

        Write-Host "旧 Registry 已备份："
        Write-Host "  $backup"
    }

    Set-Content `
        -Path $script:CxRegistry `
        -Value "{}" `
        -Encoding UTF8

    $profiles = Get-ChildItem `
        -Path $script:CxHome `
        -Filter "*.config.toml" `
        -File `
        -ErrorAction SilentlyContinue

    $count = 0

    foreach ($file in $profiles) {

        $profile =
            $file.Name -replace '\.config\.toml$', ''

        try {
            cximport $profile | Out-Null

            Write-Host "✓ $profile" `
                -ForegroundColor Green

            $count++
        }
        catch {
            Write-Host "✗ $profile" `
                -ForegroundColor Yellow

            Write-Host "  $($_.Exception.Message)" `
                -ForegroundColor DarkYellow
        }
    }

    Write-Host ""
    Write-Host "Registry 重建完成，共导入 $count 个 Profile。" `
        -ForegroundColor Green

    Write-Host ""
    Write-Host "运行 cxlist 查看。"
}


# ============================================================
# cxinit
#
# 在当前项目创建跨 Provider 的共享上下文
# ============================================================

function cxinit {

    $root = ""

    try {
        $gitRoot = & git `
            rev-parse `
            --show-toplevel `
            2>$null

        if (
            $LASTEXITCODE -eq 0 -and
            $gitRoot
        ) {
            $root = $gitRoot.Trim()
        }
    }
    catch {
    }

    if ([string]::IsNullOrWhiteSpace(
        $root
    )) {
        $root = (Get-Location).Path
    }

    $sharedDir = Join-Path `
        $root `
        ".codex-shared"

    $context = Join-Path `
        $sharedDir `
        "CONTEXT.md"

    $agents = Join-Path `
        $root `
        "AGENTS.md"

    New-Item `
        -ItemType Directory `
        -Force `
        -Path $sharedDir |
        Out-Null

    if (!(Test-Path $context)) {

@"
# Shared Codex Context

> OpenAI 官方账号以及所有自定义 API Provider 共享的项目上下文。
> 不要在这里记录 API Key、Token、密码或其他秘密。

## 当前目标

待填写。

## 当前进度

待填写。

## 关键决策与约束

待填写。

## 已修改文件

待填写。

## 已执行命令 / 测试 / 结果

待填写。

## 尚未解决的问题

待填写。

## 下一步

待填写。

## Provider 交接记录

待填写。
"@ |
        Set-Content `
            -Path $context `
            -Encoding UTF8
    }

    $begin =
        "<!-- CODEX-MULTI-PROVIDER:BEGIN -->"

    $end =
        "<!-- CODEX-MULTI-PROVIDER:END -->"

    $agentsText = ""

    if (Test-Path $agents) {
        $agentsText = Get-Content `
            -Raw `
            -Encoding UTF8 `
            $agents
    }

    if (
        $agentsText -notmatch
        [regex]::Escape($begin)
    ) {

        $sharedInstruction = @"

$begin

## Multi-provider shared Codex context

本项目可能同时由 OpenAI 官方 ChatGPT 登录和多个 OpenAI-compatible Codex Provider 操作。

开始任何实质性工作前：

1. 读取 `.codex-shared/CONTEXT.md`。
2. 将其中内容视为跨 Provider 的当前项目状态与交接信息。

完成有意义的修改、测试、决策或准备结束当前会话前：

1. 更新 `.codex-shared/CONTEXT.md`。
2. 记录当前进度、关键决策、修改文件、测试结果、未解决问题和下一步。
3. 在 Provider 交接记录中注明本轮完成的工作。

不要把 API Key、Token、密码或其他秘密写入共享上下文。

不要只依赖当前 Provider 自己的聊天历史保存项目状态。

$end
"@

        Add-Content `
            -Path $agents `
            -Value $sharedInstruction `
            -Encoding UTF8
    }

    Write-Host ""
    Write-Host "共享 Codex 项目已初始化：" `
        -ForegroundColor Green

    Write-Host "  $root"

    Write-Host ""
    Write-Host "共享上下文："
    Write-Host "  $context"
}


# ============================================================
# 启动提示
# ============================================================

Write-Host `
    "Codex Provider Manager 已加载。" `
    -ForegroundColor DarkGray