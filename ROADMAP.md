# YUTASHELL ROADMAP

> Living document. Each phase ships independently — no phase depends on a later
> one being complete. Philosophy: **Theme-only tokens, UI-kit primitives,
> IPC-driven actions, singleton services, `ShellState.set()` persistence**.
> Every new surface composes `YSurface`; every new button is `YButton`; every
> color comes from `Theme.*`.

Phases 1–3 are complete — see `AGENTS.md` for implementation details and
`README.md` for the feature list.

---

## Phase 1 — AI Desktop Agent

> The single biggest differentiator. No Quickshell shell has deep AI
> integration. YUTA already knows everything about the desktop state —
> pipe that context to an LLM and the shell becomes genuinely intelligent.

### 1.1 AiService Core

**File:** New `modules/ai/AiService.qml` (singleton)

**Plan:**
- Singleton connecting to Ollama (local) or any OpenAI-compatible endpoint.
- HTTP via Process + curl (same pattern as SystemStats): `POST /api/chat`
  with streaming SSE response.
- Model discovery: `GET /api/tags` on boot; expose `models: var` and
  `selectedModel: string`.
- Config in `ShellState`: `aiProvider` ("ollama" | "openai" | "anthropic"),
  `aiEndpoint`, `aiModel`, `aiApiKey` (env var reference, never stored raw).
- Auto-detect Ollama on `localhost:11434` at boot; set `available: true`
  when reachable.
- Streaming: accumulate tokens in `AiService.responseBuffer`; UI binds to
  it for real-time display.
- Expose: `chat(messages, systemPrompt)`, `complete(prompt)`,
  `isRunning: bool`, `responseBuffer: string`, `onCompleted(response)`.

### 1.2 Context Engine

**File:** New `modules/ai/AiContext.qml`

**Plan:**
- Builds a system prompt from live shell state every query:
  ```
  Active window: {appId} "{title}"
  Workspace: {id} ({windowCount} windows)
  Playing: {mpris.trackTitle || "nothing"}
  CPU: {cpuPercent}% | RAM: {memUsed}/{memTotal}
  Time: {datetime} | Weather: {weather.condition} {weather.temp}
  Recent IPC: {recentCommands}
  ```
- Reads from existing singletons: `FocusMonitor`, `SystemStats`,
  `Mpris`, `Weather`, `Session`, `ShellState`.
- Sensitive context (file contents, clipboard, window titles with URLs)
  only included for local models — gate on `aiProvider === "ollama"`.
- `buildContext()` returns the full system string.

### 1.3 Command Palette (AI-Powered)

**File:** New `modules/ai/CommandPalette.qml`

**Plan:**
- `YSurface` overlay opened via `Ctrl+Space` or IPC `ai palette`.
- Input field at top; results below; history accessible via up-arrow.
- Natural language input → AI generates one of:
  - **Hyprland dispatch** (`hl.dsp.*` call) → confirm → execute via
    existing `Hyprland.dispatch()`.
  - **Shell command** → confirm → execute via Process.
  - **IPC call** → confirm → execute via `IpcHandlers`.
  - **Answer** → display as markdown text.
- Tool definitions sent to the LLM:
  ```json
  {
    "tools": [
      {"name": "focus_window", "params": ["class", "address"]},
      {"name": "move_window", "params": ["workspace", "x", "y", "w", "h"]},
      {"name": "toggle_panel", "params": ["target"]},
      {"name": "set_volume", "params": ["percent"]},
      {"name": "run_command", "params": ["command"]},
      {"name": "switch_wallpaper", "params": ["path"]},
      {"name": "set_power_profile", "params": ["profile"]}
    ]
  }
  ```
- Confirmation dialog for every action (safety gate).
- Learning: log accepted commands to `ShellState.aiHistory` for few-shot
  examples in future queries.

### 1.4 Chat Sidebar

**File:** New `modules/ai/ChatSidebar.qml`

**Plan:**
- `YSurface` panel (like MediaWidget) with conversational UI.
- Message bubbles: user (right, faint bg) + assistant (left, bg).
- Markdown rendering: bold, italic, code blocks, lists via QML Text
  with `textFormat: Text.MarkdownText`.
- Code blocks with copy button (`YButton` micro).
- Streaming tokens appended live to the assistant bubble.
- Model selector dropdown at top.
- Clear history button.
- IPC `ai chat` (toggle/open/close).

### 1.5 Voice Input

**File:** New `modules/ai/VoiceInput.qml`

**Plan:**
- Keybind or button triggers recording via PipeWire (default source).
- Save to temp WAV via Process: `pw-record --format=s16le --rate=16000
  /tmp/yuta-voice.wav`.
- Transcribe via `faster-whisper` (local) or `whisper.cpp` Process.
- Inject transcript into Command Palette or Chat input.
- Visual: pulsing mic icon in the command palette during recording.
- Gate on `available`: probe `which faster-whisper` at boot.

### 1.6 Screenshot-to-Action

**File:** New `modules/ai/ScreenshotAction.qml`

**Plan:**
- Keybind captures region via `grim -g "$(slurp)"`.
- Send image to Ollama vision model (`llava`, `bakllava`) as base64.
- AI describes what it sees or answers a follow-up question.
- "What is this code?" → AI reads the screenshot and explains.
- "Fix this error" → AI reads the error message and suggests a command.
- Result shown in Command Palette with action buttons.

**Touches:** `AiService.qml`, `AiContext.qml`, `CommandPalette.qml`,
`ChatSidebar.qml`, `VoiceInput.qml`, `ScreenshotAction.qml` (all new),
`shell.qml`, `ShellState.qml`, `BarActions.qml`, `qmldir`.

---

## Phase 2 — Project Profiles

> One-switch workspace contexts. The desktop equivalent of "workspaces" but
> at a higher level: apps, wallpaper, power, DND, and layout — all bundled.

### 2.1 Profile Service

**File:** New `modules/profiles/ProfileService.qml` (singleton)

**Plan:**
- Profile definition: `{id, name, icon, wallpaper, apps[], rules[],
  powerProfile, dnd, barPreset, nlActive}`.
- Stored in `ShellState.profiles` as a JSON array.
- `apply(profileId)`:
  1. Switch wallpaper via `Wallpaper.apply(profile.wallpaper)`.
  2. Launch apps via `DesktopEntries.byId(id).execute()`.
  3. Apply window rules via `hl.config` (new rules block).
  4. Set power profile via `PowerProfiles.profile`.
  5. Set DND via `NotificationServer`.
  6. Switch bar layout via `BarSegments.loadPreset()`.
  7. Toggle night light.
- `save(profileId)`: snapshot current state (running apps, wallpaper,
  power profile, DND, bar layout) into a new profile.
- `stop(profileId)`: close apps launched by this profile, restore
  previous state.

### 2.2 Profile Picker

**File:** New `modules/profiles/ProfilePicker.qml`

**Plan:**
- `YSurface` panel showing profile cards in a grid.
- Each card: icon + name + active indicator + edit/delete buttons.
- "Save Current" button creates a new profile from live state.
- "Apply" button switches to that profile.
- Drag-to-reorder (reuses the Kanban pattern from Bar settings).
- IPC `profiles list/apply/save`.

### 2.3 Bar Segment + Auto-Switch

**Plan:**
- New bar segment `profiles` showing the active profile name as a chip.
- Click cycles profiles; right-click opens the picker.
- Auto-switch rules: `ShellState.profileRules` maps triggers to profiles:
  - Time-based: "At 9:00 AM, switch to Work profile."
  - Network-based: "When on 'Office-WiFi', switch to Work."
  - Power-based: "When on battery, switch to Mobile profile."
- Rules evaluated by a Timer (60s) + event listeners.

**Touches:** `ProfileService.qml`, `ProfilePicker.qml` (new),
`BarSegments.qml`, `BarActions.qml`, `ShellState.qml`, `qmldir`.

---

## Phase 3 — Automation Rules Engine

> Declarative triggers + actions. "When X happens, do Y." Power user
> superpowers without writing scripts.

### 3.1 Rules Service

**File:** New `modules/automation/RuleService.qml` (singleton)

**Plan:**
- Rule model: `{id, name, trigger, condition?, actions[], enabled}`.
- Trigger types:
  - `time` — cron-like schedule (hour, minute, day-of-week).
  - `battery` — threshold crossed (above/below N%).
  - `network` — connected/disconnected/changed SSID.
  - `bluetooth` — device connected/disconnected.
  - `focusedApp` — specific app gained/lost focus.
  - `idle` — user idle for N seconds.
  - `mpris` — playback started/stopped.
  - `recording` — recording started/stopped.
  - `temperature` — sensor above/below threshold.
