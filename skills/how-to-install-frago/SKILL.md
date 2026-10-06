---
name: how-to-install-frago
description: |
  This skill should be used when a user wants to install or configure frago from source on their machine (macOS/Linux/Windows) using the agent CLI they already have — Claude Code, codex or opencode. The agent runs a probe script that detects which agent CLI is running the skill and what the machine already has, opens a generated local page that collects every decision up front — which CLIs to hook up, what may be installed, whether to set up LightAgent — then clones the repository, builds it with uv, publishes it as the system frago by running the server once, verifies only what frago cannot repair by itself, fetches recipes on demand, backs the working directory up to a private GitHub repository, and closes with a welcome page that has the machine prove what changed. The user never types a frago command themselves, and never pastes an API key into the chat. Trigger phrases: "install frago", "安装 frago", "配置 frago", "frago 源码安装", "set up frago", "frago installation", "deploy frago hooks", "从源码安装 frago", "配置 frago 模型", "frago profile", "配方没有 api key", "frago 备份", "frago-working-dir".
license: AGPL-3.0
---

## Overview

装 frago,让用户已经在用的那些 agent 命令行在开口那一刻就带着 frago 的知识和规则,再配好没有它 frago 就干不了活的那一样东西——轻量 ai 的鉴权。

用户全程只动手两次:在一张本地网页上拿几个主意(接哪些、装哪些、配不配轻量 ai)、把网页给的那段配置贴回对话;选了备份的话再登录一次 GitHub。其余全部由 agent 完成,**中途不再问人**——所有决定都在开场页上一次收齐。

主路径:跑探测脚本生成开场页 → 页面收全部决定 → 按决定装依赖和勾了的 agent 命令行 → 装本体 → 接会话 → 验收 → 取配方 → 建 profile → 备份 → 收尾页。

## Scope

不装桌面客户端、不装 Node.js。agent 命令行(Claude Code、codex、opencode)只装用户在开场页上勾了「装上并接入」的,装完不替他登录。**不要跑 `frago init`**——它会装 Claude Code 并改写认证,这不是一个说「装 frago」的人要的东西。不碰用户已有的 Claude Code 认证。手写配置文件只是服务起不来时的兜底,不是正常步骤。

## 一条会毁掉安装的规矩

frago 拒绝从自己的源码检出运行。除 `server` 外的每条命令都会当场拒绝,服务本身也拒绝跑在仓库的虚拟环境里。这是故意的:仓库代码配上系统装的服务,是没有任何用户的机器上会出现的组合。

所以只有两种形态:

- 仓库里只准这一条:`uv run frago server start`(或 `restart`)。它抬补丁号、打 wheel、用 `uv tool install --force` 装成系统 frago,再把控制权交过去。源码变成产品就靠这一步。
- 其他任何地方,都用普通的 `frago` 命令,上一步之后它住在 `~/.local/bin/frago`。

**永远不要建议 `<repo>/.venv/bin/frago <任何命令>`。** 它会被拒绝,而那句拒绝在非技术用户眼里就是安装失败。

---

## 步骤

### 1. 跑探测脚本,生成开场页

**不要自己探测,跑 skill 带的脚本。** 它在本文件旁边的 `assets/` 里,macOS / Linux 用 `setup-page.sh`,原生 Windows 用 `setup-page.ps1`——**判断依据是 agent 自己此刻在什么系统上,不是「用户是不是 Windows 用户」**:在 WSL 里跑的,系统是 Linux,用 `setup-page.sh`,脚本会把「在 WSL 里」这一标记一起带出来。**skill 目录就是本文件所在的目录**——加载这份 skill 时给你的那个路径;没给的话,找一下 `assets/setup-page.sh` 在哪(装成插件时多半在 `~/.claude/plugins/` 下)。只需要跑这一条:

```bash
bash <skill 目录>/assets/setup-page.sh            # 探测这台机器,生成页面,打印生成后的路径
```
```powershell
powershell -ExecutionPolicy Bypass -File <skill 目录>\assets\setup-page.ps1
```

(加 `--json` 只打印探测结果不生成页面,排查时才用;正常安装不需要,探测结果已经嵌在页面里,也不用贴给用户看。)

脚本做三件事,规则都写死在里面,agent 不用判断:

