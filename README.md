# CXH Provider Manager

<p align="center">
  <b>Windows + PowerShell 下的 OpenAI Codex CLI 多 Provider / 多 API Key / 多 Profile 管理器</b>
</p>

<p align="center">
  <code>cx</code> ·
  <code>cxr</code> ·
  <code>cxh</code> ·
  <code>cxadd</code> ·
  <code>cximport</code> ·
  <code>cxsetkey</code> ·
  <code>cxlogin</code> ·
  <code>cxlist</code> ·
  <code>cxtest</code> ·
  <code>cxrepair</code> ·
  <code>cxinit</code>
</p>

---

## 1. 这个项目解决什么问题

CXH Provider Manager 用来在同一台 Windows 电脑上保留并快速切换：

- OpenAI / ChatGPT 官方 Codex 登录
- Lumon Code 等 OpenAI/Codex Responses API 兼容 Provider
- 同一 Provider 的多个 API Key / Profile
- 不同模型、Reasoning Effort、Service Tier 配置
- 不同 Provider 之间的项目级共享上下文

不需要为了切换 Provider 反复手改 `~/.codex/config.toml`，也不需要把 API Key 明文写进脚本。

---

## 2. 环境要求

推荐环境：

```text
Windows 10 / Windows 11
PowerShell 7+
OpenAI Codex CLI
Git
```

仓库中的 PowerShell 脚本使用 **UTF-8 with BOM** 保存，以兼容 Windows PowerShell 5.1 对含中文脚本的解析。推荐日常使用 PowerShell 7（`pwsh`），但安装器和管理器也尽量保持 Windows PowerShell 5.1 可解析。

检查 PowerShell：

```powershell
$PSVersionTable.PSVersion
```

检查 Codex：

```powershell
codex --version
```

检查当前用户所有 Host 共用的 PowerShell Profile：

```powershell
$PROFILE.CurrentUserAllHosts
```

> 不要依赖固定的 Profile 路径。不同 PowerShell/用户环境下实际路径可能不同，CXH 安装器直接使用 `$PROFILE.CurrentUserAllHosts`。

---


## 3. 安装目录与下载脚本

CXH 现在支持三个目录分别指定，而且都可以位于 C / D / E 等任意本地磁盘：

```text
1. Git 仓库源码目录
   例如：
   E:\project\cxh

2. Codex 数据目录（CODEX_HOME）
   保存：
   config.toml
   *.config.toml
   providers.json
   auth.json
   sessions/
   以及 Codex 本地状态

3. CXH 管理器脚本目录
   保存：
   CodexProviderManager.ps1
```

例如可以这样组织：

```text
E:\project\cxh              # GitHub 仓库
D:\CodexData                 # Codex 数据 / CODEX_HOME
E:\Tools\CXH                # CXH 管理器脚本
```

如果不特别指定：

- Codex 数据目录优先使用当前/当前用户已有的 `CODEX_HOME`
- 如果没有配置 `CODEX_HOME`，才回退到 `%USERPROFILE%\.codex`
- CXH 管理器默认安装到 Codex 数据目录

### 推荐：下载并交互式选择目录

仓库中提供：

```text
download-install.ps1
```

第一次运行时，如果没有传参数，会依次询问：

```text
1/3 Git 仓库源码目录
2/3 Codex 数据目录
3/3 CXH 管理器安装目录
```

例如：

```powershell
pwsh -File .\download-install.ps1
```

也可以完全不询问，直接指定：

```powershell
pwsh -File .\download-install.ps1 `
  -SourceDir "E:\project\cxh" `
  -CodexHome "D:\CodexData" `
  -ManagerInstallDir "E:\Tools\CXH"
