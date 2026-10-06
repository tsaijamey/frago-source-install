#!/usr/bin/env bash
# setup-page.sh — 探测这台机器,把结果嵌进向导页模板,生成一张只属于这台机器的页面。
#
#   assets/setup-page.sh              # 生成页面,打印生成后的路径
#   assets/setup-page.sh --json       # 只打印探测结果,不生成页面
#   assets/setup-page.sh --out PATH   # 指定生成到哪
#
# 装机的 agent 只需要跑它。检测规则全在这里,agent 不用自己判断;页面上每一个
# 「有 / 没有」都对应下面的一次实际检查。macOS 与 Linux 用这份,Windows 用 setup-page.ps1。
# 兼容 macOS 自带的 bash 3.2:不用关联数组。

set -u

here="$(cd "$(dirname "$0")" && pwd)"
template="$here/frago-setup-intro.html"
tmp="${TMPDIR:-/tmp}"; tmp="${tmp%/}"          # 去掉尾部斜杠,免得路径里出现 //
out="$tmp/frago-setup/index.html"
json_only=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) json_only=1 ;;
    --out) shift; out="$1" ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

has() { command -v "$1" >/dev/null 2>&1; }

# ── 系统 ──
case "$(uname -s)" in
  Darwin) os=darwin ;;
  Linux)  os=linux ;;
  *)      os=other ;;
esac

# 跑在 WSL 里吗。WSL 里就是 Linux,装法与 Linux 一套;这个标记只用来告诉页面「这台机器
# 的 Windows 一侧另有可选项」,不改变装法。三个探针任一命中即算,见 frago 会话层同一判法。
wsl="none"
if [ "$os" = linux ]; then
  if [ -n "${WSL_DISTRO_NAME:-}" ] || [ -n "${WSL_INTEROP:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
    wsl="distro"
  fi
fi

# Linux 上用哪个包管理器,决定「怎么装」那句话
pm=""
if [ "$os" = linux ]; then
  for c in apt-get dnf pacman zypper; do has "$c" && { pm="$c"; break; }; done
  case "$pm" in apt-get) pm=apt ;; esac
fi
brew_ok=0; [ "$os" = darwin ] && has brew && brew_ok=1

# ── 谁在跑这个脚本:顺着父进程链往上找 agent 命令行 ──
running=""
p=$PPID
i=0
while [ -n "$p" ] && [ "$p" != 0 ] && [ "$p" != 1 ] && [ $i -lt 10 ]; do
  name="$(ps -o comm= -p "$p" 2>/dev/null)"; name="${name##*/}"
  case "$name" in
    claude*)              running=claude ;;
    codex*)               running=codex ;;
    opencode*)            running=opencode ;;
    codebuddy*|WorkBuddy*) running=codebuddy ;;
  esac
  [ -n "$running" ] && break
  p="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
  i=$((i+1))
done
[ -z "$running" ] && [ "${CLAUDECODE:-}" = 1 ] && running=claude

# ── agent 命令行 ──
ok_claude=0;    has claude   && ok_claude=1
ok_codex=0;     has codex    && ok_codex=1
ok_opencode=0;  has opencode && ok_opencode=1
# WorkBuddy 的命令行藏在桌面应用包里,PATH 上通常没有它,所以除了按命令找,还要看应用包。
# 包内的相对位置两个平台同形,差别只在应用装在哪。macOS 那条是实测的;Linux 那几条按桌面
# 应用的常规落点写,没有实机验证过。
ok_codebuddy=0
has codebuddy && ok_codebuddy=1
if [ $ok_codebuddy = 0 ]; then
  if [ "$os" = darwin ]; then
    cb_roots="/Applications/WorkBuddy.app/Contents/Resources"
  else
    cb_roots="/opt/WorkBuddy/resources /usr/lib/workbuddy/resources /usr/share/workbuddy/resources $HOME/.local/share/WorkBuddy/resources"
  fi
  for r in $cb_roots; do
    [ -x "$r/app.asar.unpacked/cli/bin/codebuddy" ] && { ok_codebuddy=1; break; }
  done
fi

# ── 依赖 ──
ok_git=0;    has git  && ok_git=1
ok_uv=0;     { has uv || [ -x "$HOME/.local/bin/uv" ]; } && ok_uv=1
ok_tmux=0;   has tmux && ok_tmux=1
ok_ffmpeg=0; has ffmpeg && ok_ffmpeg=1
ok_gh=0;     has gh && ok_gh=1
# 浏览器不是用户要装的东西:frago 自己取一份 Chrome for Testing 放这儿。
# 探它只为让页面显示「已就绪」还是「装的时候取」,两种都不用用户动手。
ok_cft=0
[ -d "$HOME/.frago/tools/chrome-for-testing" ] && ok_cft=1
ok_bwrap=0; has bwrap && ok_bwrap=1