- **认出是谁在跑它。** 顺着父进程链找 claude / codex / opencode / codebuddy,找不到再看 Claude Code 的环境变量。这个结果决定第 2 屏哪一个是「正在用」——那一个必须接上,页面上锁死不让取消,因为 frago 正是通过它在给用户装。
- **查四个 agent 命令行在不在**:claude、codex、opencode、codebuddy(含 WorkBuddy 桌面应用内嵌的那份,固定路径在脚本里)。没装的也进页面,用户可以勾「装上并接入」;agent 装不了的(WorkBuddy 只有桌面版,Linux 上 codex 要 Node.js)页面会说明「自己装好后再跑一次 skill」。
- **查依赖在不在**:git、uv、tmux(必装)、ffmpeg、gh,Linux 再加 bubblewrap。缺的每一项配上这台系统上的装法,写成人看得懂的一句。浏览器不在这张单子里——frago 自己带一份,不用用户装(见第 3 步)。
- **在 Windows 上还查 WSL 走到哪一步**(没装 / 没发行版 / 有发行版)。它决定第 3 步给不给「装原生还是装 WSL」这个选择:没有 WSL 就只推原生,已有 WSL 则两条路都摆出来。

然后把探测结果嵌进模板 `frago-setup-intro.html`,生成到临时目录,打印路径。模板本身没有任何机器状态,直接打开只显示一句「要由 skill 生成后打开」;**不要改 skill 目录里的模板**。

**这一步一样都不装。** 装哪些由用户在页面上勾。

### 2. 打开生成的页面,等用户的决定

交给用户的系统默认浏览器:macOS `open <路径>`,Linux `xdg-open <路径>`,Windows `start <路径>`。这一步发生在 frago 装好之前,没有配方运行器、也还没有 agent 专用的浏览器,只能走系统自己的打开方式。页面按视口自适应,矮于 900 像素会自动收紧间距。

**打开之后告诉用户去哪看。** 这些命令成功了也没有回显,窗口可能落在别的窗口后面(全屏会议、另一块屏)。说一句「页面开在你的浏览器里,标题是『frago — 装之前先问你几件事』,没看到就切过去」,然后等。用户说没弹出来,把路径给他,请他自己打开。

页面中英双语,按浏览器语言默认,右上角可切;每屏一个地址 `#1`…`#5`,要把用户送回某一屏就开带锚点的路径。这一页不是安装进度,是安装前的问卷,五屏各收一个决定:这是什么、接上哪些命令行(含要不要装没装的)、允许装哪些软件(含装完留不留常驻服务、要不要创建私有仓库备份)、轻量 ai 配不配、过一遍决定后交给你。最后一屏是一段配置文本,用户复制、贴回对话,你从这段文本开始干活。配了轻量 ai 的话,页面先让他把钥匙存成本机文件 `frago-setup-key.json`(浏览器下载),配置里只写这个文件在哪。**钥匙走文件不走对话**:贴进对话它就永久留在会话记录里,以后谁翻到这段对话谁就拿到了它。

贴回来的配置长这样,后面每一步都照它办,**不再问用户第二遍**:

```json
{
  "frago_setup": 2,
  "os": "darwin",
  "windows_target": "native",              // 仅 Windows 上有:装原生还是装 WSL(native / wsl);macOS、Linux 上没有这个字段
  "lang": "zh",                            // 用户在页面上用的语言(zh / en),之后跟他说话用这个
  "running": "claude",                     // 脚本认出的、正在跑这份 skill 的 agent
  "connect": ["claude", "codex"],          // 已装且勾了接上的命令行(running 一定在里面)
  "install_agents": ["opencode"],          // 没装、勾了「装上并接入」的命令行(第 3 步)
  "install": ["tmux"],                     // 勾了允许装的依赖(第 3 步)
  "skip": ["ffmpeg", "gh"],                // 没勾的,对应能力明说不可用
  "keep_server": true,                     // 装完留不留常驻服务(第 12 步)
  "backup": false,                         // 要不要创建私有仓库备份(第 11 步)
  "lightagent": { "vendor": "deepseek", "endpoint_type": "deepseek", "url": "…", "model": "…", "key_file": "~/Downloads/frago-setup-key.json" }   // 或 null = 先不配
}
```

`vendor` 是页面上选的(deepseek / openrouter / custom),`endpoint_type` 是 frago profile 认的类型。`key_file` 是钥匙文件的位置:页面默认写浏览器的下载目录,用户改过就以贴回来的为准。钥匙文件里是 `{ "frago_setup_key": 2, vendor, endpoint_type, url, model, api_key }`。

收到配置之后立刻开始干活,中途不再打断用户。钥匙文件在第 9 步读一次、建好 profile 就删。