- Condition (optional): additional filter (e.g., "AND battery is charging").
- Actions array:
  - `setProfile(id)` — apply a project profile.
  - `setPowerProfile(name)` — switch power plan.
  - `toggleDnd(bool)` — enable/disable DND.
  - `runCommand(cmd)` — execute a shell command.
  - `notify(title, body)` — send a notification.
  - `setWallpaper(path)` — change wallpaper.
  - `togglePanel(target)` — open/close a panel.
  - `setNightLight(bool, temp)` — control night light.
  - `setBarPreset(id)` — switch bar layout.
- Engine: Timer (30s) evaluates time-based rules. Event-driven triggers
  subscribe to existing signals (battery level changes, network events,
  MPRIS state changes, temperature thresholds).

### 3.2 Rules Editor

**File:** New `modules/automation/RuleEditor.qml`

**Plan:**
- `YSurface` panel with a list of rules on the left, detail editor on
  the right (same two-panel pattern as Settings).
- Create/edit/delete rules.
- Trigger selector: dropdown of available trigger types with type-specific
  config fields (e.g., battery trigger → slider for threshold %).
- Action builder: add/remove actions from a dropdown; each action type
  shows its relevant fields.
- Enable/disable toggle per rule.
- "Test" button runs the rule's actions immediately.
- IPC `automation list/enable/disable`.

### 3.3 Built-in Rule Templates

**Plan:**
- Ship 8 starter rules (all disabled by default):
  1. "Low Battery Saver" — battery < 20% → set power saver + DND.
  2. "Work Hours" — 9:00 AM Mon–Fri → apply Work profile.
  3. "Night Mode" — 10:00 PM → enable night light 3500K + DND.
  4. "Gaming Mode" — Steam focused → disable DND + night light +
     hold Performance profile.
  5. "Recording Focus" — recording started → DND + hide bar.
  6. "Presentation" — external monitor connected → presentation mode.
  7. "Thermal Throttle" — CPU > 85°C → notify + switch to balanced.
  8. "Morning Wake" — 7:00 AM → apply Home profile + disable DND +
     random wallpaper.

**Touches:** `RuleService.qml`, `RuleEditor.qml` (new),
`ShellState.qml`, `SettingsPanel.qml`, `qmldir`.

---

## Phase 4 — Developer Command Center

> Everything a developer needs in one surface: git, Docker, CI/CD, logs,
> tmux. No more alt-tabbing between terminal windows.

### 4.1 Git Status Bar Widget

**File:** New `modules/dev/GitService.qml`

**Plan:**
- Reads focused terminal's CWD via `/proc/<pid>/cwd` (detect terminal
  class from `FocusMonitor` active window).
- Runs `git status --porcelain=v2 --branch` via Process (3s refresh,
  gated on terminal focus).
- Exposes: `{branch, ahead, behind, dirty, staged, untracked, remote}`.
- New bar segment `git` showing branch name + dirty count badge.
- Click opens mini-diff popup; right-click shows status details.
- Notifications on upstream divergence (ahead > 0 after pull).

### 4.2 Docker Compose Monitor

**File:** New `modules/dev/DockerService.qml`

**Plan:**
- Singleton running `docker compose ls --format json` (10s refresh).
- Model: `{project, configFiles, status, containers[{name, state, cpu, mem, ports}]}`.
- `YSurface` panel showing projects as cards:
  - Status dot (green=running, red=stopped, yellow=partial).
  - Container list with resource usage.
  - One-click: restart project, view logs (tail -f via Process),
    stop/start individual containers.
- IPC `docker status/restart/logs`.

### 4.3 CI/CD Pipeline Status

**File:** New `modules/dev/CIService.qml`

**Plan:**
- Reads GitHub Actions via `gh run list --json` (60s refresh).
- Model: `{repo, branch, name, status, conclusion, url, createdAt}`.
- Bar segment `cicd` showing checkmark/X/spinner per pinned repo.
- Failure triggers notification with "View" action opening browser.
- Configurable repos in `ShellState.cicdRepos`: `["owner/repo1", ...]`.
- Auto-detect repos from focused terminal's git remote.

### 4.4 Log Tailer

**File:** New `modules/dev/LogTailer.qml`

**Plan:**
- `YSurface` panel with tabbed log views.
- Sources: `journalctl -f -p warning` (system), `hyprland` (via log path),
  Docker containers (per-service), custom `Process` streams.
- Search bar with regex filter; errors highlighted in `Theme.alert`.
- Pin favorite sources (persisted in `ShellState.logPins`).
- Auto-scroll with pause on manual scroll-up.
- IPC `dev logs`.

### 4.5 Tmux/Zellij Dashboard

**File:** New `modules/dev/TmuxService.qml`

**Plan:**
- Reads tmux sessions: `tmux list-sessions -F "#{session_name}:#{session_windows}:#{session_attached}"`.
- Reads zellij sessions: `zellij list-sessions` (if available).
- Model: `{name, windows, attached, via}` (via = "tmux" | "zellij").
- `YSurface` panel showing session cards:
  - Session name + window count + attached indicator.
  - Click to switch: `tmux switch-client -t <name>`.
  - Create new session / kill session buttons.
- Bar segment `tmux` showing active session name + window count.
- Auto-detect which is installed at boot.

### 4.6 Port Scanner & Tunnel Manager

**File:** New `modules/dev/PortService.qml`

**Plan:**
- Reads `ss -tlnp` via Process (15s refresh).
- Model: `{port, address, process, pid, type}` (tcp/udp).
- Filter for non-localhost listeners (exposure warning).
- Create SSH tunnel: form for local port, remote host, remote port.
  Execute via `ssh -L` Process.
- Kill tunnel button (sends SIGTERM to the SSH PID).
- ControlCenter SYSTEM tab integration.

**Touches:** `GitService.qml`, `DockerService.qml`, `CIService.qml`,
`LogTailer.qml`, `TmuxService.qml`, `PortService.qml` (all new),
`BarSegments.qml`, `BarActions.qml`, `ControlCenter.qml`,
`ShellState.qml`, `qmldir`.

---

## Phase 5 — Focus & Wellness

> Productivity isn't just about features — it's about healthy computer use.
> Deep focus mode, break reminders, screen time awareness.

### 5.1 Deep Focus Mode

**File:** New `modules/focus/FocusMode.qml` (singleton)

**Plan:**
- State machine: `idle → focusing → break → longBreak → idle`.
- Configurable: `workMin` (25), `breakMin` (5), `longBreakMin` (15),
  `roundsBeforeLong` (4).
- On focus start:
  - Enable DND via `Notify.dnd = true`.
  - Optionally block distracting apps via window rules (user-configurable
    blocklist in `ShellState.focusBlocklist`: `["discord", "telegram", ...]`).
  - Inhibit idle via `IdleInhibitor`.
  - Start ambient audio (optional, via a second PipeWire node).
- On break: show overlay with stretch/exercise prompts (rotating tips).
- Bar chip: acid when focusing (countdown MM:SS), faint when idle.
- Session stats: `{date, minutesFocused, sessions, longestSession}` logged
  to `~/.local/state/yutashell/focus-history.json`.
- IPC `focus start/pause/resume/reset/status`.

### 5.2 Focus Calendar & Heatmap

**File:** New `modules/focus/FocusCalendar.qml`

**Plan:**
- CalendarGrid (reusing existing component) with day cells colored by
  focus minutes: no data → transparent, < 30m → light acid, < 2h →
  medium acid, 2h+ → full acid.
- Month view with navigation.
- Click a day to see that day's sessions list.
- CC CALENDAR tab extension: "Focus" sub-tab showing the heatmap.
- Stats summary: total this week, current streak, best streak.

### 5.3 Break Overlay

**File:** New `modules/focus/BreakOverlay.qml`

**Plan:**
- `WlrLayershell` surface at `Overlay` layer, fullscreen, transparent bg.
- Shows when focus session ends (break time):
  - Large countdown timer (MM:SS).
  - Rotating health tips: "Look at something 20ft away for 20 seconds",
    "Stretch your shoulders", "Drink water", "Stand up and walk".
  - Optional ambient sound (nature sounds via PipeWire).
- Dismissible after minimum break time (10s).
- Blocks input (exclusion mode) to enforce the break.

### 5.4 Caffeine Toggle (Deep)

**File:** Extend `modules/session/Session.qml`

