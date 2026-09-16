# CXH Provider Manager

<p align="center">
  <b>为 OpenAI Codex CLI 提供多 Provider / 多 API Key / 多 Profile 管理能力</b>
</p>

<p align="center">
  <code>cx</code>
  ·
  <code>cxr</code>
  ·
  <code>cxh</code>
  ·
  <code>cxadd</code>
  ·
  <code>cxlist</code>
</p>

---

## 简介

**CXH Provider Manager** 是一个面向 Windows + PowerShell 的 Codex Provider 管理脚本。

它可以让同一台电脑同时保留：

- OpenAI / ChatGPT 官方 Codex 登录
- Lumon Code API
- 第二个 Lumon API Key
- 其他 OpenAI / Codex Responses API 兼容服务

无需反复修改 `config.toml`，也无需频繁覆盖 API Key。

例如：

```powershell
cx official
```

启动官方 OpenAI Codex。

```powershell
cx lumon
```

启动 Lumon Provider。

```powershell
cx lumon-other
```

启动第二个 Lumon Provider。

---

## 功能

### 多 Provider 管理

可以同时维护多个 Codex Provider：

```text
OpenAI Official
Lumon
Lumon Other
API 3
API 4
...
```

每个 Provider 都拥有独立的：

- API Key
- Base URL
- Model
- Reasoning Effort
- Service Tier
- Codex Profile

---

### API Key 安全存储

API Key 不需要直接写入：

```text
config.toml
```

而是保存到 Windows User Environment Variables。

例如：

```text
CODEX_LUMON_OTHER_API_KEY
```

Codex Provider 只保存对应的环境变量名称。

---

### 一条命令新增 API

例如增加另一个 Lumon API：

```powershell
cxadd lumon-other https://www.lumoncode.com/v1 gpt-6-astra
```

随后输入 API Key。

管理器会自动完成：

```text
创建环境变量
        ↓
注册 model_provider
        ↓
创建 Codex Profile
        ↓
登记 Provider
        ↓
生成启动命令
```

之后直接：

```powershell
cx lumon-other
```

---

## 命令

### 查看所有 Provider

```powershell
cxlist
```

示例：

```text
Name          Profile       Provider       Model
----          -------       --------       -----
OpenAI 官方   official      openai         config.toml
lumon         lumon         lumoncode      gpt-6-astra
lumon-other   lumon-other   lumon-other    gpt-6-astra
```

---

### 启动 Provider

官方账号：

```powershell
cx official
```

Lumon：

```powershell
cx lumon
```

其他 Provider：

```powershell
cx lumon-other
```

---

### 继续最近一次对话

```powershell
cxr official
```

```powershell
cxr lumon
```

```powershell
cxr lumon-other
```

---

### 查看历史对话

```powershell
cxh official
```

```powershell
cxh lumon
```

```powershell
cxh lumon-other
```

---

### 新增 Provider

格式：

```powershell
cxadd <名称> <Base URL> <模型>
```

例如：

```powershell
cxadd lumon-other https://www.lumoncode.com/v1 gpt-6-astra
```

随后按照提示输入 API Key。

---

### 设置或更换 API Key

```powershell
cxsetkey lumon-other
```

API Key 会保存到 Windows 当前用户环境变量。

---

### 测试 Provider

```powershell
cxtest lumon-other
```

管理器会测试：

```text
GET /v1/models
```

用于检查：

- API Key
- Base URL
- Provider 是否可访问
- 模型列表

---

### 修复 Provider Registry

如果 `cxlist` 显示异常：

```powershell
cxrepair
```

管理器会重新扫描：

```text
~/.codex/*.config.toml
```

并重建 Provider Registry。

---

## 多 Provider 项目共享

进入项目目录：

```powershell
cd E:\your-project
```

执行：

```powershell
cxinit
```

管理器会创建：

```text
your-project/
├─ AGENTS.md
└─ .codex-shared/
   └─ CONTEXT.md
```

不同 Provider 可以通过：

```text
.codex-shared/CONTEXT.md
```

共享：

- 当前目标
- 当前进度
- 关键决策
- 已修改文件
- 测试结果
- 未解决问题
- 下一步工作

这可以避免在：

```text
OpenAI
Lumon
其他 API
```

之间切换时完全丢失项目上下文。

> 注意：不同 Provider 的 Codex Thread 本身仍然可能是独立的。  
> CXH 使用共享项目上下文实现跨 Provider 工作交接。