四个 agent 的接法不一样,页面上不用区分,agent 自己要清楚:claude、codex、opencode 在第 6 步服务启动时被接上,之后用户自己开的每个会话都带注入;codebuddy 是 frago 派活时的一个机位,frago 起它的时候才把钩子挂上,用户自己开的 WorkBuddy 会话不受影响。一个都没有也能装完:网页、配方、知识索引照常工作,只是没有会话能收到注入、也派不出活,收尾时要明说。

### 3. 按用户的决定装依赖,和他勾了的 agent 命令行

**装 frago 只需要 git、uv 和 tmux:前两个是本体,第三个是派活。** 派活(`frago agent`、主代理、`frago remote`)是这个工具的核心用法,不是可选项,所以 tmux 和 git、uv 一样是页面上锁死的必装项,直接装——不要问用户「要不要派活」,他装 frago 就是要的。Python 不用预装,uv 会按 `requires-python>=3.13` 拉一个托管版本。所有锁定依赖都有预编译轮子,任何系统都不需要编译器。

- macOS:`xcode-select --install` 保证有 git;uv 用 `curl -LsSf https://astral.sh/uv/install.sh | sh`。
- Linux:apt/dnf/pacman 装 git、curl;uv 同上。
- Windows:按贴回来的配置里 `windows_target` 定装在哪一边,再往下——
  - **没有 WSL**:装在原生 Windows,这是首选,页面上不摆第二个选项。
  - **已有 WSL**:原生和 WSL 两条路都摆给用户选。选 WSL 的,后续命令经 `wsl.exe` 在 WSL 里跑(或请用户自己进 WSL 再跑一遍本 skill);选原生的,按下面这条走。
  装原生 Windows 这一边:`winget install Git.Git`(兜底:git-scm.com 的安装包;它顺带装上 Git Bash,不要漏——tmux 面板靠它当默认壳);uv 用 `powershell -c "irm https://astral.sh/uv/install.ps1 | iex"`。
- POSIX 上 uv 落在 `~/.local/bin`,当前 shell 可能还没有它,先 `source ~/.local/bin/env` 或直接用绝对路径。

**再往下几样,各管一种能力。** 它们跟 tmux 不同——tmux 是锁死的必装项,这几样缺了 frago 照常装完、照常启动,这正是要在开场页上逐条列给用户勾的原因:它们坏的时候是静默的,一次坏一种能力,离「安装成功」已经过去很久。**只装贴回来的配置里 `install` 列出的;`skip` 里的一律不装,装完时明说那项能力用不了。**这张表是给你自己看的,用户已经在页面上看过同样的话。

| 干什么要它 | 是什么 | 缺了会怎样 |
|---|---|---|
| 派活(`frago agent`)、主代理、`frago remote`;也是替用户过 codex 信任门的工具 | **tmux** | worker 永远起不来,全部报错就一句 `Error: tmux not found`。没有它,第 9 步建 profile 等于白建 |
| 浏览器自动化(`frago browser`) | **不用装**——frago 自己取一份 Chrome for Testing(见下) | 没取到时才退回找用户装的 Chromium 系浏览器,一个都没有就把每个都列成未找到 |
| 录标签页、虚拟桌面(`frago desktop`) | **ffmpeg** | 录制调用直接失败,别的都正常。虚拟桌面还要 tmux 和一个可用的浏览器 |
| **Linux 上**跑配方 | **bubblewrap**(`bwrap`) | 配方被拒绝运行,而不是不隔离地跑。macOS 用系统自带沙箱,不需要额外装 |
| 创建私有仓库备份(第 11 步) | **gh** | 建不了私有仓库、推不上去。页面上勾了「创建私有仓库」会连带勾上它 |

从哪来:macOS 上 tmux 和 ffmpeg 走 Homebrew。Linux 上 tmux、ffmpeg、bubblewrap 走发行版的包管理器。Windows 原生这一边,tmux 走 winget 上的社区移植版 `arndawg.tmux-windows`,ffmpeg、gh 走 winget;另需两样机器上的条件——Git Bash(随 Git for Windows 来,上面的 git 装完就有)和系统级 UTF-8(代码页 65001,不开的话中文提示词进 tmux 面板会乱码或被当面拒绝)。浏览器三个平台都不用装。

**浏览器由 frago 自己带,不要让用户装。** 取一份 Chrome for Testing 放进 `~/.frago/tools/chrome-for-testing/`,frago 会自动挑中它。这是 Google 官方为自动化场景发布的 Chrome 构建,压缩包不到 200 MB,解压后放着就能用——不进 `/Applications`、不要管理员权限、不注册成系统默认浏览器,也不会跟用户日常在用的那个抢 profile。