**Plan:**
- Toggle DND + idle inhibit + hide bar + lock workspace layout.
- Persist `ShellState.caffeineActive`.
- Bar chip: coffee cup icon, glow when active.
- IPC `session caffeine`.

**Touches:** `FocusMode.qml`, `FocusCalendar.qml`, `BreakOverlay.qml`
(all new), `Session.qml`, `BarSegments.qml`, `ControlCenter.qml`,
`ShellState.qml`, `qmldir`.

---

## Phase 6 — Smart System Monitor

> Go beyond basic stats. Battery health, thermal intelligence, power
> budgets, network diagnostics, workspace memory visualization.

### 6.1 Battery Intelligence

**File:** New `modules/system/BatteryService.qml`

**Plan:**
- Read `/sys/class/power_supply/BAT*/{capacity,energy_full,
  energy_full_design,voltage_now,current_now,status,
  charge_control_end_threshold}` via FileView (2s).
- Derived: `healthPct = (full/design)*100`, `wearPct = 100 - healthPct`,
  `timeRemaining = energy / rate` (minutes), `chargeRate` (W).
- Write charge threshold (for ThinkPad/Lenovo): `echo N > .../charge_control_end_threshold`.
- `StatCell bat` enhanced: show time remaining instead of just %.
- CC POWER tab: battery health ring + charge curve sparkline.

### 6.2 Thermal Monitor & Auto-Throttle

**File:** Extend `modules/common/SystemStats.qml`

**Plan:**
- Read thermal zones from `/sys/class/thermal/thermal_zone*/temp` +
  hwmon sensors (already partially done).
- New signals: `thermalWarn(sensor, temp)`, `thermalCrit(sensor, temp)`.
- Auto-action: if any sensor > `tempCrit` for > 10 consecutive seconds,
  switch to power-saver profile and notify.
- Bar segment `cputemp` enhanced: color shifts to `Theme.alert` at warn
  threshold.
- OSD: show temperature warning overlay when throttling activates.

### 6.3 Power Budget Visualizer

**File:** New `modules/system/PowerBudget.qml`

**Plan:**
- Aggregates per-app CPU usage from `top -bn1` (Process, 5s).
- Screen brightness from `/sys/class/backlight/*/brightness`.
- WiFi power save from `iw dev <iface> get power_save`.
- Battery discharge rate from `current_now * voltage_now` (microwatts → mW).
- Render as a treemap or stacked bar in CC SYSTEM tab:
  - Sections: CPU apps, GPU, Screen, WiFi, Other.
  - Highlight "power hogs" (> 5% CPU) with app name.
  - Show estimated battery time based on current draw.

### 6.4 Network Health Monitor

**File:** New `modules/net/NetHealth.qml`

**Plan:**
- Periodic probes (30s):
  - `ping -c1 -W2 1.1.1.1` → latency (ms).
  - `nmcli -t -f IP4.ADDRESS con show <active>` → IP.
  - `wg show wg0` → VPN status.
  - DNS resolution time via `dig +stats example.com | grep "Query time"`.
- Expose: `{latencyMs, ip4, vpnActive, dnsMs, interface, linkSpeed}`.
- Bar chip `net` enhanced: show latency color-coded (< 20ms green,
  < 100ms yellow, > 100ms red).
- Alerts: notify on VPN disconnect, latency spike > 500ms.

### 6.5 Workspace Memory Heatmap

**File:** New `modules/system/WsHeatmap.qml`

**Plan:**
- Query `hyprctl -j workspaces` for window counts and
  `hyprctl -j clients` for per-window size (proxy for memory weight).
- Render as a grid in CC SYSTEM tab: each workspace is a colored cell.
  - Color scale: green (empty) → yellow (1-2 windows) → red (5+).
  - Cell size proportional to window count.
  - Click to switch to that workspace.
- Refresh on workspace change events.

**Touches:** `BatteryService.qml`, `PowerBudget.qml`, `NetHealth.qml`,
`WsHeatmap.qml` (all new), `SystemStats.qml`, `Osd.qml`,
`BarSegments.qml`, `ControlCenter.qml`, `ShellState.qml`, `qmldir`.

---

## Phase 7 — Session Snapshots & Restore

> Save and restore entire desktop states. Disaster recovery meets workflow
> portability.

### 7.1 Snapshot Service

**File:** New `modules/session/SnapshotService.qml` (singleton)

**Plan:**
- `save(name)`: captures current state as JSON:
  ```json
  {
    "name": "pre-refactor",
    "timestamp": 1724800000,
    "wallpaper": "~/.local/state/yutashell/...",
    "powerProfile": "balanced",
    "windows": [
      {"appId": "firefox", "workspace": 1, "floating": false, "title": "..."},
      {"appId": "kitty", "workspace": 1, "cwd": "/home/user/project"}
    ],
    "barLayout": [...],
    "dnd": false,
    "nightLight": false
  }
  ```
- Capture method: `hyprctl -j clients` for window list; `/proc/<pid>/cwd`
  for terminal working directories; `Wallpaper.current` for wallpaper;
  existing singletons for other state.
- `restore(name)`: iterate saved windows, launch via
  `DesktopEntries.byId(id).execute()`, apply workspace rules via
  `hl.config`, set wallpaper, restore bar layout.
- `list()`: return all saved snapshots.
- `delete(name)`: remove a snapshot.
- Storage: `~/.local/state/yutashell/snapshots/<name>.json`.

### 7.2 Snapshot Picker

**File:** New `modules/session/SnapshotPicker.qml`

**Plan:**
- `YSurface` panel showing snapshot cards:
  - Name + timestamp + window count + wallpaper thumbnail.
  - "Restore" button → confirmation dialog → restore.
  - "Overwrite" button → save current state over this snapshot.
  - "Delete" button → remove.
- "Save New" button at top with name input field.
- Auto-snapshots: optional Timer (every 30 minutes) saves to
  `ShellState.snapshotAuto` slot. Only keep last 3.
- IPC `snapshots list/save/restore/delete`.

### 7.3 Bar Segment

**Plan:**
- New bar segment `snapshots` showing a save icon + count.
- Click saves a quick snapshot (auto-named by timestamp).
- Right-click opens the snapshot picker.
- Notification on successful save/restore.

**Touches:** `SnapshotService.qml`, `SnapshotPicker.qml` (new),
`BarSegments.qml`, `BarActions.qml`, `Session.qml`,
`ShellState.qml`, `qmldir`.

---

## Phase 8 — Visual Workspace Intelligence

> Make workspaces visual, spatial, and informative. Users think in spatial
> terms, not numbered lists.

### 8.1 Workspace Heatmap Overlay

**File:** New `modules/overview/WsHeatmap.qml`

**Plan:**
- Full overview mode: replace the current window-grid overview with a
  two-level view:
  - Level 1: workspace grid (3×2 or user-defined) with mini heatmaps.
    Each cell shows workspace number + colored dots for windows + memory
    usage bar.
  - Level 2: click a workspace to zoom into its window grid (current
    OverviewGrid behavior).
- Transition: smooth zoom animation between levels.
- Keyboard: arrow keys navigate workspaces, Enter zooms in, Escape zooms
  out.

### 8.2 Named Workspaces

**File:** Extend `modules/bar/Workspaces.qml`

**Plan:**
- `ShellState.wsNames`: JSON map `{1: "Code", 2: "Comms", 3: "Media", ...}`.
- Bar segment shows names instead of numbers when `wsMode === "names"`.
- New mode alongside default/numbers/pills/active/thumbnails.
- Overview shows workspace names in the grid cells.
- IPC `bar wsname <id> <name>` to assign names.

### 8.3 Cross-Monitor Workspace Awareness

**File:** New `modules/overview/MonitorAwareness.qml`

**Plan:**
- Visual representation of all monitors with their current workspaces.
- Each monitor card shows: name, resolution, scale, active workspace
  number/name, window count.
- Click to focus that monitor.
- Drag workspaces between monitors (dispatch `window.move` +
  `focusmonitor`).
- CC MONITORS tab enhancement: replace the bare DDC slider with a
  visual layout.

### 8.4 Workspace Memory Usage Bars

**File:** Extend `modules/overview/OverviewGrid.qml`

**Plan:**
- Per-workspace: show total RSS of windows on that workspace.
- Data from `/proc/<pid>/status` VmRSS for each window's PID.
- Color-coded bar at the bottom of each workspace cell in overview.
- Helps identify memory-heavy workspaces at a glance.

