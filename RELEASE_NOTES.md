## Unreleased — Windows asks where to install

Windows no longer gets a single path. The probe reports how far WSL has got — not installed, installed without a distro, or with one — and the page asks a single question: install into native Windows, or into WSL. With no WSL the page only offers native and says so; with a distro already present it offers both and still recommends native, noting that installing into WSL is equally reasonable once it is there.

Delegation stops being an optional capability. tmux is now a locked, required item on every platform alongside git and uv, because delegating work is what the tool is for, not a preference to opt into. On native Windows that means the winget tmux port (`arndawg.tmux-windows`), which in turn makes Git Bash a hard requirement — tmux panels use it as their default shell, and it arrives with Git for Windows.

The hand-over configuration gains `windows_target` (`native` / `wsl`) on Windows only; macOS and Linux do not carry the field.

### Known limitations

- **The Windows branch still has not been exercised on a real Windows machine.** The WSL three-state check (`wsl.exe -l -q`) is a paper design, and `setup-page.ps1` was already unverified before this change; the new Git Bash check shares that status. A handover todo tracks running the probe on both a Windows machine with a distro and one without.

---

## What's in this release

v0.6.0 moves every decision to the front. Before touching anything, the agent probes the machine with a script shipped in the skill, generates a page from that probe, and lets the user decide once — which CLIs to hook up, what may be installed, whether to set up LightAgent, what happens after. The user pastes one block of configuration back into the chat, and the install runs through without asking again.

## Changed — the page is generated, not shipped

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

## Fixed

- The skill no longer assumes it is running under Claude Code; codex and opencode users get the same flow, and the page names whichever CLI is actually running it.
- Missing dependencies are never installed unattended; the skill installs exactly what the configuration lists and says what stays unavailable.

## Known limitations

- `setup-page.ps1` has not been exercised on a Windows machine yet
- Passing codex's hook-trust gate from tmux has not been exercised end to end yet; the fallback is the user choosing "Trust all" once
- The server registers hooks for every installed CLI on start; a CLI the user unticked is unregistered afterwards and comes back on the next `frago server restart`
- Does not install the desktop (Tauri) client or Node.js; agent CLIs are installed only when ticked, and never signed in to
- Hook binary unavailable on platforms without a shipped binary (e.g. linux-aarch64); the CLI still works there
- Resident server binds port 8093; port conflicts require the manual fallback
- `gh auth login` is interactive — the agent hands it to the user rather than answering its prompts