早先的版本要求用户装 Edge,理由是「驱动真实 profile 才有登录态」。那条现在不成立了:agent 用的浏览器本来就该是专属的一个,登录态由用户在里面登一次积累,跟他日常那个浏览器分开反而更干净;而让人为了装个 agent 才去下 1.4 GB 的浏览器,是这一步最大的一道坎。

怎么取,四步:

1. 读 `https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json`,在 `channels.Stable.downloads.chrome` 里挑本平台那条(`mac-arm64` / `mac-x64` / `linux64` / `win64`)。
2. 下载那个 zip,解压到 `~/.frago/tools/chrome-for-testing/`。解压后是一层带平台名的目录(如 `chrome-mac-arm64/`),**原样留着别铺平**,frago 按这个形状找可执行文件。
3. macOS 上补一句 `xattr -cr "<那个 .app>"`。用浏览器下载会被系统打上隔离属性,不清就报「应用已损坏」;用 curl/wget 下的一般没有这个问题,但清一次不会错。
4. 验:`frago browser check` 里 `Chrome for Testing` 那一行是 ✓,末尾 `Default:` 指向 `~/.frago/tools/chrome-for-testing/...`。

约 200 MB,跨境链路上可能要几分钟,下载前跟用户说一声在下什么、多大。下不动就跳过——frago 会退回找机器上已有的 Chromium 系浏览器,收尾时说明浏览器自动化这一项要用哪个浏览器、或者稍后重取。

**别把 Chrome 稳定版当备选。** 它从 v137 起静默忽略加载扩展的参数——不报错,只是扩展没进去,现象是「桥连不上」,跟登录、跟网络都对不上号,极难查。frago 的挑选顺序里刻意排除了它。用户机器上已经有 Edge / Chromium / Brave / Vivaldi 的,那些都能用,是 CfT 取不到时的退路。

**`~/.local/bin` 必须进用户的永久 PATH,不只是当前这个 shell。** frago 的钩子敲的是裸命令 `frago`;启动 Claude Code 的那个 shell 找不到它,钩子照样触发,但每次知识注入都是空的,而且没有任何一行告诉你为什么。检查用户的 shell 配置文件,缺了就补上。

**用户勾了「装上并接入」的 agent 命令行(`install_agents`),在这一步装。** 用页面上写的那条路:Claude Code 和 opencode 走各自的官方安装脚本,macOS 上 codex 走 Homebrew。装完**不要替用户登录**,也不要碰它的认证——页面上已经告诉他装完得自己登录一次;收尾时再提醒一遍,并说明登录之前那个命令行收不到注入。没勾的一个都不装,页面上标了「agent 装不了」的(WorkBuddy、Linux 上的 codex)更不要试。

### 4. 服务器 / root 判断

多数安装是一个人自己的机器,这一节不适用,直接装。它适用于两种情况:目标是一台用户要从网络访问的服务器,或者当前就是以 **root** 在装。云主机默认就是 root 登录,所以这经常在没人选择的情况下发生。早点查一次:`id -u` 是不是 0,或者用户在说服务器、域名、部署、公网、开放页面。

两件事会出问题,而且都不报错:

- **frago 的服务令牌等于以服务运行的那个账号执行命令的权限。** 装成 root,这个令牌就是整台机器的 root,不是沙箱。
- **claude 拒绝以 root 跑它的免确认模式。** frago 的子代理跑在同一个账号下,所以 root 安装时代理那一侧永远起不来:网页、配方、知识索引都正常,但派活、主代理、`frago remote` 静默失效——worker 起了,claude 因 root 退出,frago 一直等一个永远不会来的就绪信号。没有任何一行说明原因。

第二条**只对 claude 成立**。选 codex 或 opencode 当干活机位时,root 下照样能派活。第一条与选哪个机位无关。

装在服务器上或以 root 装之前,把这件事当成一个决定摆给用户,而不是一步推过去。说清代价,并说明解法是建一个**专用的非 root 用户**:`useradd -m -s /bin/bash frago` 之类,然后 clone、uv 构建、常驻服务、以及之后每一条 frago 命令都以这个用户身份跑。服务本身可能仍需 root 来绑特权端口或装 systemd 单元,但**跑 `frago server` 的那个账号是每个代理继承的账号,所以它不能是 root**。用户理解了代价仍然要 root 装,就装,但要明说什么会不能用。