**Touches:** `WsHeatmap.qml`, `MonitorAwareness.qml` (new),
`Workspaces.qml`, `OverviewGrid.qml`, `ControlCenter.qml`,
`BarSegments.qml`, `ShellState.qml`.

---

## Phase 9 — Plugin Marketplace & Theme Store

> Build the ecosystem. Community plugins and themes drive adoption.

### 9.1 Plugin Registry

**File:** New `modules/plugins/PluginRegistry.qml`

**Plan:**
- Fetches plugin catalog from a GitHub-hosted `registry.json`:
  ```json
  {
    "plugins": [
      {
        "id": "spotify-player",
        "name": "Spotify Player",
        "description": "Full Spotify controls with search",
        "author": "community",
        "version": "1.0.0",
        "type": "bar",
        "download": "https://github.com/...",
        "screenshot": "https://...",
        "tags": ["media", "music"],
        "installs": 142
      }
    ]
  }
  ```
- Cache catalog locally (1h refresh via Timer).
- Settings page: browse by category (media, system, productivity,
  dev), search, sort by popularity/recent.
- One-click install: download tarball to `~/.config/quickshell/plugins/<id>/`.
  Hot-reload detects the new plugin automatically.
- Update checker: compare installed version vs registry version.
- Uninstall: delete plugin directory.
- **Permissions:** each plugin declares required permissions in manifest
  (Process, FileView, Hyprland dispatch, network). Shown to user on
  install. Enforced by PluginService at load time.

### 9.2 Theme Store

**File:** New `modules/themes/ThemeStore.qml`

**Plan:**
- Fetches theme catalog from a separate GitHub-hosted `themes.json`.
- Each theme: `{id, name, author, colors{bg,fg,acid,...}, previewUrl,
  schemeJson}`.
- Browse in settings APPEARANCE tab: grid of preview cards.
- "Preview" button: temporarily applies the scheme (reverts on cancel).
- "Install" button: saves scheme JSON to `theme/schemes/<id>.json`,
  adds to the scheme list.
- "Set as Default" applies immediately via `Theme.setScheme(id)`.
- Community contributions via PRs to the themes repo.

### 9.3 In-Shell Auto-Update

**Plan:**
- On boot (after warm-up), check if the shell itself has a new version:
  `git -C <shellDir> fetch && git -C <shellDir> rev-list HEAD..origin/main
  --count`.
- If > 0: notification with "Update available" + "View changes" button.
- No auto-update (user decides when to `git pull`); the notification is
  informational only.
- Version from `README.md` header or a dedicated `VERSION` file.

**Touches:** `PluginRegistry.qml`, `ThemeStore.qml` (new),
`PluginService.qml`, `SettingsPanel.qml`, `AppearancePage.qml`,
`ShellState.qml`, `qmldir`.

---

## Phase 10 — Context Engine & Ambient Intelligence

> The shell should adapt to the user, not the other way around. Time,
> location, activity, patterns — the shell should "just know."

### 10.1 Context Service

**File:** New `modules/context/ContextService.qml` (singleton)

**Plan:**
- Aggregates context signals into a unified state:
  ```
  timeOfDay: "morning" | "afternoon" | "evening" | "night"
  dayOfWeek: "weekday" | "weekend"
  location: "home" | "office" | "mobile" | "unknown"
  activity: "focused" | "browsing" | "media" | "idle" | "gaming"
  batteryState: "charging" | "discharging" | "full"
  networkType: "wifi" | "wired" | "vpn" | "offline"
  ```
- Location inference: from active WiFi SSID (map SSIDs to locations in
  `ShellState.locationMap`: `{"Home-WiFi": "home", "Office-WiFi": "office"}`).
- Activity inference: from focused app category (from desktop entries),
  MPRIS state, active window type.
- Time: from system clock.

### 10.2 Adaptive Behaviors

**File:** New `modules/context/AdaptiveEngine.qml`

**Plan:**
- Rules mapping context → shell behavior:
  - `"morning" + "home"` → apply Home profile, random wallpaper, disable DND.
  - `"night"` → enable night light, dim OSD, enable DND.
  - `"focused"` + weekday → auto-apply Work profile, hide non-essential
    bar segments.
  - `"gaming"` → disable all OSD, hide bar, inhibit idle, hold Performance.
  - `"mobile"` (battery discharging + wifi) → compact bar, disable
    notifications from non-critical apps, lower poll rates.
  - `"idle" > 10min` → dim screen, reduce bar poll rates.
- Rules stored in `ShellState.adaptiveRules` (user-editable).
- Engine evaluates on every context change (debounced 5s).

### 10.3 Proactive Suggestions

**File:** Extend `modules/context/AdaptiveEngine.qml`

**Plan:**
- Passive suggestions surfaced as subtle bar chips or toast notifications:
  - "You usually start working now. Apply Work profile?" (time pattern).
  - "Battery is low and you're not plugged in. Switch to Power Saver?"
  - "You've been focused for 2 hours. Time for a break?"
  - "You always open Slack + Firefox on workspace 2. Pin them?"
- Suggestions are non-intrusive: micro-chip in the bar that fades after
  10s or on dismiss. Never blocks input.
- Learning: track accepted/rejected suggestions to improve accuracy.
- Persist in `ShellState.contextPatterns`: `{time → lastApps}`,
  `{location → profiles}`, etc.

### 10.4 Pattern Learning

**File:** Extend `modules/context/ContextService.qml`

**Plan:**
- Observe and record:
  - App launch sequences (what apps are opened together).
  - Time-based routines (what happens at what time).
  - Location-based routines (what changes per location).
  - Workspace usage patterns (which workspaces for which tasks).
- Data stored in `~/.local/state/yutashell/patterns.json` (rolling
  30-day window, privacy-first: all local, no cloud).
- Pattern detection: if the same 3+ apps are launched within 5 minutes
  on 5+ occasions → suggest as a profile.
- If the same wallpaper is used during "focused" activity → suggest
  as the focus wallpaper.

### 10.5 Ambient Display

**File:** New `modules/context/AmbientDisplay.qml`