```

如果仓库已经存在，下载脚本会执行：

```text
git pull --ff-only
```

如果不存在，则执行：

```text
git clone
```

### 从 GitHub 直接下载安装脚本

上传本版本到 GitHub 后，新电脑可以直接执行：

```powershell
$script="$env:TEMP\cxh-download-install.ps1"; Invoke-WebRequest "https://raw.githubusercontent.com/V1rnn4r/CXH-ProviderManager/main/download-install.ps1" -OutFile $script; pwsh -File $script
```

这样不需要先手工 `git clone`。脚本会自己询问三个目录，并完成下载与安装。

如果新电脑已经有 Codex 数据目录，例如：

```text
D:\CodexData
```

在第 2 步直接填写这个现有目录即可。安装器不会迁移、删除或重建已有 Session，只会让 Codex CLI 与 CXH 使用同一个 `CODEX_HOME`。

---

## 4. 一键安装

克隆仓库：

```powershell
git clone https://github.com/V1rnn4r/CXH-ProviderManager.git
cd CXH-ProviderManager
```

最简单安装：

```powershell
pwsh -File .\install.ps1
```

如果电脑已经配置 `CODEX_HOME`，安装器会优先使用它；如果没有，才使用：

```text
%USERPROFILE%\.codex
```

同时指定 Codex 数据目录与 CXH 管理器目录：

```powershell
pwsh -File .\install.ps1 `
  -CodexHome "D:\CodexData" `
  -ManagerInstallDir "E:\Tools\CXH"