### 5. 取源码、建环境

`git clone https://github.com/tsaijamey/frago.git` 到一个稳定路径,比如 `~/frago`。github.com 不通的地区可以加镜像前缀:`https://mirror.ghproxy.com/https://github.com/tsaijamey/frago.git` 或 `https://ghproxy.net/...`。然后在仓库里跑 `uv sync`(不需要 `--all-extras --dev`)。

检出要留着:后面有一步要从里面拷一个文件,升级也就是 `git pull` 加一次服务重启。

### 6. 在仓库里跑一次服务

`uv run frago server start`,然后等。输出会依次报出它抬到的版本号、打出的 wheel、以及交给系统 frago 的那一刻。启动过程中产品代码会自动完成:

- 把包里的知识铺到 `~/.frago`——`book/` 目录、`constitution.md`、`agent-disciplines.md`。**已存在的文件一律不覆盖**,所以用户改过的内容不会被升级抹掉;后续版本新增的条目仍然到得了。
- 把平台二进制部署到 `~/.frago/bin/frago-core`,并清掉旧布局留下的残留。
- 合并写入 `~/.claude/settings.json`,不动其他钩子。
- 装了 opencode 就把桥铺到 `~/.config/opencode/plugin/`。
- 装了 codex 就把同一个引擎注册进 `~/.codex/hooks.json`。

部署在启动后二十秒左右才完成,不是瞬间。太早去检查看到的是一台半配好的机器,等服务应答之后再验。

**按 `connect` 收口。** 服务启动时会给本机装了的 claude、codex、opencode 全部注册,不看用户勾没勾(第 3 步新装的也算在内)。`running` 那一个用户取消不了,一定在 `connect` 里。用户在页面上点掉的那个,启动后把它那份注册删掉:Claude Code 是 `~/.claude/settings.json` 里 hooks 段带 `frago-core --engine` 的条目,codex 是 `~/.codex/hooks.json`,opencode 是 `~/.config/opencode/plugin/` 下的 frago 文件。并告诉用户:下次 `frago server restart` 会再加回来,那时再删一次——这是产品目前的限制,不是他勾错了。codebuddy 不用做任何事:它只在 frago 派活起它时才挂钩子,用户自己开的 WorkBuddy 会话本来就不受影响。

**替用户过 codex 的信任门(勾了 codex 才做)。** codex 不直接运行新装的钩子,要先过目并信任它的确切定义,信任记录写在 `~/.codex/config.toml` 的 `[hooks.state]` 里,每个钩子一条哈希。这道门归 agent,不归用户:有 tmux 就在 tmux 里起一次 `codex`(不带 `--dangerously-bypass-hook-trust`,那个参数会绕过这道门、什么都不写),看到「Hooks need review」选 Trust all,退出,再看 `config.toml` 里有没有多出四条 `trusted_hash`。这条路走的是 codex 自己的流程,哈希一定对;不要自己算哈希写进去——它是对 codex 内部结构序列化后算的,拼不出来。没有 tmux 才退回让用户自己进一次 codex 选 Trust all。*本 skill 写下这一段时,tmux 驱动这一步还没实际跑过;跑不通就明说,退回让用户点。*

### 7. 验收:只验 frago 自己修不好的

**不要去数注册了几个事件、超时是多少、桥接文件有几个。** 那些是 frago 每次启动自己重新算、对不上就覆盖的东西,人去清点等于替产品检查它有没有正确执行自己的同步,而且数字一改 skill 就假失败一次。

要验的是这几件:

- **`~/.local/bin` 在不在永久 PATH 里。** 在一个全新的终端里跑 `frago --version`。这件事 frago 修不了。
- **`~/.claude/settings.json` 里有没有 frago 的条目。** 查「有没有」,不查「几条、超时多少」。二进制跑不起来时同步会整个跳过、一条都不注册,那是真正的失败。
- **codex 的信任(勾了 codex 才有)。** 第 6 步替用户过了门之后,`~/.codex/config.toml` 里应有四条 `trusted_hash`。没有就是没过成,回去重做或交给用户点。
- **端到端。** 让用户重启 Claude Code。新会话开头出现 frago 的知识注入,就证明整条链通了:PATH 找得到 frago、设置指向二进制、二进制路由了事件、命令行应答了。这一条过了,前面那些逐项清点本来就不必要。

`~/.frago/runtime.json` 不存在了。旧指南要你创建或检查它的话,忽略——没有任何代码读它。

