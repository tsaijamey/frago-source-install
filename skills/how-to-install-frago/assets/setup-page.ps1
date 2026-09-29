# 本文件 MUST 以 UTF-8 BOM 保存。Windows PowerShell 5.1(`powershell.exe`,这正是本
# skill 让 agent 用的那一个)在非 UTF-8 区域设置的机器上把无 BOM 的 .ps1 当 ANSI 读,
# 中文全部烂掉、脚本当场解析失败——中文 Windows 上实测:skill 第一步就死在这里。
# setup-page.ps1 — Windows 版:探测这台机器,把结果嵌进向导页模板,生成一张只属于这台机器的页面。
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File assets\setup-page.ps1              # 生成页面,打印路径
#   powershell -NoProfile -ExecutionPolicy Bypass -File assets\setup-page.ps1 -Json        # 只打印探测结果
#   powershell -NoProfile -ExecutionPolicy Bypass -File assets\setup-page.ps1 -Out PATH    # 指定生成到哪
#
# 检测规则与 setup-page.sh 对齐;差别只在 Windows 的 tmux 是第三方 win32 移植版。

param(
  [switch]$Json,
  [string]$Out = (Join-Path $env:TEMP "frago-setup\index.html")
)

# 控制台按系统 ANSI 代码页写 stdout,--json 那条路上的中文会在非 UTF-8 机器上变乱码,
# 调用方拿到的 JSON 里全是问号。生成的页面不受影响(那是按 UTF-8 直接写文件的)。
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$template = Join-Path $here "frago-setup-intro.html"

function Has($name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }

# winget 装完会改用户级 PATH,但**当前进程拿不到**——agent 在同一个 shell 里接着跑,
# 敲什么都是"找不到命令",看着像装失败。所以探测一律从注册表重读一次 PATH。
function Sync-PathFromRegistry {
  $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
  $user    = [Environment]::GetEnvironmentVariable("Path", "User")
  $env:Path = "$machine;$user"
}
Sync-PathFromRegistry

# ── 谁在跑这个脚本:顺着父进程链往上找 agent 命令行 ──
$running = ""
$p = $PID
for ($i = 0; $i -lt 10 -and $p; $i++) {
  $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$p" -ErrorAction SilentlyContinue
  if (-not $proc) { break }
  $n = $proc.Name.ToLower()
  if ($n -like "claude*")    { $running = "claude"; break }
  if ($n -like "codex*")     { $running = "codex"; break }
  if ($n -like "opencode*")  { $running = "opencode"; break }
  if ($n -like "codebuddy*" -or $n -like "workbuddy*") { $running = "codebuddy"; break }
  $p = $proc.ParentProcessId
}
if (-not $running -and $env:CLAUDECODE -eq "1") { $running = "claude" }

# ── agent 命令行 ──
$agents = @(
  @{ id="claude";    name="Claude Code"; ok=(Has "claude");    how="官方安装脚本(PowerShell)"; how_en="official install script (PowerShell)"; manual=$false }
  @{ id="codex";     name="codex";       ok=(Has "codex");     how="需要 Node.js,自己装好后再跑一次这份 skill 就能接上"; how_en="needs Node.js; install it yourself, then run this skill again"; manual=$true }
  @{ id="opencode";  name="opencode";    ok=(Has "opencode");  how="官方安装脚本(PowerShell)"; how_en="official install script (PowerShell)"; manual=$false }
  @{ id="codebuddy"; name="WorkBuddy";   ok=(Has "codebuddy"); how="WorkBuddy 是桌面应用,从官网下载"; how_en="WorkBuddy is a desktop app; download it from its website"; manual=$true }
)

# ── 依赖 ──
$uvOk = (Has "uv") -or (Test-Path (Join-Path $env:USERPROFILE ".local\bin\uv.exe"))
$tools = @(
  @{ id="git";    name="git";              ok=(Has "git");    required=$true;  how="winget install Git.Git"; how_en="winget install Git.Git" }
  @{ id="uv";     name="uv";               ok=$uvOk;          required=$true;  how="官方安装脚本(PowerShell)"; how_en="official install script (PowerShell)" }
  @{ id="tmux";   name="tmux";             ok=(Has "tmux");   required=$false; how="winget install arndawg.tmux-windows(Windows 版 tmux,frago 已适配它的脾气)"; how_en="winget install arndawg.tmux-windows (the Windows build of tmux; frago already works around its quirks)" }
  @{ id="browser"; name="浏览器（frago 自带）"; ok=(Test-Path "$HOME\.frago\tools\chrome-for-testing"); required=$false; how="装的时候由 frago 取,不用你动手"; how_en="fetched by frago during install; nothing for you to do" }
  @{ id="ffmpeg"; name="ffmpeg";           ok=(Has "ffmpeg"); required=$false; how="winget install ffmpeg"; how_en="winget install ffmpeg" }
  @{ id="gh";     name="GitHub CLI (gh)";  ok=(Has "gh");     required=$false; how="winget install GitHub.cli"; how_en="winget install GitHub.cli" }
)

$probe = @{ os="windows"; running=$running; agents=$agents; tools=$tools }
# NEVER 把这个变量叫 $json：PowerShell 的变量名不分大小写，它与上面 param 里的
# [switch]$Json 是同一个变量，赋一段字符串进去当场抛「无法将 String 转换为
# SwitchParameter」。这一行无条件执行，所以撞上了就是两种模式一起死。
$payload = $probe | ConvertTo-Json -Depth 5 -Compress

if ($Json) { Write-Output $payload; exit 0 }

if (-not (Test-Path $template)) { Write-Error "template not found: $template"; exit 1 }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Out) | Out-Null
$html = Get-Content -Raw -Encoding UTF8 $template
$html = $html.Replace("/*__PROBE__*/null", $payload)
[IO.File]::WriteAllText($Out, $html, (New-Object Text.UTF8Encoding $false))
Write-Output $Out
