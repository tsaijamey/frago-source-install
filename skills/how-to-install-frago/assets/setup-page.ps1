# setup-page.ps1 — Windows 版:探测这台机器,把结果嵌进向导页模板,生成一张只属于这台机器的页面。
#
#   powershell -ExecutionPolicy Bypass -File assets\setup-page.ps1              # 生成页面,打印路径
#   powershell -ExecutionPolicy Bypass -File assets\setup-page.ps1 -Json        # 只打印探测结果
#   powershell -ExecutionPolicy Bypass -File assets\setup-page.ps1 -Out PATH    # 指定生成到哪
#
# 检测规则与 setup-page.sh 对齐;差别只在 Windows 没有原生 tmux。

param(
  [switch]$Json,
  [string]$Out = (Join-Path $env:TEMP "frago-setup\index.html")
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$template = Join-Path $here "frago-setup-intro.html"

function Has($name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }

# WorkBuddy 的命令行藏在桌面应用包里,PATH 上通常没有它,所以除了按命令找,还要看应用包。
# 包内的相对位置与 macOS 同形,差别只在应用装在哪。这几条按 Windows 桌面应用的常规落点
# 写,没有实机验证过——探不到时跟补这几条之前一样报「没装」,不会更糟。
function HasCodebuddy {
  if (Has "codebuddy") { return $true }
  # 环境变量缺一个就让整份脚本报错不值得,所以先筛掉空的再拼路径。
  $bases = @($env:LOCALAPPDATA, $env:ProgramFiles) | Where-Object { $_ }
  foreach ($b in $bases) {
    $roots = @(
      "$b\Programs\WorkBuddy\resources\app.asar.unpacked\cli\bin",
      "$b\WorkBuddy\resources\app.asar.unpacked\cli\bin"
    )
    foreach ($r in $roots) {
      foreach ($n in @("codebuddy.cmd", "codebuddy.exe", "codebuddy")) {
        if (Test-Path "$r\$n") { return $true }
      }
    }
  }
  return $false
}

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
  @{ id="codebuddy"; name="WorkBuddy";   ok=(HasCodebuddy);    how="WorkBuddy 是桌面应用,从官网下载"; how_en="WorkBuddy is a desktop app; download it from its website"; manual=$true }
)

# ── 依赖 ──
$uvOk = (Has "uv") -or (Test-Path (Join-Path $env:USERPROFILE ".local\bin\uv.exe"))
$tools = @(
  @{ id="git";    name="git";              ok=(Has "git");    required=$true;  how="winget install Git.Git"; how_en="winget install Git.Git" }
  @{ id="uv";     name="uv";               ok=$uvOk;          required=$true;  how="官方安装脚本(PowerShell)"; how_en="official install script (PowerShell)" }
  @{ id="tmux";   name="tmux";             ok=(Has "tmux");   required=$false; how="Windows 没有原生 tmux,派活要进 WSL;这一项 agent 装不了"; how_en="no native tmux on Windows; delegation needs WSL, the agent cannot install this" }
  @{ id="browser"; name="浏览器（frago 自带）"; ok=(Test-Path "$HOME\.frago\tools\chrome-for-testing"); required=$false; how="装的时候由 frago 取,不用你动手"; how_en="fetched by frago during install; nothing for you to do" }
  @{ id="ffmpeg"; name="ffmpeg";           ok=(Has "ffmpeg"); required=$false; how="winget install ffmpeg"; how_en="winget install ffmpeg" }
  @{ id="gh";     name="GitHub CLI (gh)";  ok=(Has "gh");     required=$false; how="winget install GitHub.cli"; how_en="winget install GitHub.cli" }
)

$probe = @{ os="windows"; running=$running; agents=$agents; tools=$tools }
$json = $probe | ConvertTo-Json -Depth 5 -Compress

if ($Json) { Write-Output $json; exit 0 }

if (-not (Test-Path $template)) { Write-Error "template not found: $template"; exit 1 }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Out) | Out-Null
$html = Get-Content -Raw -Encoding UTF8 $template
$html = $html.Replace("/*__PROBE__*/null", $json)
[IO.File]::WriteAllText($Out, $html, (New-Object Text.UTF8Encoding $false))
Write-Output $Out