### 8. 取配方

**包里一个配方都不带**,`frago init` 也装不来。公开的那批住在 `tsaijamey/frago-recipe-community`。

这一步**不要问用户「你需要哪个」**。他刚装完,没见过任何一个配方,不知道配方是一段能重复跑、还带界面的活,更不知道社区仓库里有什么——这个决定他没有判断依据。

做法是:`frago recipe search <关键词>` 看社区仓库实际有什么,拿这次对话里已经知道的用户是谁、干什么活,提两三个具体的推荐,他点头才装。不是列一整屏让他自己挑。

然后告诉他以后怎么补:手上有一件具体的活时,先让 agent 查一次有没有现成的,再考虑从头写。

### 9. 建轻量 ai 的 profile

看贴回来的配置里的 `lightagent`:是 `null` 就跳过,并在收尾时说一句「轻量 ai 没配,规则和知识现在按关键词硬匹配,以后在 frago 设置页随时补」。有值就读 `key_file` 指的那个文件(`~` 和 `%USERPROFILE%` 要展开),取出 `api_key`,通过 frago 自己的设置接口把 profile 建起来,**不要手写 `~/.frago/profiles.json`**——那个文件存明文钥匙、按属主权限写入,创建和编辑只走产品自己的接口。**建好 profile 立刻把钥匙文件删掉**,并告诉用户删了。

`key_file` 指的位置没有这个文件时:同一目录下找 `frago-setup-key*.json`(浏览器碰到同名会存成 `frago-setup-key (1).json`),取最新的那个;还是没有,就告诉用户浏览器没把钥匙文件存到配置里写的位置,请他看下载栏、把实际位置贴回来。不要猜别的目录,不要让用户把钥匙贴进对话。

轻量 ai 只认 HTTP 端点加钥匙,支持的端点类型是 deepseek、custom、anthropic、official、claude。命令行装的 agent(codebuddy 之类)不能当它的后端。

DeepSeek 当前的模型是 `deepseek-v4-flash`(还有 v4-pro 和 vision 版),端点 `https://api.deepseek.com`。`deepseek-chat` 和 `deepseek-reason` 已经下线,不要再用。

建完用 `frago profile list` 验一下,它打印保存的 profile 并把钥匙打码。这条命令是只读的——创建和编辑只在网页设置页。

### 10. 配方钥匙

调用外部服务的配方从 `~/.frago/recipes.local.json` 读自己的钥匙。缺钥匙的配方会当场失败并报出缺什么。

只给用户真要跑的那几个配。某个配方这样失败时,打开 `http://127.0.0.1:8093` 的配方页,让用户填它的凭据对话框——字段是配方自己声明的,只问它真正需要的那几个。规矩和 profile 一样:钥匙填进页面,不填进对话。

### 11. 备份工作目录

用户通过 frago 攒下来的一切——建的配方、填的知识域、路由规则、跑过的记录,还有他改过的宪法和 book——都在 `~/.frago`。它不在刚 clone 的仓库里,任何升级都不会重建它。frago 的设计是把这个目录做成一个 git 仓库,镜像到一个**私有**的 GitHub 仓库 `frago-working-dir`,这也是换第二台机器的前提。

用户已经在开场页上决定过了:贴回来的配置里 `backup` 是 `false` 就跳过这一步,收尾时说一句他的配方和知识现在只存在于这台机器上,以后想备份再说;**不要再问一遍**。是 `true` 才往下:

**a. 确认 gh 在且已登录。** `gh --version` 和 `gh auth status`。缺了就装:macOS `brew install gh`、Debian/Ubuntu `sudo apt install gh`、Fedora `sudo dnf install gh`、Windows `winget install GitHub.cli`。

`gh auth login` 是交互式的,会问几个问题并开浏览器要一次性码。agent 替不了用户回答,所以明确交回去——在 Claude Code 里用户可以直接敲 `!gh auth login` 就地跑,`gh auth status` 报出账号就算完成。没有 GitHub 账号的用户先去 github.com 注册,登录流程不会替他建。

**b. 先铺忽略规则,再提交任何东西。** 包里带着权威的忽略清单,但**没有任何代码会自动铺它**,从检出拷过去:

`cp <repo>/src/frago/resources/frago-home-gitignore.template ~/.frago/.gitignore`

**c. 第一次推之前,确认没有凭据进了暂存区。** `git -C ~/.frago init`(已经是仓库就跳过),然后 `git -C ~/.frago status --short` 逐行读。下面任何一个出现就停下——忽略规则没生效:

`server-token`、`remotes.json`、`config.yaml`、`users.json`、`login-sessions/`、`published.json`、`profiles.json`、`recipes.local.json`、`config.json`、任何 `.env`。

前五个是这台机器和其他机器的通行凭据,拿到即等于拿到它指向的东西。**这一关没过,绝不往下推。**

**d. 建私有仓库并推送。** `git -C ~/.frago add -A && git -C ~/.frago commit -m "frago working dir"`,然后 `gh repo create frago-working-dir --private --source ~/.frago --push`。告诉用户这个仓库是私有的,以及为什么这件事重要:它装着他的工作、他的笔记、以及他自动化了什么的形状。

**以后的同步不要教普通 git。** 网页上有一页「数据仓库」,列出 `~/.frago` 里还有多少东西等着备份、哪些会备哪些不会,点一下就起一个 agent 替他分组、提交、推送。换第二台机器时,先把那个仓库 clone 进 `~/.frago`,再在那台机器上装 frago。

### 12. 常驻服务的去留

服务提供 8093 上的网页、调度和任务入口。第 9、10 步需要它在跑。按贴回来的配置里 `keep_server` 办,**不要再问**:`false` 就在第 13 步收尾页之后跑 `frago server stop`——磁盘上的东西全在,钩子链照常工作,只是网页和调度没有了,以后要改凭据得先 `frago server start`。

### 13. 收尾页:交给欢迎配方

到这里一切都能用了,而用户还什么都没见着。frago 自己不带配方,所以从社区仓库取那个负责介绍它的配方来跑——两条命令,按这个顺序,每次安装都跑:

```bash
frago recipe install community:frago_welcome
frago recipe run frago_welcome
```

第一条从 `tsaijamey/frago-recipe-community` 拉配方;第二条把页面准备好,交给用户**自己的默认浏览器**(配方返回 `open_url`,运行器负责打开)。**不要用 `frago browser navigate` 开它**——那驱动的是 agent 自己控制的浏览器,用户看不到。也不要把地址贴出来让用户自己开;跑配方这个动作本身就是打开。

六屏,每屏有自己的地址(`#1`…`#6`,任何一屏都能单独重开或发给别人):装完变了什么、现在就能提什么要求、一个现场演示、那个演示是怎么做到的、接下来去哪。

页面上有两处会反过来碰这台机器,用户按之前 agent 要心里有数:

- **第四屏的演示**——用户写一条自己的规则、按一个按钮,它就存进这台机器的一个知识域。页面接着把他送回这个终端,让他来问你那条规则。
- **第二屏的「不是吧」按钮**——每个按钮把它的问题交给这台机器上的一个真实 agent 会话,把答案打在屏上。这需要有模型可用:第 9 步做完了,几秒内答出来;没做,退回一段写好的样例,并在屏上说明这是样例。两种情况都不会坏。

用户回来问他存的那条规则时,**像回答任何问题一样回答:先看再说。** frago 的轻量 ai 会把问题路由到它所属的知识域;没路由到就 `frago my-rules find` 直接读。绝不能因为看着他打字就复述给他——那证明不了任何事。从机器上读回来。

说页面已经打开,让用户自己走。不要替他讲解每一屏。

两条命令任何一条失败(没网、仓库不通),明说,然后回到第 7 步的端到端检查——没有这张页,安装本身也是好的。第 13 步跑成了的话,用户存的那条规则比会话开头那条横幅更硬:它撑过重启,而从它答出来走的是同一条链。

---

## 排查:按用户看到的现象