**Plan:**
- On idle (configurable delay), show a minimal ambient overlay:
  - Large clock (analog or digital, user's choice).
  - Current weather + temperature.
  - Next calendar event (if integrated).
  - Currently playing track.
- `WlrLayershell` surface at `Bottom` layer, behind windows.
- Fades in with `movDrift` (2.6s), dismisses on any input.
- Respects `Theme.reducedMotion` (instant show/hide if true).
- Gate on `ShellState.ambientEnabled` and not-in-game (detect fullscreen
  windows).

**Touches:** `ContextService.qml`, `AdaptiveEngine.qml`,
`AmbientDisplay.qml` (all new), `ShellState.qml`, `BarSegments.qml`,
`SettingsPanel.qml`, `qmldir`.

---

## Phase 11 — Gaming & Streaming

> Game detection, auto-configuration, OBS integration, replay buffer,
> streaming controls. The shell adapts to gaming, not the other way around.

### 11.1 Game Detector & GameMode

**File:** New `modules/gaming/GameDetector.qml` (singleton)

**Plan:**
- Detect games from focused window: `appId.startsWith("steam_app_")`
  || `appId.startsWith("wine-")` || known game list.
- On game launch:
  - Activate Feral GameMode via D-Bus (`org.feralinteractive.GameMode`).
  - Apply Hyprland rules: `render_unfocused` (fixes UE4/5 disconnect
    bug), disable blur, optionally move to dedicated workspace.
  - Switch RGB profile via OpenRGB (if available).
  - Pause break reminders (Phase 5).
  - Hold Performance power profile.
  - Increase GPU polling rate.
- On game exit: restore all defaults.
- Expose: `gameRunning: bool`, `activeGame: string`, `gameModeActive: bool`.
- Gate GameMode on `busctl call org.feralinteractive.GameMode` probe.

### 11.2 OBS WebSocket Controller

**File:** New `modules/gaming/ObsController.qml` (singleton)

**Plan:**
- Connect to OBS WebSocket v5 (port 4455, built into OBS 28+).
- Auto-reconnect with exponential backoff.
- Expose: `connected`, `streaming`, `recording`, `currentScene`,
  `scenes[]`, `streamDuration`, `cpuUsage`, `fps`.
- Functions: `toggleStream()`, `toggleRecord()`, `switchScene(name)`,
  `muteToggle()`, `setVolume(source, level)`.
- Bar segment `streaming`: shows OBS status (disconnected/streaming/
  recording) with duration. Click toggles stream. Right-click opens
  scene picker.
- CC extension: streaming tab with scene grid, audio mixer, status.

### 11.3 Replay Buffer

**File:** New `modules/gaming/ReplayBuffer.qml`

**Plan:**
- Persistent `gpu-screen-recorder -r 120` process (2-minute ring buffer).
- "Save Clip" button (bar chip or keybind) sends `SIGUSR1` to dump.
- Notification: "Clip saved to ~/Videos/Replays/".
- Gate on `Recording.active` (don't run alongside manual recording).
- Configurable buffer length in `ShellState.replayBufferSec` (30–300).

### 11.4 Game Session Analytics

**File:** Extend `modules/focus/FocusMode.qml`

**Plan:**
- Log game sessions: `{game, start, end, duration}` to
  `~/.local/state/yutashell/gaming-sessions.json`.
- Stats: total time per game, daily gaming time, weekly summary.
- Bar chip in `session` segment shows today's gaming time when a game
  was played.
- Integrate with Focus heatmap (Phase 5.2): gaming sessions shown in
  a different color.

### 11.5 MangoHud Integration

**File:** New `modules/gaming/MangoHud.qml`

**Plan:**
- On game launch: inject `MANGOHUD=1` env var (or `--mangohud` flag).
- Read MangoHud config from `~/.config/MangoHud/MangoHud.conf`.
- Bar chip shows live FPS when a game is running (read from
  `/tmp/mangohud_<pid>.log` or MangoHud's D-Bus interface if available).
- Settings: per-game MangoHud presets (off/compact/full) in GAME
  settings page.

**Touches:** `GameDetector.qml`, `ObsController.qml`, `ReplayBuffer.qml`,
`MangoHud.qml` (all new), `FocusMode.qml`, `BarSegments.qml`,
`BarActions.qml`, `ControlCenter.qml`, `ShellState.qml`, `qmldir`.

---

## Phase 12 — Smart Home Control

> Home Assistant, MQTT, Zigbee/Z-Wave — control your physical environment
> from the same shell that controls your digital one.

### 12.1 Home Assistant Service

**File:** New `modules/smarthome/HomeAssistant.qml` (singleton)

**Plan:**
- Connect to Home Assistant REST API (port 8123).
- Auth: long-lived access token stored in `ShellState.haToken` (or
  env var `HASS_TOKEN`).
- Boot probe: `GET /api/` to check availability.
- Expose: `available: bool`, `entities[]`, `states{}`.
- Entity model: `{id, state, attributes{friendly_name, icon, device_class,
  unit_of_measurement}}`.
- Polling: 30s Timer for state updates; WebSocket subscription for
  real-time (if `QtWebSockets` available).

### 12.2 Device Control UI

**File:** New `modules/smarthome/DevicePanel.qml`

**Plan:**
- `YSurface` panel with rooms as tabs (derived from HA `area_id`).
- Per-room device cards:
  - Lights: toggle + brightness slider + color picker (HS wheel).
  - Switches: toggle on/off.
  - Climate: temperature setpoint + mode (heat/cool/auto).
  - Media players: play/pause + volume.
  - Sensors: read-only display (temp, humidity, motion).
  - Covers: open/close/stop + position slider.
- All control calls `POST /api/services/<domain>/<service>` with
  `{"entity_id": "light.living_room", "brightness": 128}`.
- IPC `smarthome toggle/dim/set`.

### 12.3 Bar Segment + Quick Controls

**Plan:**
- New bar segment `smarthome` showing:
  - Icon for most-active device (light on = bulb icon).
  - Climate temperature if thermostat is in "home" area.
  - Click opens `DevicePanel`.
  - Scroll on bar adjusts most-recent light brightness.
- Quick toggles: pin favorite devices to bar as micro-chips
  (e.g., "Living Room Light" toggle).

### 12.4 MQTT Bridge (Optional)

**File:** New `modules/smarthome/MqttBridge.qml`

**Plan:**
- For users without Home Assistant: direct MQTT via `mosquitto_sub`/
  `mosquitto_pub` (Process-based).
- Subscribe to topics: `home/sensor/#`, `home/+/state`.
- Publish commands: `home/light/office/set` → `{"brightness": 200}`.
- Config: `ShellState.mqttBroker` (host, port, topic prefix).
- Discovery: subscribe to `homeassistant/+/config` for auto-discovered
  devices (HA MQTT discovery format).

### 12.5 Automation Triggers (Phase 3 Extension)

**Plan:**
- New trigger type for Phase 3 rules engine: `smarthome`.
  - Condition: entity state equals/contains value.
  - Action: call HA service.
- Example: "When motion sensor triggers after 11 PM, turn on hallway
  light at 20% and send notification."
- Bidirectional: HA automations can trigger YUTA shell actions via
  `qs ipc call` (external process).

**Touches:** `HomeAssistant.qml`, `DevicePanel.qml`, `MqttBridge.qml`
(all new), `BarSegments.qml`, `BarActions.qml`, `ShellState.qml`,
`RuleService.qml` (Phase 3 extension), `qmldir`.

---

## Phase 13 — Phone Companion

> KDE Connect integration: phone notifications, battery, clipboard sync,
> remote commands, find-my-phone. Your phone and desktop, unified.

### 13.1 KDE Connect Service

**File:** New `modules/companion/PhoneService.qml` (singleton)

**Plan:**
- Probe: `which kdeconnect-cli` at boot; set `available: bool`.
- Poll: `kdeconnect-cli -l --refresh` (10s) for device list.
- Model: `{id, name, type, paired, connected, batteryPct,
  charging, lastSeen}`.
- Events via D-Bus subscription (`org.kde.kdeconnect.device` signals):
  battery changes, notification received, clipboard received, ringer
  triggered.

### 13.2 Phone Status Bar

**Plan:**
- New bar segment `phone` showing:
  - Phone icon (connected/disconnected).
  - Battery percentage + charging indicator.
  - Missed notification count badge.
  - Click opens `PhonePanel`.

### 13.3 Notification Relay

**Plan:**
- Mirror phone notifications to YUTA's notification server.
- When phone receives a notification: create a YUTA toast with the
  phone's app icon, title, and body.
- Inline reply: text input on the toast → `kdeconnect-cli -d <id>
  --send-sms "reply" --destination "<number>"`.
- Action buttons: "Open on Phone" (sends URL), "Dismiss" (dismisses
  on phone).

### 13.4 Clipboard Sync

**Plan:**
- Bidirectional clipboard sync between phone and desktop.
- On desktop clipboard change (from Phase 1.1 `ClipboardService`):
  `kdeconnect-cli -d <id> --share-text "$(wl-paste)"`.
- On phone clipboard change (D-Bus event): `wl-copy "$(kdeconnect-cli
  -d <id> --receive-text)"`.
- Gate: `ShellState.phoneClipSync` toggle (default false for privacy).

### 13.5 Remote Commands & Find My Phone

**Plan:**
- Remote commands: `ShellState.phoneCommands` stores
  `{name, command}` pairs. Execute via `kdeconnect-cli -d <id>
  --run-command <name>`.
- Find my phone: `kdeconnect-cli -d <id> --ring` → phone plays a loud
  ringtone. Bar button + IPC `phone find`.
- Remote input: optional mouse/keyboard forwarding (KDE Connect's
  remote input plugin).

### 13.6 Device Panel

**File:** New `modules/companion/PhonePanel.qml`

**Plan:**
- `YSurface` panel showing connected phone(s).
- Per-device card: name, battery ring, connection status.
- Sections:
  - **Notifications**: recent phone notifications list with reply.
  - **Clipboard**: last synced clipboard entry.
  - **Media**: phone's current media (if MPRIS-compatible).
  - **Actions**: Find my phone, share URL, send file.
  - **Commands**: list of remote commands.
- IPC `phone toggle/open/close`.

**Touches:** `PhoneService.qml`, `PhonePanel.qml` (new),
`ClipboardService.qml` (extension), `BarSegments.qml`,
`BarActions.qml`, `ShellState.qml`, `qmldir`.

---

## Phase 14 — Security Dashboard

> Privacy auditing, firewall management, open port visibility, VPN
> health — know your system's security posture at a glance.

### 14.1 Security Service

**File:** New `modules/security/SecurityService.qml` (singleton)

**Plan:**
- Boot probes (one-shot, staggered):
  - `ufw status` or `firewall-cmd --state` → firewall available + active.
  - `lynis audit system --quick --quiet` → security score (Process, 30s).
  - `wg show` → VPN active peers + handshake timestamps.
- Periodic (5min): re-check firewall status, VPN handshake freshness.
- Expose: `firewallActive: bool`, `firewallStatus: string`,
  `securityScore: int` (0-100 from lynis), `vpnActive: bool`,
  `vpnPeers[]`, `openPorts[]`.

### 14.2 Firewall Manager

**File:** New `modules/security/FirewallPanel.qml`

**Plan:**
- `YSurface` panel showing:
  - Status banner: active/inactive with toggle.
  - Active rules table: port, protocol, action, source, comment.
  - "Add Rule" form: port field, protocol dropdown, action toggle,
    source field.
  - Delete button per rule.
- All operations via `ufw` Process calls (with `sudo` prompt via
  PolkitDialog).
- History of recent changes (persisted in `ShellState.firewallLog`).

### 14.3 Open Port Monitor

**File:** New `modules/security/PortMonitor.qml`

**Plan:**
- Read `ss -tlnp` + `ss -ulnp` (15s refresh, reuses Phase 4.6 pattern).
- Filter: show only non-localhost listeners (external exposure).
- Color-coded: green (expected service), yellow (unknown), red
  (dangerous port open).
- Known ports database: map common ports to services (80=HTTP, 443=HTTPS,
  22=SSH, 3306=MySQL, etc.).
- Click to add firewall rule to block an exposed port.
- Integrate with CC SECURITY tab.

### 14.4 VPN Health Monitor

**File:** Extend `modules/net/Connectivity.qml`

**Plan:**
- Read `wg show` via Process (30s): handshake timestamp per peer.
- If handshake > 180s old: "VPN stale" warning.
- If `wg0` interface missing: "VPN down" alert.
- Bar chip `net` shows VPN indicator: shield icon (green = connected,
  yellow = stale, red = down, hidden = no VPN).
- Auto-reconnect: `wg-quick up wg0` if interface drops (configurable
  via `ShellState.vpnAutoReconnect`).

### 14.5 Security Score Display

**Plan:**
- Lynis security score (0-100) displayed in CC SECURITY tab as a
  ring gauge.
- Breakdown: list of passed/failed/warning tests.
- "Rescan" button triggers a fresh `lynis` audit.
- History: track score over time, show trend line (YSpark).
- Bar chip: shield icon with score number (color: green > 80,
  yellow > 60, red ≤ 60).

### 14.6 Login Audit Log

**Plan:**
- Read `last -n 20` via Process for recent logins.
- Read `journalctl _SYSTEMD_UNIT=sshd.service -n 10` for SSH attempts.
- Display in CC SECURITY tab: recent logins with user, IP, time.
- Failed SSH attempts highlighted in `Theme.alert`.
- Gate on availability (not all systems have sshd).

**Touches:** `SecurityService.qml`, `FirewallPanel.qml`,
`PortMonitor.qml` (all new), `Connectivity.qml`, `ControlCenter.qml`,
`BarSegments.qml`, `ShellState.qml`, `qmldir`.

---

## Phase 15 — File Intelligence

> Beyond file browsing: intelligent search, duplicate detection,
> sync status, quick actions on the filesystem.

### 15.1 File Search Service

**File:** New `modules/files/FileSearch.qml` (singleton)

**Plan:**
- Indexed search via `fd` (if installed) or `find` fallback.
- Index: scan `~/` (maxdepth 4, skip `.cache`, `.local/share/Trash`)
  on boot and every 10 minutes.
- Model: `{path, name, ext, size, mtime, mime}`.
- Search: fuzzy match on filename + path.
- IPC `files search <query>`.

### 15.2 File Picker Panel

**File:** New `modules/files/FilePicker.qml`

**Plan:**
- `YSurface` panel with search bar + results list.
- Each result: icon (from mime type), filename, path, size, date.
- Actions on each file:
  - Open: `xdg-open <path>`.
  - Copy path: `wl-copy <path>`.
  - Copy file: `wl-copy --type=... < <path>` (for text) or `cp` to
    clipboard temp dir.
  - Show in file manager: `xdg-open <parent_dir>`.
  - Delete: move to trash via `gio trash <path>`.
- Recent files section at top (from xdg-recent).
- Pinned/starred files (persisted in `ShellState.pinnedFiles`).

### 15.3 Duplicate Finder

**File:** New `modules/files/DuplicateFinder.qml`

**Plan:**
- Scan for duplicates using file size pre-filter → MD5 hash comparison.
- Algorithm: group by size → hash first 4KB → hash full file for
  collisions. Process-based (runs in background, non-blocking).
- Results: groups of duplicate files with size, count, total wasted.
- Actions: keep newest / keep oldest / manual select / move duplicates
  to trash.
- Gate: opt-in scan (CPU-intensive for large directories).
- Store last scan results in `~/.local/state/yutashell/duplicates.json`.

### 15.4 Storage Visualizer

**File:** New `modules/files/StorageViz.qml`

**Plan:**
- Treemap visualization of disk usage by directory.
- Data: `du -b --maxdepth=2 ~/` (Process, 5s).
- Render as nested rectangles using QML Canvas or Shape, sized by
  directory size, colored by type (code=acid, media=purple, docs=blue,
  other=faint).
- Click to drill down; breadcrumb navigation at top.
- Hover shows: path, size, file count.
- Gate on `Theme.reducedMotion` (instant render if true).

### 15.5 Quick File Actions

**Plan:**
- Global shortcut or launcher prefix (`/`): show recent files + pinned.
- Type a filename to search.
- Enter on a file opens it; Shift+Enter copies the path.
- Integration with launcher: `/path/to/file` in launcher
  opens the file directly.

**Touches:** `FileSearch.qml`, `FilePicker.qml`, `DuplicateFinder.qml`,
`StorageViz.qml` (all new), `AppLauncher.qml` (extension),
`ShellState.qml`, `qmldir`.

---

## Phase 16 — Hardware Control

> Fan curves, RGB lighting, keyboard backlight, GPU clocks — direct
> hardware control from the shell. Power user territory.

### 16.1 GPU Service

**File:** New `modules/hardware/GpuService.qml` (singleton)

**Plan:**
- Unified GPU monitor (extends SystemStats GPU data):
  - NVIDIA: `nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,
    fan.speed,power.draw,memory.used,memory.total --format=csv,noheader,nounits`.
  - AMD: read from `/sys/class/drm/card*/device/hwmon/hwmon*/` files.
- Expose: `temperature`, `utilization`, `fanSpeed`, `powerDraw`,
  `vramUsed`, `vramTotal`, `gpuType: "nvidia" | "amd" | "intel" | "none"`.
- Boot probe: try nvidia-smi first, fall back to sysfs.
- Fan control (if supported): write to hwmon `pwm1` (AMD) or NVML
  (NVIDIA, requires root).
- Bar segment `gpu` showing temp + utilization + fan %.

### 16.2 Fan Curve Editor

**File:** New `modules/hardware/FanCurveEditor.qml`

**Plan:**
- `YSurface` panel with a visual fan curve editor.
- Canvas-based temperature → fan speed graph with draggable control
  points.
- Presets: "Silent" (low fan until 80°C), "Balanced" (linear 40-90°C),
  "Aggressive" (fast ramp at 60°C), "Custom".
- Apply button writes the curve to hwmon.
- Live preview: show current temp as a dot on the curve.
- Gate: only shown when `GpuService.fanControlAvailable`.

### 16.3 OpenRGB Controller

**File:** New `modules/hardware/RgbService.qml` (singleton)

**Plan:**
- Probe: `openrgb --server status` at boot.
- Expose: `available`, `devices[]`, `currentProfile: string`.
- Functions: `applyProfile(name)`, `setDeviceColor(device, color)`,
  `setMode(device, mode)`.
- Per-game profiles: subscribe to `GameDetector.gameRunningChanged`.
  Desktop profile → game profile → back to desktop.
- Audio-reactive mode: read peaks from `AudioService.peakMonitor`,
  map to keyboard LED colors.
- Bar chip `rgb`: shows current profile name. Click cycles profiles.

### 16.4 Keyboard Backlight Control

**File:** New `modules/hardware/KeyboardBacklight.qml`

**Plan:**
- Read/write `/sys/class/leds/*/brightness` via FileView.
- Expose: `level: int`, `maxLevel: int`, `available: bool`.
- OSD on brightness change (like display brightness OSD).
- Bar chip: keyboard icon with brightness indicator.
- Auto-dim on idle (configurable delay).

### 16.5 Hardware Monitor Panel

**File:** New `modules/hardware/HardwarePanel.qml`

**Plan:**
- `YSurface` panel with tabs: GPU, Fans, RGB, Keyboard.
- GPU tab: temperature gauge, utilization bar, VRAM usage, power draw,
  fan speed ring.
- Fans tab: current RPM per fan, fan curve editor, manual override
  toggle.
- RGB tab: device list, color picker, mode selector, profile switcher.
- Keyboard tab: brightness slider, auto-dim toggle.
- IPC `hardware gpu/fans/rgb/keyboard`.

**Touches:** `GpuService.qml`, `FanCurveEditor.qml`, `RgbService.qml`,
`KeyboardBacklight.qml`, `HardwarePanel.qml` (all new),
`BarSegments.qml`, `BarActions.qml`, `ShellState.qml`, `qmldir`.

---

## Phase 17 — Ergonomics & Health

> Beyond break reminders: posture tracking, eye care, work-life balance,
> screen time analytics. The shell cares about the human using it.

### 17.1 Break Reminder (Enhanced)

**File:** New `modules/health/BreakReminder.qml` (singleton)

**Plan:**
- Extends Phase 5 with ergonomic-specific features:
  - **20-20-20 rule**: every 20 minutes, look at something 20 feet
    away for 20 seconds. Overlay shows a distant landscape image.
  - **Posture alert**: after 45 minutes of sitting, prompt to stand.
    Optional: if a posture sensor (USB device) is connected, read
    data and alert on slouching.
  - **Hydration reminder**: configurable interval (default 60 min).
  - **Stretching routines**: rotating prompts with illustrations
    (simple QML shapes, no images needed).
- Defer during: games, meetings (mic active), DND mode.
- Persist all break data for analytics.

### 17.2 Screen Time Analytics

**File:** New `modules/health/ScreenTimeAnalytics.qml`

**Plan:**
- Track per-app foreground time (already partially done in Phase 9.4).
- Extend with:
  - Per-workspace time breakdown.
  - Category aggregation (social, dev, media, gaming, other).
  - Daily/weekly/monthly charts.
  - "Digital wellbeing" summary: total screen time, most-used app,
    longest session, breaks taken vs skipped.
- Visual: bar chart per day (stacked by category) in a `YSurface`
  panel.
- Insights: "You spent 3h on Discord yesterday, up 40% from last week."
- Gate: `ShellState.screenTimeEnabled` (opt-in, privacy-first).

### 17.3 Work-Life Balance Indicator

**File:** New `modules/health/WorkLifeIndicator.qml`

**Plan:**
- Simple bar chip showing work status:
  - **Working**: weekday, 9-17, focused apps open → green.
  - **Overtime**: past 17:00 with work apps still open → yellow.
  - **Break needed**: no breaks in > 2 hours → amber pulse.
  - **Off**: weekend or evening with no work apps → faint.
- Configurable work hours in `ShellState.workHours`:
  `{start: "09:00", end: "17:00", days: [1,2,3,4,5]}`.
- Click shows today's summary: work time, break time, focus score.
- Optional: notification at end of workday ("Time to log off?").

### 17.4 Ergonomic Settings Page

**File:** New `modules/settings/ErgonomicsPage.qml`

**Plan:**
- Settings page in SYSTEM group:
  - Break interval slider (15–90 min).
  - Micro-break duration (10–60 sec).
  - Posture reminder toggle + interval.
  - Hydration reminder toggle + interval.
  - Work hours configuration.
  - Screen time tracking toggle.
  - Break overlay customization (text tips vs images vs minimal).
  - Gaming/meeting defer toggles.

### 17.5 Health Dashboard

**File:** New `modules/health/HealthDashboard.qml`

**Plan:**
- `YSurface` panel aggregating all health data:
  - Today's screen time ring (target vs actual).
  - Break compliance (taken / due).
  - Current streak (consecutive days meeting break goals).
  - Per-app time breakdown (top 5).
  - Work-life balance indicator.
- Weekly report summary at the top.
- Motivational messages based on performance.

**Touches:** `BreakReminder.qml`, `ScreenTimeAnalytics.qml`,
`WorkLifeIndicator.qml`, `HealthDashboard.qml`, `ErgonomicsPage.qml`
(all new), `FocusMode.qml` (integration), `BarSegments.qml`,
`ShellState.qml`, `qmldir`.

---

## Phase 18 — Cross-Device Sync

> Syncthing integration, clipboard sharing, file transfer between
> desktop and other devices. One unified file ecosystem.

### 18.1 Syncthing Service

**File:** New `modules/sync/SyncthingService.qml` (singleton)

**Plan:**
- Connect to Syncthing REST API (port 8384).
- Auth: API key from `ShellState.syncthingApiKey` (or env var).
- Boot probe: `GET /rest/system/status`.
- Expose: `available`, `folders[]`, `devices[]`, `globalState{}`
  (total files, needed, progress).
- Model per folder: `{id, label, path, paused, globalFiles,
  localFiles, needFiles}`.
- Model per device: `{id, name, type, paused, connected,
  lastSeen}`.

### 18.2 Sync Status Bar

**Plan:**
- New bar segment `sync` showing:
  - Sync icon (green = up to date, yellow = syncing, red = error).
  - Count of files needing sync.
  - Click opens `SyncPanel`.
- Notifications on: new device request, folder sync error, completed
  large sync.

### 18.3 Sync Panel

**File:** New `modules/sync/SyncPanel.qml`

**Plan:**
- `YSurface` panel with two tabs: Folders, Devices.
- Folders: list with status, file counts, pause/resume toggle,
  browse button (opens file manager).
- Devices: list with connection status, last seen, address.
- "Share Folder" action: select folder + target device, create via
  API.
- "Pause All" global toggle.
- Error display with retry button.

### 18.4 LocalSend Integration

**File:** New `modules/sync/LocalSend.qml`

**Plan:**
- Probe: `which localsend` or check port 53317.
- On local clipboard image: offer "Send to device" action on
  notification toast.
- Discovery: `GET http://localhost:53317/api/v2/neighbors` for
  visible devices.
- Send file: `POST http://<device>:53317/api/v2/upload` with multipart.
- Simple send UI: select device from discovered list → send.

### 18.5 Sync Automation

**Plan:**
- Trigger: Phase 3 automation rules can use Syncthing state as a
  condition (folder paused, device disconnected).
- Auto-pause sync during gaming (save bandwidth).
- Auto-resume on work profile activation.

**Touches:** `SyncthingService.qml`, `SyncPanel.qml`, `LocalSend.qml`
(all new), `BarSegments.qml`, `BarActions.qml`, `ShellState.qml`,
`RuleService.qml` (Phase 3 extension), `qmldir`.

---

## Phase 19 — Notification Intelligence (Advanced)

> Beyond early notification features: smart triage, VIP contacts, digest
> batching, notification analytics, per-channel rules.

### 19.1 Smart Triage

**File:** New `modules/notify/NotificationTriage.qml`

**Plan:**
- Classify incoming notifications by priority:
  - **VIP**: from user-defined contacts (by name or phone number in
    the notification body). Always break through DND.
  - **Important**: from messaging apps with direct messages (not
    group chats). Normal priority.
  - **Informational**: from news, social media, system. Low priority.
  - **Spam**: > 5 notifications from same app in 2 minutes → auto-snooze
    that app for 10 minutes.
- Rules configurable per app: `ShellState.notifyPriority` map:
  `{"Signal": "vip", "Twitter": "spam", "Slack": "important"}`.
- VIP detection: match notification body against
  `ShellState.vipContacts[]` (names/numbers).

### 19.2 Digest Batching

**File:** Extend `modules/notify/Notify.qml`

**Plan:**
- For "informational" priority notifications: batch into hourly digests.
- Timer collects notifications; at the hour mark, send one summary
  notification: "12 new notifications: 4 from Reddit, 3 from Hacker
  News, 3 from Twitter, 2 from GitHub."
- Per-app grouping within the digest.
- Gate: `ShellState.notifyDigest` toggle, per-app override.
- Critical notifications bypass the digest entirely.

### 19.3 Notification Analytics

**File:** New `modules/notify/NotifyAnalytics.qml`

**Plan:**
- Log every notification: `{app, title, body, timestamp, actioned,
  dismissed}`.
- Analytics surface in CC NOTIFICATIONS tab:
  - Top apps by notification count (bar chart).
  - Notifications per hour (line chart, shows peak hours).
  - Action rate (how many notifications the user actually interacted
    with vs dismissed).
  - "Noise score": percentage of dismissed notifications per app.
- Insights: "Twitter sent 47 notifications today; you opened 2.
  Consider muting?"
- Data: `~/.local/state/yutashell/notify-log.json` (rolling 7-day
  window, auto-pruned).

### 19.4 Per-Channel Rules

**Plan:**
- For messaging apps (Signal, Telegram, Slack): parse notification
  body for channel/group context.
- Rules: `ShellState.notifyChannelRules`:
  `{"Slack": {"#general": "quiet", "#alerts": "vip", "#random": "block"}}`.
- Channel detection: first line of notification body often contains
  the channel name.

### 19.5 Notification Summary Card

**Plan:**
- At end of day (configurable time): send a self-notification with
  daily summary.
  - Total received, total actioned, total blocked.
  - Top 3 apps by count.
  - "You spent X minutes responding to notifications."
- Opt-in via `ShellState.notifyDailySummary`.

**Touches:** `NotificationTriage.qml`, `NotifyAnalytics.qml` (new),
`Notify.qml` (extend), `NotificationCenter.qml`,
`ControlCenter.qml` (NOTIFICATIONS tab), `ShellState.qml`.

---

## Phase 20 — Desktop Blueprint (Capstone)

> The final phase ties everything together: a complete configuration
> export/import system, first-run experience, recovery mode, and
> documentation generator. YUTA becomes a portable, reproducible
> desktop environment.

### 20.1 Blueprint Export

**File:** New `modules/blueprint/BlueprintService.qml` (singleton)

**Plan:**
- `export(name)`: serialize the entire shell configuration into a
  single JSON blueprint:
  ```json
  {
    "version": "1.0",
    "name": "my-setup",
    "exported": "2026-08-27T12:00:00Z",
    "shellState": { ... },
    "wallpaper": "path/to/image",
    "schemes": ["acid", "tokyonight"],
    "profiles": [...],
    "rules": [...],
    "plugins": ["arch-updater"],
    "barLayout": {...},
    "keybinds": {...},
    "templates": {...},
    "focusSettings": {...},
    "smartHome": {...}
  }
  ```
- Also exports: `theme.json`, current matugen templates state,
  plugin manifests.
- Saves to `~/.local/state/yutashell/blueprints/<name>.json`.
- "Export to clipboard" for sharing.

### 20.2 Blueprint Import

**Plan:**
- `import(name)`: read blueprint JSON, validate version, apply:
  1. Merge `shellState` keys via `ShellState.set()` (respect
     coalescing timer).
  2. Copy wallpaper to `wallDir`, apply via `Wallpaper.apply()`.
  3. Install custom schemes to `theme/schemes/`.
  4. Load profiles, rules, templates.
  5. Enable plugins via `PluginService.enable()`.
  6. Apply bar layout.
  7. Show restart prompt: "Blueprint applied. Restart to activate."
- Conflict resolution: "Keep mine" / "Use blueprint" per key.
- Dry-run mode: show what would change without applying.

### 20.3 Blueprint Picker

**File:** New `modules/blueprint/BlueprintPicker.qml`

**Plan:**
- `YSurface` panel showing saved blueprints as cards.
- Each card: name, date, preview (bar layout thumbnail + scheme
  colors), size.
- Actions: Apply, Export (copy to clipboard), Delete, Rename.
- "Share" button: copy blueprint JSON to clipboard for pasting into
  another machine's picker.
- Community blueprints: link to a GitHub repo of shared blueprints
  (Phase 9 marketplace integration).

### 20.4 First-Run Experience

**File:** New `modules/blueprint/FirstRun.qml`

**Plan:**
- On first launch (detect via `ShellState.firstRun === false`):
  1. Welcome screen with YUTA logo + tagline.
  2. Scheme picker: visual grid of 12 preset schemes with live preview.
  3. Bar layout picker: 5 presets (Minimal, Classic, macOS, GNOME, Developer).
  4. Quick settings: clock format (12/24h), bar position (top/bottom),
     wallpaper directory.
  5. Import blueprint: "Have a blueprint? Import it here."
  6. Apply & restart.
- Persists `ShellState.firstRun = true` on completion.
- Skip button for advanced users.

### 20.5 Recovery Mode

**Plan:**
- If the shell fails to load (detected by a watchdog timer outside the
  QML context, or by the user launching `qs -c yuta-qs --recovery`):
  - Show a minimal recovery surface: scheme selector + "Reset to Defaults"
    button + "Import Blueprint" button + log viewer.
  - "Reset to Defaults": clear `state.json`, restart.
  - "Import Blueprint": file picker for blueprint JSON.
  - "View Logs": read last 100 lines from shell log.
- Triggered by: `YUTA_RECOVERY=1` env var, or detecting 3 consecutive
  boot failures (track in `ShellState.bootFailures`).

### 20.6 Documentation Generator

**Plan:**
- Auto-generate personalized documentation from current config:
  - `qs ipc call blueprint docs` → markdown document with:
    - Current bar layout with segment descriptions.
    - Active plugins list.
    - Custom schemes installed.
    - Automation rules summary.
    - Project profiles list.
    - Recommended keybinds.
    - IPC cheatsheet (from existing About page).
  - Save to `~/.local/state/yutashell/DOCS.md`.
  - Share button copies to clipboard.

### 20.7 Version Migration

**Plan:**
- Each blueprint export includes a `version` field.
- On import: if blueprint version differs from current, run migration
  steps (add new keys with defaults, rename moved keys, etc.).
- Migration registry: `BlueprintService.migrations` maps version pairs
  to transform functions.
- Ensures blueprints survive across YUTA updates.

**Touches:** `BlueprintService.qml`, `BlueprintPicker.qml`, `FirstRun.qml`
(all new), `ShellState.qml`, `SettingsPanel.qml`,
`settings/AboutPage.qml`, `qmldir`.

---

## Dependency Graph

```
Phase 1  (AI Agent)                ← independent (uses existing APIs)
Phase 2  (Project Profiles)        ← independent
Phase 3  (Automation Rules)        ← benefits from Phase 2 profiles
Phase 4  (Dev Command Center)      ← independent
Phase 5  (Focus & Wellness)        ← benefits from IdleInhibitor (complete)
Phase 6  (Smart System Monitor)    ← benefits from info widgets (complete)
Phase 7  (Session Snapshots)       ← independent
Phase 8  (Visual Workspace Intel)  ← benefits from workspace thumbnails (complete)
Phase 9  (Plugin/Theme Store)      ← independent
Phase 10 (Context Engine)          ← benefits from Phase 2 profiles + Phase 3 rules
Phase 11 (Gaming & Streaming)      ← independent
Phase 12 (Smart Home)              ← independent
Phase 13 (Phone Companion)         ← independent
Phase 14 (Security Dashboard)      ← independent
Phase 15 (File Intelligence)       ← independent
Phase 16 (Hardware Control)        ← independent
Phase 17 (Ergonomics & Health)     ← benefits from Phase 5 focus
Phase 18 (Cross-Device Sync)       ← independent
Phase 19 (Notification Intel)      ← benefits from early notification work (complete)
Phase 20 (Desktop Blueprint)       ← capstone: ties all phases together
```

---

## Estimate Summary

| Phase | New Files | Modified Files | Effort |
|-------|-----------|----------------|--------|
| 1 — AI Desktop Agent | 6 | 3 | High |
| 2 — Project Profiles | 2 | 3 | Medium |
| 3 — Automation Rules | 2 | 2 | Medium |
| 4 — Dev Command Center | 6 | 3 | High |
| 5 — Focus & Wellness | 3 | 3 | Medium |
| 6 — Smart System Monitor | 4 | 3 | Medium |
| 7 — Session Snapshots | 2 | 2 | Medium |
| 8 — Visual Workspace Intel | 2 | 3 | Medium |
| 9 — Plugin/Theme Store | 2 | 3 | Medium |
| 10 — Context Engine | 3 | 2 | High |
| 11 — Gaming & Streaming | 4 | 3 | Medium |
| 12 — Smart Home | 3 | 2 | Medium |
| 13 — Phone Companion | 2 | 2 | Medium |
| 14 — Security Dashboard | 3 | 2 | Medium |
| 15 — File Intelligence | 4 | 1 | Medium |
| 16 — Hardware Control | 5 | 2 | High |
| 17 — Ergonomics & Health | 5 | 2 | Medium |
| 18 — Cross-Device Sync | 3 | 2 | Medium |
| 19 — Notification Intel | 2 | 3 | Medium |
| 20 — Desktop Blueprint | 3 | 3 | Medium |

**Total: ~64 new files, ~48 modified files across all 20 remaining phases.**