# ── 「怎么装」:按这台机器的系统写成人看得懂的一句,中英各一份(页面按语言取) ──
if [ "$os" = darwin ]; then
  if [ $brew_ok = 1 ]; then via_brew="用 Homebrew 装"; via_brew_en="via Homebrew"
  else via_brew="先装 Homebrew,再用它装"; via_brew_en="via Homebrew (installed first)"; fi
  how_git="xcode-select --install";                 how_git_en="xcode-select --install"
  how_uv="官方安装脚本,装到 ~/.local/bin";           how_uv_en="official install script, into ~/.local/bin"
  how_tmux="$via_brew"; how_ffmpeg="$via_brew"; how_gh="$via_brew"
  how_tmux_en="$via_brew_en"; how_ffmpeg_en="$via_brew_en"; how_gh_en="$via_brew_en"
  how_claude="官方安装脚本";     how_claude_en="official install script";   manual_claude=false
  how_codex="$via_brew";        how_codex_en="$via_brew_en";              manual_codex=false
  how_opencode="$via_brew";     how_opencode_en="$via_brew_en";           manual_opencode=false
  how_codebuddy="WorkBuddy 是桌面应用,从官网下载"; how_codebuddy_en="WorkBuddy is a desktop app; download it from its website"; manual_codebuddy=true
  how_bwrap=""; how_bwrap_en=""
else
  case "$pm" in
    apt)    via_pm="用 apt 装";    via_pm_en="via apt" ;;
    dnf)    via_pm="用 dnf 装";    via_pm_en="via dnf" ;;
    pacman) via_pm="用 pacman 装"; via_pm_en="via pacman" ;;
    zypper) via_pm="用 zypper 装"; via_pm_en="via zypper" ;;
    *)      via_pm="用发行版的包管理器装"; via_pm_en="via your distribution's package manager" ;;
  esac
  how_git="$via_pm";                                how_git_en="$via_pm_en"
  how_uv="官方安装脚本,装到 ~/.local/bin";           how_uv_en="official install script, into ~/.local/bin"
  how_tmux="$via_pm"; how_ffmpeg="$via_pm"; how_gh="$via_pm"; how_bwrap="$via_pm"
  how_tmux_en="$via_pm_en"; how_ffmpeg_en="$via_pm_en"; how_gh_en="$via_pm_en"; how_bwrap_en="$via_pm_en"
  how_claude="官方安装脚本";     how_claude_en="official install script";   manual_claude=false
  how_codex="需要 Node.js,自己装好后再跑一次这份 skill 就能接上"; how_codex_en="needs Node.js; install it yourself, then run this skill again"; manual_codex=true
  how_opencode="官方安装脚本";   how_opencode_en="official install script"; manual_opencode=false
  how_codebuddy="WorkBuddy 目前只有桌面版"; how_codebuddy_en="WorkBuddy is desktop-only for now"; manual_codebuddy=true
fi

b() { [ "$1" = 1 ] && echo true || echo false; }
q() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

agent() { # id name ok how how_en manual
  printf '{"id":"%s","name":"%s","ok":%s,"how":"%s","how_en":"%s","manual":%s}' "$1" "$2" "$(b "$3")" "$(q "$4")" "$(q "$5")" "$6"
}
tool() { # id name ok required how how_en
  printf '{"id":"%s","name":"%s","ok":%s,"required":%s,"how":"%s","how_en":"%s"}' "$1" "$2" "$(b "$3")" "$4" "$(q "$5")" "$(q "$6")"
}

tools="$(tool git git $ok_git true "$how_git" "$how_git_en"),$(tool uv uv $ok_uv true "$how_uv" "$how_uv_en"),$(tool tmux tmux $ok_tmux true "$how_tmux" "$how_tmux_en"),$(tool browser "浏览器（frago 自带）" $ok_cft false "装的时候由 frago 取,不用你动手" "fetched by frago during install; nothing for you to do"),$(tool ffmpeg ffmpeg $ok_ffmpeg false "$how_ffmpeg" "$how_ffmpeg_en"),$(tool gh "GitHub CLI (gh)" $ok_gh false "$how_gh" "$how_gh_en")"
[ "$os" = linux ] && tools="$tools,$(tool bwrap bubblewrap $ok_bwrap false "$how_bwrap" "$how_bwrap_en")"

json="{\"os\":\"$os\",\"wsl\":\"$wsl\",\"running\":\"$running\",\"agents\":[$(agent claude "Claude Code" $ok_claude "$how_claude" "$how_claude_en" $manual_claude),$(agent codex codex $ok_codex "$how_codex" "$how_codex_en" $manual_codex),$(agent opencode opencode $ok_opencode "$how_opencode" "$how_opencode_en" $manual_opencode),$(agent codebuddy WorkBuddy $ok_codebuddy "$how_codebuddy" "$how_codebuddy_en" $manual_codebuddy)],\"tools\":[$tools]}"

if [ $json_only = 1 ]; then
  printf '%s\n' "$json"
  exit 0
fi

[ -f "$template" ] || { echo "template not found: $template" >&2; exit 1; }
mkdir -p "$(dirname "$out")"
# 模板里只有一处空位 /*__PROBE__*/null;走 ENVIRON 传值,避免 awk 对反斜杠再做一次转义
PROBE_JSON="$json" awk '{
  i = index($0, "/*__PROBE__*/null")
  if (i) print substr($0, 1, i - 1) ENVIRON["PROBE_JSON"] substr($0, i + 17)
  else print
}' "$template" > "$out" || exit 1
printf '%s\n' "$out"