```

当显式传入 `-CodexHome` 时，安装器会：

1. 将 `CODEX_HOME` 写入 Windows 当前用户环境变量
2. 同步到当前 PowerShell 会话
3. 在 PowerShell Profile 中写入相同目录
4. 让 CXH 从这个目录读取 Provider 配置、Registry 和 Session
5. 备份已有的 `CodexProviderManager.ps1`
6. 复制并执行 SHA256 校验
7. 检查全部公开命令是否加载成功

PowerShell Profile 会记录实际的管理器路径，所以 `CodexProviderManager.ps1` 不要求放在 C 盘。

安装后重新打开 PowerShell，应看到：

```text
Codex Provider Manager 已加载。
```

---

## 5. 核心命令

| 命令 | 作用 |
|---|---|
| `cx [profile]` | 启动 Codex；默认官方账号 |
| `cxr [profile]` | 恢复该 Profile 最近一次对话 |
| `cxh [profile]` | 打开历史会话选择器 |
| `cxadd ...` | 新建自定义 Provider/Profile |
| `cximport <profile>` | 把已有 `*.config.toml` Profile 导入 CXH Registry |
| `cxsetkey <profile>` | 设置/更换 API Key |
| `cxlogin [profile]` | 官方账号执行 `codex login`；自定义 Provider 显示认证状态 |
| `cxlist` | 查看已登记 Provider |
| `cxtest <profile>` | 请求 Provider 的 `/models` |
| `cxrepair` | 扫描 `~/.codex/*.config.toml` 重建 Registry |
| `cxinit` | 为当前项目初始化跨 Provider 共享上下文 |

---

## 6. 启动与恢复会话

### OpenAI 官方

新建/进入 Codex：

```powershell
cx
```

等价于：

```powershell
cx official
```

恢复最近一次：

```powershell
cxr
```

历史会话选择器：

```powershell
cxh
```

也可以显式写：

```powershell
cxr official
cxh official
```

### 自定义 Provider

例如：

```powershell
cx lumon
cxr lumon
cxh lumon
```

或者：

```powershell
cx lumon-other
cxr lumon-other
cxh lumon-other
```

`cxr` 当前调用：

```text
codex resume --last
```

`cxh` 当前调用：

```text
codex resume --all
```

所以 `cxh` 会进入 Codex 的历史会话选择流程，而不是直接固定恢复某一个 Session ID。

---

## 7. Windows 管理员终端兼容

当前管理器包含 Windows 管理员终端兼容逻辑。

在管理员 PowerShell 中运行普通 `cx` / `cxr` / `cxh` 时，会自动加入：

```text
--no-daemon
```

这样可兼容 Codex CLI 中管理员终端无法启动 shared daemon 的场景。

管理器也会过滤 PowerShell 参数数组里的 `null` / 空字符串，避免 `resume` 把空参数误识别为 Session ID。

如果命令参数包含：

```text
--remote
```

或：

```text
agents
```

CXH **不会**自动加入 `--no-daemon`，因为这些模式依赖 shared server。

这类功能建议直接在**非管理员 PowerShell**中使用。

---

## 8. 新增 Provider

格式：

```powershell
cxadd <名称> <Base URL> <模型> [-Reasoning <等级>] [-ServiceTier <等级>]
```

最简单的例子：

```powershell
cxadd lumon https://www.lumoncode.com/v1 gpt-6-astra
```

随后根据提示输入 API Key。输入内容不会显示。

当前默认值：

```text
Model          = gpt-6-astra
Reasoning      = xhigh
Service Tier   = default
```

也可以显式指定：

```powershell
cxadd lumon-other https://www.lumoncode.com/v1 gpt-6-astra -Reasoning high -ServiceTier default
```

管理器会自动：

```text
保存 API Key 到 Windows 当前用户环境变量
        ↓
写入主 config.toml 的 model_providers
        ↓
创建 <profile>.config.toml
        ↓
更新 providers.json
        ↓
生成 cx / cxr / cxh 使用入口
```

例如 `lumon-other` 的 API Key 环境变量会类似：

```text
CODEX_LUMON_OTHER_API_KEY
```

---

## 9. 重要：新建 Profile 的权限策略

当前 `cxadd` 自动创建的 Profile 中包含：

```toml
approval_policy = "never"
sandbox_mode = "danger-full-access"
```

这意味着该 Profile 默认：

- 不逐次询问操作批准
- 使用高权限/宽松沙箱模式

这是当前 CXH 的设计选择，适合你明确希望 Codex 直接执行工作的环境。

**不要在不受信任的仓库、脚本或代码目录中随意使用这类 Profile。**

如果你希望更严格的权限策略，请手动修改对应：

```text
~/.codex/<profile>.config.toml
```

---

## 10. API Key 存储

CXH 不把自定义 Provider 的 API Key 明文写进：

```text
config.toml
```

而是保存到 Windows 当前用户环境变量。

设置或更换：

```powershell
cxsetkey lumon-other
```

如果启动时提示缺少环境变量，直接重新执行对应的 `cxsetkey`。

当前 PowerShell 会话会立即同步新值，不需要为了 Key 变更重新启动终端。

---

## 11. 导入已有 Profile

如果 `~/.codex/` 中已经存在：

```text
lumon.config.toml
lumon-other.config.toml
```

并且主：

```text
~/.codex/config.toml
```

中已经有对应：

```toml
[model_providers.xxx]
```

不要重复 `cxadd`。

使用：

```powershell
cximport lumon
```

或：

```powershell
cximport lumon-other
```

然后检查：

```powershell
cxlist
```

---

## 12. 登录状态

官方账号：

```powershell
cxlogin official
```

会直接执行：

```text
codex login
```

对于自定义 API Provider：

```powershell
cxlogin lumon
```

CXH 会显示：

- Profile
- Provider
- Base URL
- API Key 环境变量名
- API Key 是否已经配置

自定义 Provider 的认证仍由其 API Key 完成。

---

## 13. 查看 Provider

```powershell
cxlist
```

示例结构：

```text
Name          Profile       Provider       Model          Launch            Resume
----          -------       --------       -----          ------            ------
OpenAI 官方   official      openai         主 config.toml cx official       cxr official
lumon         lumon         lumon          gpt-6-astra    cx lumon          cxr lumon
lumon-other   lumon-other   lumon-other    gpt-6-astra    cx lumon-other    cxr lumon-other
```

---

## 14. 测试 Provider

```powershell
cxtest lumon-other
```

CXH 会请求：

```text
<Base URL>/models
```

并使用对应 Windows 用户环境变量里的 API Key 发送 Bearer 认证。

这个测试可以帮助确认：

- Base URL 是否可访问
- API Key 是否有效
- `/models` 是否受支持

> `/models` 成功并不必然代表 Provider 的 `/responses` 一定可用；如果实际 Codex 请求失败，还需要结合 Provider 对 Responses API 的支持情况判断。

---

## 15. Registry 修复

CXH Registry：

```text
~/.codex/providers.json
```

如果 `cxlist` 缺项或 Registry 损坏：

```powershell
cxrepair
```

它会：

1. 备份现有 `providers.json`
2. 重置 Registry
3. 扫描：

```text
~/.codex/*.config.toml
```

4. 逐个执行导入

它不会主动删除 API Key、Session 或 Codex 历史。

---

## 16. 跨 Provider 项目共享

在项目目录执行：

```powershell
cxinit
```

如果当前目录位于 Git 仓库中，CXH 会优先使用 Git 仓库根目录。

随后创建：

```text
<project>/
├─ AGENTS.md
└─ .codex-shared/
   └─ CONTEXT.md
```

并在 `AGENTS.md` 中加入受标记管理的说明，要求不同 Provider：

- 开始工作前读取 `.codex-shared/CONTEXT.md`
- 结束重要工作前更新共享上下文
- 记录进度、决策、修改文件、测试结果和下一步
- 不把 API Key、Token、密码等秘密写入共享文件

这样 OpenAI 官方和自定义 Provider 可以通过项目文件进行工作交接。

> 不同 Provider 的 Codex Thread / Session 本身仍可能相互独立；CXH 的 `cxinit` 解决的是项目状态交接，而不是合并服务端会话历史。

---

## 17. 配置位置

Codex 数据目录由 `CODEX_HOME` 决定。

CXH 的查找顺序：

```text
当前 PowerShell 的 CODEX_HOME
        ↓
Windows 当前用户保存的 CODEX_HOME
        ↓
%USERPROFILE%\.codex
```

查看当前会话：

```powershell
$env:CODEX_HOME
```

查看当前用户持久化值：

```powershell
[Environment]::GetEnvironmentVariable("CODEX_HOME","User")
```

典型 Codex 数据目录结构：

```text
D:\CodexData\
├─ config.toml
├─ providers.json
├─ lumon.config.toml
├─ lumon-other.config.toml
├─ auth.json
├─ sessions/
└─ ...
```

`CodexProviderManager.ps1` 可以和这些数据放在一起，也可以单独放在其他目录。

CXH 仓库本身只应该保存管理器源码、安装器和文档。

---

## 18. 更新 CXH

在仓库目录：

```powershell
git pull
pwsh -File .\install.ps1
```

如果使用自定义目录：

```powershell
pwsh -File .\install.ps1 `
  -CodexHome "D:\CodexData" `
  -ManagerInstallDir "E:\Tools\CXH"
```

安装器会先备份目标位置现有的 `CodexProviderManager.ps1`，再复制仓库中的新版本并做 SHA256 校验。

推荐流程：

```text
GitHub 仓库
    ↓ git pull
本地 CXH 源码
    ↓ install.ps1
指定的 CXH 管理器目录
```

Codex 的配置与 Session 则继续保留在指定的 `CODEX_HOME`。

---

## 19. 在另一台电脑安装

新电脑准备：

```text
Git
PowerShell 7
OpenAI Codex CLI
```

### 推荐方法：直接运行下载脚本

```powershell
$script="$env:TEMP\cxh-download-install.ps1"; Invoke-WebRequest "https://raw.githubusercontent.com/V1rnn4r/CXH-ProviderManager/main/download-install.ps1" -OutFile $script; pwsh -File $script
```

随后按提示选择：

```text
1/3 Git 仓库源码目录
2/3 Codex 数据目录
3/3 CXH 管理器安装目录
```

如果新电脑现有 Codex 数据已经在：

```text
D:\CodexData
```

那么第 2 步直接填写：

```text
D:\CodexData
```

即可继续使用已有配置和 Session。

也可以手工克隆后安装：

```powershell
git clone https://github.com/V1rnn4r/CXH-ProviderManager.git
cd CXH-ProviderManager
pwsh -File .\install.ps1 -CodexHome "D:\CodexData" -ManagerInstallDir "E:\Tools\CXH"
```

需要注意：

- API Key 不应提交到 Git
- Windows 用户环境变量不会自动随 Git 同步
- 官方 `auth.json` 不应提交
- 如果新电脑已有 API Key 环境变量和 `auth.json`，可直接沿用
- 如果没有，则重新执行 `cxsetkey <profile>` / `cxlogin official`

---

## 20. 安全说明

不要提交到 Git：

```text
API Key
.env
auth.json
cap_sid
providers.json
sessions/
archived_sessions/
state_*.sqlite
```

项目 `.gitignore` 已覆盖常见本地秘密、Codex Runtime、数据库、日志和备份文件。

提交前建议检查：

```powershell
git status
git diff --cached
```

---

## 21. 常见问题

### `cx` 无法识别

检查管理器：

```powershell
Test-Path "$env:USERPROFILE\.codex\CodexProviderManager.ps1"
```

手动加载：

```powershell
. "$env:USERPROFILE\.codex\CodexProviderManager.ps1"
```

检查实际 Profile：

```powershell
$PROFILE.CurrentUserAllHosts
```

查看内容：

```powershell
Get-Content $PROFILE.CurrentUserAllHosts
```

---

### `cxh` 没有出现历史会话选择

先直接测试原生命令：

```powershell
codex --no-daemon resume --all
```

如果原生命令能正常显示会话选择，再运行：

```powershell
cxh official
```

管理员终端下 CXH 会自动补 `--no-daemon`。

---

### Missing environment variable

例如：

```text
Missing environment variable: CODEX_LUMON_OTHER_API_KEY
```

执行：

```powershell
cxsetkey lumon-other
```

然后：

```powershell
cx lumon-other
```

---

### `providers.json` 显示异常

```powershell
cxrepair
cxlist
```

---

### `--remote` / `agents` 在管理员终端异常

这些模式依赖 shared server，CXH 不会给它们强制加入 `--no-daemon`。

建议关闭管理员终端，在普通 PowerShell 7 中运行。

---

## 22. Roadmap

已完成：

- [x] 多 Provider / 多 Profile
- [x] Windows 用户环境变量保存 API Key
- [x] `cx / cxr / cxh`
- [x] `cxadd / cximport / cxsetkey`
- [x] `cxlogin / cxlist / cxtest / cxrepair`
- [x] 跨 Provider 项目共享上下文 `cxinit`
- [x] 管理员终端 `--no-daemon` 兼容
- [x] 一键 `install.ps1`
- [x] 安装前自动备份
- [x] PowerShell Profile 自动加载

可继续增加：

- [ ] Provider 编辑命令
- [ ] Provider 删除命令
- [ ] 一键卸载
- [ ] Provider 更完整的健康检查
- [ ] Session 备份 / 恢复工具
- [ ] 多电脑配置同步
- [ ] 自动更新 / GitHub Release 安装

---

## PowerShell 使用建议

CXH 现在默认以 **PowerShell 7 (`pwsh`)** 作为安装与日常使用环境。

- Windows 自带的 **Windows PowerShell 5.1** 是系统兼容组件，不建议强行卸载。
- 如果误用 Windows PowerShell 5.1 运行安装脚本，脚本会自动切换到已安装的 PowerShell 7。
- 安装器只会配置 PowerShell 7 当前用户 Profile，不会主动给 Windows PowerShell 5.1 添加新的 CXH Loader。
- CXH 启动成功后默认静默加载，不再显示 `Codex Provider Manager 已加载。`。
- 安装器每次运行都会先清理旧版和重复的 CXH Loader，再只保留一个受管理 Loader。

如果你使用 Windows Terminal，建议在：

```text
设置 → 启动 → 默认配置文件
```

选择 **PowerShell（pwsh / PowerShell 7）**，避免日常误打开旧的 Windows PowerShell 5.1。

---

## License

MIT License

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
