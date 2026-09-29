## What's in this release

v0.6.1 is the Windows pass. The probe script had never been run on a Windows machine; it was run on one (Chinese locale, code page 936) and it did not work at all — two separate showstoppers on the very first step of the install. Both are fixed, and the Windows half of the guide now reflects what the machine actually does.

## Fixed — the Windows probe script never ran

- **The script is now saved with a UTF-8 BOM.** Windows PowerShell 5.1 — the interpreter this skill tells the agent to use — reads a BOM-less `.ps1` as ANSI on machines whose locale is not UTF-8. Every Chinese string in the file was mangled and the script died with a parse error before doing anything. Verified against the unmodified file first, so this is not a regression introduced here.
- **`$json` was the same variable as `param([switch]$Json)`.** PowerShell variable names are case-insensitive, so assigning the JSON payload to `$json` threw "cannot convert String to SwitchParameter". That line runs unconditionally, so the script failed in both modes on every Windows machine. The variable is now `$payload`.
- **Console output is pinned to UTF-8**, so `--json` no longer hands the caller mojibake on a non-UTF-8 machine.
- **The probe re-reads PATH from the registry** before detecting anything: winget and the uv installer change the user-level PATH, but the process the agent is already running in keeps the stale one, so freshly installed tools looked missing.

## Changed — Windows can run agent sessions now

- **tmux on Windows is installable, and the guide says how**: `winget install arndawg.tmux-windows`. The old text said "no native tmux on Windows; delegation needs WSL, the agent cannot install this", which pushed a Windows user into installing a Linux distribution to use frago at all.
- **What that package is, stated plainly.** Upstream tmux is POSIX-only; the Windows build is a third-party port over ConPTY. frago adapts to its quirks in the driver — session creation without `-c`, pane shell pinned to Git Bash, screen reads decoded as UTF-8 explicitly, liveness downgraded on truncated process names, non-ASCII text delivered through a file instead of the command line — so the user installs the package and nothing else.
- **Git for Windows is now called out as a runtime dependency, not just a clone tool.** The tmux panes run its Git Bash; frago's launch command is POSIX syntax and `cmd.exe` understands none of it.
- **PATH refresh is documented as a step**, with the one-liner, next to the Windows install commands.
- **`Start-Process` replaces `start`** for opening the generated page; `start` is a cmd built-in and is not reliable when an agent calls PowerShell non-interactively.
- **`-NoProfile` is now part of the documented invocation** — a user's PowerShell profile writes to stdout and corrupts the `--json` output.
- **Four Windows entries added to troubleshooting**: freshly installed commands "not recognised" (stale PATH), sessions failing with `never reached ready signal` (tmux / Git Bash / a menu waiting for a keypress), an agent that cannot reach the network reporting what looks like an auth failure (proxy variables belong in the environment of the process that starts the server), and the "recipes are not running isolated" line on Windows, which is an explanation rather than an error.

## Previously — v0.6.0 moved every decision to the front Before touching anything, the agent probes the machine with a script shipped in the skill, generates a page from that probe, and lets the user decide once — which CLIs to hook up, what may be installed, whether to set up LightAgent, what happens after. The user pastes one block of configuration back into the chat, and the install runs through without asking again.

### v0.6.0: the page is generated, not shipped

- **A probe script does the detection** (`assets/setup-page.sh`, `assets/setup-page.ps1` on Windows). It walks the parent process chain to recognise which agent CLI is running the skill, checks the four agent CLIs and every optional dependency, and writes an install hint for each missing item in the machine's own terms (Homebrew, apt, winget…). The agent runs one command and opens the path it prints; it no longer judges or edits anything by hand.
- **The template carries no machine state.** Opened directly, it shows a single line saying it must be generated first. It cannot pretend to be someone's machine.
- **Five screens, each one decision.** What this is and what the install touches · which CLIs to hook up · what to install and which services to keep · LightAgent · review and hand over. Nothing on the page reads as install progress; the first screen says plainly that nothing has been installed yet.
- **The CLI running the skill is locked on.** It is tagged "in use" and cannot be unticked, because frago is being installed through it. Other installed CLIs are ticked by default and can be removed; CLIs that are not installed are listed too, and can be ticked to install and hook up (the user signs in to them afterwards). Ones the agent cannot install (WorkBuddy, codex on Linux) say so.
- **Software is always listed the same way.** Every dependency appears as a row whether present or missing; presence only changes the row's state. Missing ones are installed only if ticked, required ones are locked on, and each row says what the capability is, what is lost without it, and how it would be installed.
- **Keep the server / private backup repository** are decided on the page too. The backup option is named for what it is — a private repository under the user's own GitHub account — and ticking it pulls in `gh` if missing.
- **Hand-over is a pasted block, not a hunted file.** The last screen shows the full configuration as text with a copy button. If LightAgent was set up, the key is first saved to a local file (`frago-setup-key.json`) and the configuration only records where that file is; the agent reads it once, creates the profile, and deletes it. The key never enters the chat.
- **Bilingual.** English and 中文, following the browser's language, switchable in the top bar; currency and paths follow the language and OS. Each screen has its own address (`#1`…`#5`).
- **codex's hook-trust gate is the agent's job.** codex records trust as a hash in its own config; the agent passes the gate by running codex once in tmux and choosing "Trust all", and only falls back to the user when tmux is absent.
- **LightAgent's cost is a reference, not a headline**: 1B tokens a day on the main agent means about ¥2 / $0.30 of LightAgent on DeepSeek V4 Flash, billed by the user's own provider — frago itself charges nothing. Provider choices are DeepSeek (recommended), OpenRouter, or a custom endpoint.

### v0.6.0 fixes

- The skill no longer assumes it is running under Claude Code; codex and opencode users get the same flow, and the page names whichever CLI is actually running it.
- Missing dependencies are never installed unattended; the skill installs exactly what the configuration lists and says what stays unavailable.

## Known limitations

- The Windows notes above describe a frago whose driver carries the native-Windows adaptations; on a build without them, installing tmux on Windows is not enough to start a session
- Passing codex's hook-trust gate from tmux has not been exercised end to end yet; the fallback is the user choosing "Trust all" once
- Recipes run unisolated on Windows — the platform offers no cheap, effective sandbox, so the service logs a line saying so and runs them anyway
- The server registers hooks for every installed CLI on start; a CLI the user unticked is unregistered afterwards and comes back on the next `frago server restart`
- Does not install the desktop (Tauri) client or Node.js; agent CLIs are installed only when ticked, and never signed in to
- Hook binary unavailable on platforms without a shipped binary (e.g. linux-aarch64); the CLI still works there
- Resident server binds port 8093; port conflicts require the manual fallback
- `gh auth login` is interactive — the agent hands it to the user rather than answering its prompts