---

# 安装

## 环境要求

推荐：

```text
Windows 10 / Windows 11
PowerShell 7+
OpenAI Codex CLI
Git
```

检查 PowerShell：

```powershell
$PSVersionTable.PSVersion
```

推荐：

```text
7.x
```

---

## 方法一：手动安装

克隆仓库：

```powershell
git clone https://github.com/V1rnn4r/CXH-ProviderManager.git
```

进入目录：

```powershell
cd CXH-ProviderManager
```

复制管理器：

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.codex" | Out-Null

Copy-Item `
    ".\CodexProviderManager.ps1" `
    "$env:USERPROFILE\.codex\CodexProviderManager.ps1" `
    -Force
```

然后在 PowerShell 7 Profile 中加入：

```powershell
. "$env:USERPROFILE\.codex\CodexProviderManager.ps1"
```

推荐写入：

```powershell
$PROFILE.CurrentUserAllHosts
```

---

## PowerShell 自动加载

PowerShell 7 的 CurrentUserAllHosts Profile 通常位于：

```text
C:\Users\<username>\Documents\PowerShell\profile.ps1
```

其中加入：

```powershell
$codexManager = "$env:USERPROFILE\.codex\CodexProviderManager.ps1"

if (Test-Path $codexManager) {
    . $codexManager
}
```

以后无论当前目录位于：

```text
C:\
D:\
E:\
F:\
```

都可以直接运行：

```powershell
cxlist
```

---

# 推荐工作流

例如同时拥有：

```text
OpenAI 官方账号
Lumon API 1
Lumon API 2
```

可以直接：

```powershell
cx official
```

```powershell
cx lumon
```

```powershell
cx lumon-other
```

切换 Provider 不需要覆盖其他 Provider 的配置。

---

## 示例：Lumon Code

Base URL：

```text
https://www.lumoncode.com/v1
```

新增：

```powershell
cxadd lumon https://www.lumoncode.com/v1 gpt-6-astra
```

启动：

```powershell
cx lumon
```

恢复：

```powershell
cxr lumon
```

历史：

```powershell
cxh lumon
```

---

# 配置位置

CXH 默认使用：

```text
C:\Users\<username>\.codex
```

例如：

```text
.codex/
├─ config.toml
├─ CodexProviderManager.ps1
├─ providers.json
├─ lumon.config.toml
├─ lumon-other.config.toml
└─ ...
```

---

# 安全说明

不要提交以下内容到 Git：

```text
API Key
auth.json
cap_sid
providers.json
sessions/
archived_sessions/
state_*.sqlite
```

API Key 建议保存在：

```text
Windows User Environment Variables
```

而不是写死在代码中。

---

# 常见问题

## `cx` 无法识别

如果出现：

```text
cx: The term 'cx' is not recognized
```

先检查：

```powershell
Test-Path "$env:USERPROFILE\.codex\CodexProviderManager.ps1"
```

然后：

```powershell
. "$env:USERPROFILE\.codex\CodexProviderManager.ps1"
```

如果手动加载成功，则检查：

```powershell
$PROFILE.CurrentUserAllHosts
```

确保 PowerShell Profile 中包含：

```powershell
. "$env:USERPROFILE\.codex\CodexProviderManager.ps1"
```

---

## Missing environment variable

例如：

```text
Missing environment variable: CODEX_LUMON_OTHER_API_KEY
```

执行：

```powershell
cxsetkey lumon-other
```

然后重新：

```powershell
cx lumon-other
```

---

## 查看当前 PowerShell 版本

```powershell
$PSVersionTable.PSVersion
```

推荐 PowerShell 7+。

---

# Roadmap

计划增加：

- [ ] 一键 `install.ps1`
- [ ] 一键 `uninstall.ps1`
- [ ] Provider 编辑命令
- [ ] Provider 删除命令
- [ ] API Key 状态检查
- [ ] Provider 健康检查
- [ ] Codex Session 备份
- [ ] Codex Session 恢复
- [ ] 多电脑同步工具
- [ ] 自动更新 CXH
- [ ] GitHub Release 安装
- [ ] Windows 安装脚本

---

# License

推荐使用 MIT License。

---

## Author

**V1rnn4r**

GitHub:

```text
https://github.com/V1rnn4r
```

---

<p align="center">
  <b>CXH Provider Manager</b><br>
  Manage multiple Codex providers without repeatedly rewriting your configuration.
</p>