- **「Refusing to run: this frago comes from the source checkout」** —— 在仓库里跑了命令。换个目录用普通的 `frago`;确实是服务的话,在仓库里用 `uv run frago server start`。
- **会话开头没有 frago 的知识** —— 先查 PATH(在全新终端里 `frago --version`),再查 `~/.claude/settings.json` 里到底有没有 frago 的条目,最后查 `~/.frago/bin/frago-core` 可不可执行。
- **`frago: command not found`** —— `~/.local/bin` 没进永久 PATH。改 shell 配置文件,不要拿绝对路径凑合。
- **codex 里什么都没注入** —— 钩子没被信任,第 6 步那一下没过成。在 tmux 里再走一遍,或让用户进 codex 选 Trust all。
- **派不出活,worker 起不来** —— 先看有没有 tmux(第 3 步);再看是不是 root 装的且机位选的是 claude(见第 4 步)。多建几个 profile 对这两种都没用。
- **Windows 上 tmux 会话起了、消息发不出去** —— 面板的默认壳落到了 cmd.exe,而 frago 发的是 POSIX 语法命令,cmd 一条都不认。面板要 Git Bash 当默认壳(随 Git for Windows 来);装上 Git Bash 再试。
- **Windows 上中文提示词进 tmux 变乱码或被拒** —— 系统级 UTF-8 没开(代码页不是 65001)。切到 65001 后重启系统再试;纯英文不受影响。
- **`frago browser check` 把每个浏览器都列成未找到** —— Chrome for Testing 没取成,机器上也没有别的 Chromium 系浏览器。重取一次(第 3 步);`Chrome` 那一行显示可用不算数,稳定版走不了扩展这条路。
- **录制失败,别的都正常** —— 缺 ffmpeg(第 3 步)。
- **Linux 上配方还没跑就被拒绝** —— 缺 bubblewrap(第 3 步)。这是故意的拒绝,不是崩溃。
- **8093 端口被占** —— 已经有一个 frago 服务在跑,`frago server status` 能确认。不要再起第二个。
- **配方报缺 api_key** —— 那是第 10 步,不是装坏了。
- **`gh auth login` 开不出浏览器**(无头或远程机器)—— 选它给出的设备码方式,在任何别的设备上打开那个网址。码有时效,过期就重来,别重复用。
- **`gh repo create` 说名字被占** —— 用户已经有一个 `frago-working-dir`,多半来自另一台机器。把那个 clone 进 `~/.frago`,不要建第二个。

## 附录:手工兜底(仅当 `uv run frago server start` 彻底失败)

也可当验收清单用:

1. `~/.frago/config.json`(不存在才写,永不覆盖):`{"schema_version": "1.0", "auth_method": "official", "init_completed": true}`。`auth_method=official` 表示不动用户已有的 Claude Code 认证。
2. `mkdir -p ~/.frago/bin/`,把 `<repo>/src/frago/bin/<平台>/frago-core` 拷过去。平台目录:darwin-arm64、darwin-x86_64、linux-x86_64、windows-x86_64;Windows 文件名是 `frago-core.exe`;没有对应二进制的平台(如 linux-aarch64)钩子不可用,但命令行仍然能用。POSIX 上 `chmod 755`。
3. 合并写入 `~/.claude/settings.json` 的 hooks 段,**永不整体覆盖**。事件清单和超时值都要问二进制自己:`<binary> --supported-events` 给出事件和 matcher,不要凭记忆写死。每个事件追加 `{"matcher": "<它给的>", "hooks": [{"type": "command", "command": "<frago-core 绝对路径> --engine", "timeout": <当前值>}]}`,已注册的跳过。`--engine` 不可省——那个二进制里有两个程序,不带这个参数会启动内核而不是路由钩子事件,钩子就静默失效了。Windows 上路径写正斜杠,Claude Code 通过 Git Bash 启动钩子,反斜杠会被吃掉。
4. **不要手写**:`hook-rules.json`(内置规则编译在二进制里)、`~/.frago/book/`(服务启动时自己铺,且不覆盖已有)、`profiles.json` 和 `recipes.local.json`(都存明文钥匙,只走网页)、AGENTS.md。`~/.frago` 下其他子目录都是懒创建的。唯一值得手工放的是 `~/.frago/.gitignore`,而且只从第 11 步说的那个模板拷。

## 附录:给 Claude Code 自己配第三方端点(可选)

仅当用户没有 Anthropic 官方认证,且只针对他自己的 Claude Code——这和第 9 步 frago 的模型 profile 是两件事,后者服务的是子代理。合并进 `~/.claude/settings.json` 的 `env` 段:ANTHROPIC_BASE_URL、ANTHROPIC_MODEL、ANTHROPIC_DEFAULT_SONNET_MODEL、ANTHROPIC_DEFAULT_HAIKU_MODEL、API_TIMEOUT_MS、CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC、ANTHROPIC_API_KEY(DeepSeek 的 base_url 是 `https://api.deepseek.com/anthropic`);并确保 `~/.claude.json` 里有 `{"hasCompletedOnboarding": true, "lastOnboardingVersion": "1.0.0", "isQualifiedForDataSharing": false}` 以跳过官方登录引导。

---

## About

Generated by **frago** — An Agent OS that turns ad-hoc agent runs into reusable recipes.

Install: `uv tool install frago-cli`
Homepage: https://frago.ai · Docs: https://docs.frago.ai
