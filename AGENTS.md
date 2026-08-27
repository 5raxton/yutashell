# YUTASHELL

Phases 1–7 complete.

Quickshell desktop shell for Hyprland every compositor call uses `hl.dsp.*` Lua forms, never raw dispatch strings.
Entry: `shell.qml`. Design tokens: `theme/Theme.qml` (`qs.theme`). UI primitives: `modules/common/ui`. State: `modules/common/ShellState.qml`.
README.md is the public-facing doc (features, install, IPC table) — keep it accurate when features change.

## Environment (this machine — volatile facts; re-probe before trusting)

- Arch, Quickshell **0.3.1**, Hyprland **0.56.2**. The session shell runs as **`qs -c yuta-qs`** — process name `qs`, NOT `quickshell` (`pgrep quickshell` finds nothing; use `pgrep -af 'qs -c'`). It hot-reloads every file edit.
- Deps present: grim, slurp, curl, notify-send, pactl, nmcli, bluetoothctl, rfkill, powerprofilesctl, checkupdates, gpu-screen-recorder, matugen, awww(-daemon). **Absent today**: wl-copy/cliphist, nvidia-smi, ddcutil, hyprsunset, cava, hyprpicker — their features hide via Health chips; never assume an optional binary exists, probe like `modules/widgets/*` services do.
- No CJK font → `Theme.jpEnabled` false → romaji fallbacks everywhere.
- Wallpaper engine is **awww** (`awww-daemon`), palettes via **matugen**. All runtime files live in `~/.local/state/yutashell/` (state.json, theme.json, matugen.toml, generated/) — nothing else writes dotfiles.
- Network reality drifts between sessions (wired ↔ wireless flips); durable fact: mullvad `wg0` is externally managed — visible via nmcli, invisible to `Quickshell.Networking`.

## Quickshell 0.3.1 API facts (each cost real debugging)

- `Hyprland.activeToplevel` never populates. Track focus via raw `activewindow`/`activewindowv2` events + one-shot `hyprctl -j activewindow` probe (`FocusMonitor.qml`).
- `HyprlandToplevel`: no `.class`, no `.activate()` — app id = `tl.wayland?.appId || tl.lastIpcObject?.class`. `HyprlandWorkspace` has `activate()`. Call `refreshToplevels()`/`refreshWorkspaces()` once at boot; models auto-update after.
- `Quickshell.env()` returns **null** (not "") for unset vars — null-guard with `?? ""`.
- No `Quickshell.primaryScreen` — use `Quickshell.screens.length > 0 ? Quickshell.screens[0] : null`.
- Per-monitor surfaces work via `Variants { model: Quickshell.screens; Bar { required property var modelData; screen: modelData } }`; instances follow hot-plug. Shared Tooltip window sits on one screen only (fine single-monitor).
- **Mpris**: `Mpris.players.values`; player has `identity/isPlaying/trackArtist/trackTitle/canTogglePlaying()/next()/previous()/volume(+volumeSupported)`.
- **DesktopEntries**: `applications.values` (filter `noDisplay`), `byId(id)`, `heuristicLookup(name)`; entries have **`execute()`** (use it — no manual Exec parsing), `.icon`, `.actions[]` (`id/name/icon/execute()`).
- **Notifications** (`NotificationServer`): caps props on server; `onNotification(n)` → `n.actions` is a plain JS array (NO `.values` — that's ObjectModel syntax; `.map` on the iterator throws). `tracked=true` holds it; `expire()/dismiss()` close it; C++ may enforce client expireTimeout first and destroy the wrapper — shrink our timeout by ~300 ms, set `dead` via `closed.connect`, never touch the object after close. **Inline reply**: `n.hasInlineReply` (bool), `n.inlineReplyPlaceholder` (string), `n.sendInlineReply(text)`. Server: `inlineReplySupported` (writable bool). PH.03: toast dedup (same-app 3s window bumps count badge), grouped history by appName (expandable in NotificationCenter), snooze (`_snoozeUntil` timestamp, `dnd snooze <minutes>` IPC), search (substring match on app+sum+body).
- **Networking**: `Networking.devices.values` → WifiDevice (`networks/scannerEnabled/mode`) / WiredDevice (`hasLink/linkSpeed/address`); enum name is **NetworkConnectivity** (not Connectivity).
- **Bluetooth**: root singleton exports as **`Bluetooth`** (NOT Bluez): `Bluetooth.defaultAdapter` → devices have `deviceName/icon/state/paired/trusted/battery` + `pair()/connect()/disconnect()/forget()`. **`Bluetooth.agent` does NOT exist in QS 0.3.1** — only `pair()`/`cancelPair()` on device for Just Works pairing; no PIN/passkey dialog API available.
- **Pipewire**: `Pipewire.nodes.values` → node `.audio` (volume LINEAR 0..1+, `muted`) + `.isStream`; perceptual steps need cubic mapping (see `AudioService.qml` `nodeFrac/stepPct`). `defaultAudioSink/Source` writable. **`PwNodePeakMonitor`** (`node`, `enabled`, `peak` float 0..1, `peaks` float list, `channels` PwAudioChannel list) — creatable type in `Quickshell.Services.Pipewire`. Bind `node` to a sink; `peak` is the summed peak, `peaks` is per-channel.
- **GlobalShortcuts**: `Quickshell.Hyprland._GlobalShortcuts` — `GlobalShortcut` type with `appid`, `name`, `description`, `triggerDescription` properties and `pressed`/`released` signals. NOT a singleton — create instances declaratively and handle `onPressed`.
- **IdleInhibitor**: `Quickshell.Wayland._IdleInhibitor` — `IdleInhibitor` type with `enabled` (bool) and `window` (QObject — a Wayland toplevel surface). Attach to any PanelWindow's surface to suppress idle. NOT the same as `IdleMonitor` (which detects idle, not prevent it). The bar's session segment (caffeine chip) directly calls `IdleInhibitor.toggle()` on click. The segment shows "CAFFEINE" when manual inhibit is active, "INHIBIT" with logind count otherwise. IPC: `session idle-inhibit` toggles.
- **Session APIs**: `WlSessionLock` default property is `surface` (a Component) with `WlSessionLockSurface {}` inside; its `.screen` is **null until the compositor assigns it** — guard before reading `.name`. `PamContext.config` = `/etc/pam.d/` service name (`system-auth` works). `UPower` AND **`PowerProfiles`** are two separate singletons (profile enum 0=saver/1=balanced/2=performance); power-profiles-daemon availability must be probed via `busctl --system introspect net.hadess.PowerProfiles …` (`systemctl is-active` lies pre-activation). `PolkitAgent` is instantiable; `IdleMonitor` lives under `Quickshell.Wayland._IdleNotify`. Exit = `Quickshell.quit()`.
- **Process**: assigning `command` does NOT start it — nothing runs until `running: true`. `StdioWriter` does not exist; write files via FileView (`setText` stages AND writes) then move with a Process.
- Singletons instantiate lazily on first access — IPC right after spawn races their boot probes; shell.qml has a warm-up Timer touching each service's `available`.

## New singletons (PH.01)

- `ClipboardService` (widgets) — reactive clipboard monitor, polls `wl-paste` and feeds `cliphist add`.
- `IdleInhibitor` (session) — prevents idle during media/recording; state singleton, per-Bar `Wayland._IdleInhibitor` instances bind `enabled` + `window`.
- `GlobalKeys` (common) — shell-internal keybind registry; persists bindings in `ShellState.globalKeybinds`.
- `MixerService` (audio) — per-app audio mixer over PipeWire; wraps AudioService streams with desktop-entry icon resolution and clean write-back API.

## New singletons (PH.07)

- `SnapshotService` (session) — save/restore desktop states: captures open windows (hyprctl -j clients), wallpaper, barSegments, DND, nightLight. Snapshots persist as JSON in `~/.local/state/yutashell/snapshots/<name>.json`. Boot writes a Python helper script via `FileView.setText()` (works only from onCompleted); runtime saves call this helper via `Process` to bypass the FileView async-write limitation. IPC: `snapshots save/remove <name>/list/status`.

## New singletons (PH.08)

- `RecentFiles` (launcher) — reads `~/.local/state/recently-used.xbel`, exposes top 20 files; click opens with `xdg-open`.

## New singletons (PH.09)

- `Pomodoro` (widgets) — singleton state machine: idle → work → break → longBreak. Properties: `phase`, `remaining` (seconds), `round`, `running`, `display` (MM:SS), `label`. Functions: `start()`, `pause()`, `resume()`, `reset()`, `toggle()`. Timer drives bar chip (⏱ + countdown); notifications on phase change. IPC: `pomodoro start/pause/resume/reset/toggle/status`.
- `Cheatsheet` (widgets) — YSurface panel parsing `hyprctl -j binds` JSON into categorized bind list (GENERAL, WINDOWS, WORKSPACES, APPS, MEDIA, SESSION). Searchable by key combo or description. Falls back to static embed if parsing fails. IPC: `cheatsheet toggle/open/close`.
- `NightLight` extended with schedule — `ShellState.nlSchedule` JSON `{on:"HH:MM", off:"HH:MM", enabled:bool}`. Timer checks every 60 s; auto-enables/disables hyprsunset. Handles midnight wrap (on > off = overnight). Settings: 3 presets (21:00–07:00, 22:00–06:00, 20:00–08:00). IPC: `nightlight schedule <on> <off> <bool>`, `nightlight schedulestatus`.

## AI Desktop Agent (PH.11)

Six types in `modules/ai/`:

- **`AiService`** (singleton) — core AI connection: Ollama local (default `http://localhost:11434`) or any OpenAI-compatible endpoint. HTTP via `Process` + `curl` (same pattern as Weather/SystemStats). Streams SSE responses into `responseBuffer` for real-time UI binding. Boot probes endpoint with `GET /api/tags` (Ollama) or `GET /v1/models` (OpenAI). `chat()` builds OpenAI-format messages array with system prompt + history; `complete()` for single-shot. Model list auto-discovers on probe. Provider/endpoint/model/apiKey persisted via `ShellState` keys (`aiProvider`, `aiEndpoint`, `aiModel`, `aiApiKey`, `aiHistory`).
- **`AiContext`** (singleton) — builds system prompt from live shell state: focused window, workspace, active monitor, OS/compositor info, system stats (CPU/mem/temp via `SystemStats`), current media (`Mpris`), weather (`Weather`), and available IPC commands. Refreshed on each `chat()` call so the AI always sees current desktop state.
- **`CommandPalette`** (PanelWindow) — AI-powered command surface: natural language input → AI response → parsed action. Action parsing detects `[DISPATCH]`, `[SHELL]`, `[IPC]` directives in AI output. EXECUTE button runs parsed actions; COPY button copies response. Model selector chips when multiple models available. Command history (last 20) persists in `ShellState`. Kill button for long-running requests.
- **`ChatSidebar`** (PanelWindow) — conversational AI panel: message bubbles (user/assistant), streaming token display, markdown text rendering. Model selector chips + CLEAR button. Messages stored as `_conversation` array with `role`/`content`. `onRunningChanged` appends empty assistant message when new turn starts.
- **`VoiceInput`** (singleton) — voice capture via `pw-record` (PipeWire) → transcription via `faster-whisper` or `whisper-cli`. Boot probe checks which backends are installed. `startRecording()` / `stopRecording()` / `transcribe()`. Transcribed text fed to AiService.
- **`ScreenshotAction`** (singleton) — screenshot-to-action: `grim` + `slurp` region capture → base64 encode → Ollama vision model (`llava`) analysis. `capture()` spawns grim+slurp, `analyze()` sends image to vision model for natural language description, `takeAction()` captures and analyzes in sequence.

IPC: `ai toggle/open/close`, `ai chat`, `ai send <text>`, `ai models`, `ai setmodel <name>`, `ai setprovider <ollama|openai>`, `ai setendpoint <url>`, `ai screenshot`, `ai voice`, `ai status`.

ShellState additions: `aiOpen` / `aiChatOpen` (runtime, non-persisted, toggled by IPC), plus persisted config keys.

## Project Profiles (PH.02)

Two types in `modules/profiles/`:

- **`ProfileService`** (singleton) — core profile management. Profile definition: `{id, name, icon, wallpaper, apps[], powerProfile, dnd, barPreset, nlActive}`. Stored in `ShellState.profiles` as a JSON array. `apply(id)` switches wallpaper via `Wallpaper.apply()`, launches apps via `DesktopEntries.heuristicLookup().execute()`, sets power profile via `PowerProfiles.profile`, DND via `Notify.setDnd()`, bar layout via `BarSegments.applyPreset()`, night light via `NightLight.setActive()`. `save(id, name)` snapshots current live state (running apps from `Hyprland.toplevels`, wallpaper, power profile, DND, night light). `deleteProfile(id)` removes a profile. `cycle()` advances to next profile. `activeId` tracks the current profile; `activeName` exposes it for the bar chip.
- **`ProfilePicker`** (PanelWindow) — YSurface panel showing profile cards in a scrollable list. Each card: active indicator (acid left bar), icon, name, RENAME/APPLY/DEL buttons. "SAVE CURRENT" button at top creates a new profile from live state. RENAME cycles through preset names (Work/Play/Focus/Chill/Dev/Media). Clicking a card applies it.

Bar: new `profiles` segment shows ◆ icon + active profile name. Click cycles profiles; scroll-down opens picker. Only visible when a profile is active. Added to all 7 layout presets (disabled by default). Falls through to `compactIds` when active.

IPC: `profiles toggle/open/close/list/apply <id>/save <id> <name>/deleteprofile <id>/cycle/status`.

ShellState additions: `profilesOpen` (runtime, toggled by IPC), persisted `profiles` (JSON array) key.

## Automation Rules Engine (PH.03)

Two types in `modules/automation/`:

- **`RuleService`** (singleton) — declarative trigger-action engine. Rules stored in `ShellState.automationRules` as JSON array of `{id, name, trigger:{type,config}, actions:[{type,config}], enabled}`. 8 trigger types: `time` (hour/minute/days-of-week), `battery` (above/below threshold %), `network` (connected/disconnected), `recording` (started/stopped), `temperature` (above/below °C), `focusedApp` (app gained/lost focus via `Hyprland.onRawEvent`), `mpris` (playback started/stopped), `idle` (user idle N seconds). 8 action types: `setProfile`, `setPowerProfile`, `toggleDnd`, `runCommand`, `notify`, `setWallpaper`, `setNightLight`, `setBarPreset`. Time-based rules evaluated by 30 s Timer; event-driven triggers subscribe to existing singleton signals (`SystemStats.warnRaised`/`thermalWarning`, `Connectivity.onWifiOnChanged`, `Recording.onActiveChanged`, etc.) via `Connections`. 60 s cooldown per rule prevents re-fire. CRUD: `create()`, `update(id, patch)`, `remove(id)`, `toggleEnabled(id)`, `setEnabled(id, bool)`, `testRule(id)`. 8 starter rules ship disabled by default (Low Battery Saver, Work Hours, Night Mode, Gaming Mode, Recording Focus, Thermal Throttle, Morning Wake, Mute on Media Stop).
- **`RuleEditor`** (PanelWindow) — YSurface panel with two-column layout: scrollable rule list (left) with enabled dot + name + trigger summary, detail editor (right) with trigger type selector chips, type-specific config fields (hour/minute/day picker for time, op+threshold chips for battery/temperature, event chips for network/recording/mpris, text input for focusedApp app ID, duration chips for idle), action chips (existing actions with remove buttons + add-action chips from a palette), enable/disable toggle, TEST button, DEL button.

Bar: new `automation` segment shows ⚡ + enabled rule count. Click opens RuleEditor. Added to all 7 layout presets (disabled by default). `present()` returns true when any rule is enabled.

IPC: `automation toggle/open/close/list/enable <id>/disable <id>/test <id>/status`.

ShellState additions: `automationOpen` (runtime, toggled by IPC), persisted `automationRules` (JSON array) key.

## Developer Command Center (PH.04)

Six singletons + one PanelWindow in `modules/dev/`:

- **`GitService`** (singleton) — reads git status from focused terminal's CWD. Tracks focused window via `Hyprland.onRawEvent`, extracts CWD from terminal title or `/proc/<pid>/cwd`. Runs `git status --porcelain=v2 --branch` on 3s timer. Exposes `branch`, `ahead`, `behind`, `dirty`, `staged`, `untracked`, `isRepo`, `cwd`. Probes `git` at boot.
- **`DockerService`** (singleton) — reads docker compose projects via `docker compose ls --format json` on 10s timer. Exposes `projects[]` with name, status, container count. `restartProject(name)` and `stopProject(name)` functions. Probes `docker` at boot.
- **`CIService`** (singleton) — reads GitHub Actions via `gh run list --json` on 60s timer. Configurable repos in `ShellState.cicdRepos`. Cycles through repos one at a time. Sends notification on failure. `addRepo(name)` / `removeRepo(name)`. Probes `gh` at boot.
- **`LogTailer`** (singleton) — streams journalctl or custom log sources via `Process` + `Splitter`. Sources: `system` (journalctl -f -p warning), `hyprland` (tail of hyprland.log), `custom` (user command). `filter` for regex, `paused` bool, `clear()`. Max 500 lines.
- **`TmuxService`** (singleton) — reads tmux sessions via `tmux list-sessions -F` and zellij via `zellij list-sessions` on 5s timer. Auto-detects which is installed. `attachSession(name)`, `newSession(name)`, `killSession(name)`. Exposes `sessions[]` with name, windows, attached, via.
- **`PortService`** (singleton) — reads `ss -tlnp` on 15s timer. Exposes `ports[]` with port, addr, process, pid. Flags non-localhost listeners in `_exposed[]`.
- **`DevPanel`** (PanelWindow) — unified YSurface panel with 6 tab chips (GIT/DOCKER/CI/CD/LOGS/TMUX/PORTS). Each tab shows its service's live data with action buttons (restart docker, kill tmux session, pause logs, add CI repo).

Bar: 3 new segments — `git` (branch + dirty badge, visible when dirty), `docker` (project count, visible when projects exist), `cicd` (run count + checkmark/X, visible when runs exist). All click to open DevPanel. Added to all 7 layout presets (disabled by default).

IPC: `dev toggle/open/close/gitstatus/dockerstatus/dockerrestart <name>/dockerstop <name>/cistatus/addrepo <name>/removerepo <name>/tmuxstatus/ports/status`.

ShellState additions: `devOpen` (runtime, toggled by IPC), persisted `cicdRepos` (JSON array of repo strings).

## Focus & Wellness (PH.05)

Three types in `modules/focus/`:

- **`FocusMode`** (singleton) — deep focus state machine: idle → focusing → break → longBreak → idle. Configurable work/break/longBreak durations and rounds. On focus start: enables DND via `Notify.setDnd(true)` and inhibits idle via `IdleInhibitor.manualInhibit`. Session stats logged to `~/.local/state/yutashell/focus-history.json` (30-day rolling window). Properties: `phase`, `remaining` (seconds), `round`, `running`, `display` (MM:SS), `label`, `focusing`, `showBreak`, `totalFocusedToday`, `history`. Functions: `start()`, `pause()`, `resume()`, `reset()`, `toggle()`, `status()`. IPC: `focus start/pause/resume/reset/toggle/status`.
- **`BreakOverlay`** (PanelWindow) — fullscreen overlay at Overlay layer shown during break phases. Large countdown timer + rotating health tips (9 tips, 8s rotation). Dismissible after 10s minimum break time. Shows round counter. Blocks input via exclusion mode.
- **`FocusPanel`** (PanelWindow) — YSurface panel showing focus stats (today's minutes, this week total, streak), start/pause/reset controls, and 7-day history list. Month navigation with `CalendarGrid` for heatmap display.

Bar: new `focus` segment shows ◉/○ icon + countdown when focusing, "FOCUS" label when idle. Visible only when `phase !== "idle"`. Added to all 7 layout presets (disabled by default). Included in `compactIds`.

IPC: `focus toggle/open/close/start/pause/resume/reset/status`.

ShellState additions: `focusOpen` (runtime, toggled by IPC), persisted `focusWorkMin`, `focusBreakMin`, `focusLongBreakMin`, `focusRoundsBeforeLong` (adapter defaults 25/5/15/4).

## Smart System Monitor (PH.06)

Five singletons + one PanelWindow in `modules/system/` (plus `NetHealth` in `modules/system/`):

- **`BatteryService`** (singleton) — battery intelligence: wraps SystemStats battery data with derived health/wear/time metrics. Reads charge threshold from sysfs on boot. Supports writing threshold via `setChargeThreshold(pct)` (sudo tee). Exposes `healthPct`, `wearPct`, `timeLeft`, `timeToFull`, `chargeRate`, `warn`, `crit`.
- **`NetHealth`** (singleton) — network health monitor: periodic 30s probes for ping latency (1.1.1.1), IP address, VPN status (`ip link show wg0`), DNS resolution. Exposes `latencyMs`, `latencyGrade` (excellent/good/fair/poor/bad), `ip4`, `vpnActive`, `dnsServer`. Signals: `latencySpike(ms)`, `vpnChanged(active)`. Health reports on VPN disconnect.
- **`PowerBudget`** (singleton) — power budget aggregator: reads top CPU apps from `ps aux`, screen brightness from sysfs, battery discharge rate. Exposes `topApps[]` (name, cpu%, mem%), `screenBrightness`, `dischargeRate` (mW), `estimatedMinutes`. 5s refresh.
- **`WsHeatmap`** (singleton) — workspace memory visualization: queries `hyprctl -j workspaces` and `activeworkspace` on 3s timer + Hyprland raw events. Exposes `workspaces[]` (id, name, windows, focused). `switchTo(wsId)` dispatches focus.
- **`SystemMonitor`** (PanelWindow) — unified YSurface panel with 4 tab chips (BATTERY/NETWORK/POWER/WORKSPACES). Battery tab: ring gauge + health/wear/energy/threshold. Network tab: latency/grade/IP/VPN/DNS rows. Power tab: discharge rate, brightness bar, top CPU apps with bar chart. Workspaces tab: color-coded grid (green→red by window count), click to switch.

Bar: new `systemmonitor` segment shows ⚙ + battery % + latency. Click opens SystemMonitor. Added to all 7 layout presets (disabled by default).

IPC: `systemmonitor toggle/open/close/battery/network/power/workspaces/status`.

ShellState additions: `systemMonitorOpen` (runtime, toggled by IPC).

## Accessibility (PH.10)

- `Theme.reducedMotion` — persisted in `ShellState.reducedMotion`. When true, all `mov*` motion tokens snap to 0: `Behavior on` blocks evaluate to instant transitions. Toast entrance excluded (80 ms minimum). Settings: A11Y page toggle.
- `Theme.highContrast` — persisted in `ShellState.highContrast`. Overrides palette tokens: ink → pure white/black, bg → pure black/white, muted/faint/hairline/lineStrong → ink. Acid accent preserved. Applied after scheme tokens via `_applyHighContrast()`.
- **Keyboard navigation** — all UI primitives (`YButton`, `YSwitch`, `YField`) have `activeFocusOnTab: true`. Enter/Space activates focused element. Focus border goes acid. Arrow keys for sliders. ESC blurs field or closes panel. Tab/BackTab cycles focus within panel.
- Settings: 17 pages total (new A11Y page in LOOK group).

## Launcher (PH.08)

- **Frecency ranking**: `ShellState.launchStats` stores per-app `{count, lastLaunch}` timestamps; `frecencyScore()` applies time-decay (`count * 1/(1 + daysSince * 0.1)`). Used to sort unqueried results (pins -> recents -> frecency -> alpha) and to boost fuzzy search scores by up to +30%.
- **Multi-mode prefixes**: `=` calculator, `>` shell command, `@` notification history search, `#` color converter, `~` recent files. Each mode has its own result kind and UI component.
- **Safe calculator** (`=` prefix): recursive descent parser (no `eval`/`Function()`); supports `+`, `-`, `*`, `/`, `%`, `^`, parentheses, functions (`sqrt`, `abs`, `sin`, `cos`, `tan`, `log`, `ln`, `floor`, `ceil`, `round`), constants (`pi`, `e`, `phi`). Result copied to clipboard via `wl-paste` (missing `wl-clipboard` = Health warning).
- **Result kinds**: `app` (desktop entry, default), `action` (desktop entry action), `recentfile` (XDG recent, opened via `xdg-open`), `shellcmd` (> prefix, run via Process), `notifyitem` (@ prefix, matched notification history entry).

## Hyprland facts

- **Warm-client rule**: `Hyprland.dispatch('hl.dsp.*')` silently no-ops from a fresh instance unless the event socket is subscribed AND ~8 s uptime elapsed. Live shell always qualifies; 2 s test instances don't. `hyprctl eval '<lua>'` is always cold — fine for `hl.config`, inert for `hl.dsp.*`.
- `Hyprland.dispatch()` return value is meaningless — verify dispatches by effect, not return.
- Verified working verbs (see `modules/overview/Overview.qml` for canonical usage): `hl.dsp.focus({window="class:X"|address:"0x…"})` (selector strings + userdata), `focus({workspace="N"})` (existing only, no auto-create; `"previous"` works), `hl.dsp.window.{float({action="toggle"}),center(),fullscreen(),resize{x,y},move{x,y},close()}`, `window.move({workspace=N})` (focused window only). Scratchpad gesture: `window.move({workspace="special:magic"})` auto-creates ws −98; restore = `move({workspace="previous"})`.
- **INERT despite plausible names**: `hl.dsp.workspace.toggle_special(...)`, `focus({workspace="special:*"})`, and raw keyword strings (hyprctl wraps them into failing `hl.dispatch(<bare identifiers>)`).
- Runtime config only via `hyprctl eval '<lua>'` — plain `hyprctl keyword` fails ("non-legacy parsers"). Nested Lua tables mirror option paths: `hl.config({general={col={active_border="…"}}})` → `general:col.active_border`.
- Color formats (hyprctl round-trip verified): `rgba()` hex parses RRGGBBAA (trailing alpha!), bare `"0xAARRGGBB"` strings parse directly; internal form is always AARRGGBB. colors.lua template's `0xff…` values correct as-is; it applies borders via `hl.config` at require time, and the catalog post-hook re-applies through `hyprctl eval` after every matugen run.
- `WlrLayershell` anchors are ONLY left/right/top/bottom — no horizontalCenter. Centered dock = full-width window (left+right+bottom) + `mask: Region { item: <centered content> }`.
- **Workspaces**: five render modes via `ShellState.wsMode`: `default`/`numbers`/`pills`/`active`/`thumbnails`. Scratchpad windows live in `special:magic` (workspace id < 0 or name === "magic"); restore via `window.move({workspace="previous"})`. PH.04: `Scratchpad.qml` lists stash contents; `Dock.pinnedWindows` tracks addresses pinned to all workspaces; `OverviewGrid` has search filter + right-click move-window mode. PH.05: `IdleInhibitor` caffeine chip in bar session segment, `session idle-inhibit` IPC toggle. PH.06: Osd "thermal" kind for threshold-crossing alerts (auto-dismiss 4 s), gated by `ShellState.osdThermal`. PH.08: Launcher features in dedicated section below. PH.09: `Pomodoro` bar chip with ⏱ + countdown, `Cheatsheet` bar chip with ⌨ toggle. PH.07: `Snapshots` bar chip with ⌘ + count. 29 total segment types.

## Hard-won lessons (do not regress)

### 1. Never decode full-res images for thumbnails — OOM incident
Full-res decode of 194 wallpapers hit **7–13 GB RSS** and the kernel OOM-killed the session. Rules: every preview `Image` sets `sourceSize`; gate `source` on visibility (`root.visible ? url : ""`); remember components inside always-instantiated singletons run at startup even when "closed". Picker uses a spine+stage design: one clamped preview decode total (stage preview 1024×640, `WallpaperPicker.qml`). Watch RSS after opening model-heavy surfaces (healthy ≈ 370–420 MB).

### 2. awww socket race
Fixed sleeps race daemon startup and drop paints silently. Spawn detached (`setsid`), retry `awww img` up to 8× with 0.25 s gaps (Wallpaper.qml).

### 3. FileView drops overlapping operations
Back-to-back `writeAdapter()`/`setText()`/`reload()` within a few hundred ms silently drop (warning: `got operation finished from dropped operation`). **Critical: `setText()` and `writeAdapter()` also silently fail when called from async callback contexts (StdioCollector.onStreamFinished, Timer triggered from callbacks) — they only work reliably from `Component.onCompleted` or other synchronous init paths.** Fixes shipped: `ShellState.set()` coalesces via 80 ms flush timer; Wallpaper.writeGenConfig 100 ms; startup seeding writes only if file absent AND empty. **SnapshotService workaround**: writes a Python helper script to disk at boot via `setText()` (onCompleted), then calls it via `Process` at runtime for all file writes. Keep ≥0.5 s between mutating IPC calls in scripts. state.json is not watched for external edits — inject prefs via IPC or restart.

### 4. QML gotchas (one line each, all bit us)
- Flickable/GridView/ListView reparent declared children into contentItem — scroll indicators/fades/overlays MUST be siblings over the scroll area (`YScroll { target }`).
- Binding loops: `contentHeight ← childrenRect.height`; hosts sized from `childrenRect` while children anchor to them (YRow.trailingW exists for this).
- `contentHeight ← loader.item.height` can latch onto a dying item across sourceComponent switches and go permanently stale — sync imperatively + retargetable `Connections { target: loader.item }`.
- Declare `required property var modelData` exactly ONCE (delegate root + inline wrapper = silent per-row creation failure).
- A Repeater delegate redeclaring a host type's own property → `Property value set multiple times`; use a fresh name.
- **Anchored Loaders STRETCH their loaded root** past explicit width/height (launcher/picker cards rendered fullscreen for weeks). Wrap: filler Item + alias the real surface; point masks at `loader.item.surface`.
- `IconImage` sizes ONLY via `implicitSize`; needs real URLs — resolve icon *names* via `Quickshell.iconPath(name)`; missing icons still WARN (`Cannot open: qrc:/...`) — expected fallback noise, initials fallback covers it.
- Duplicate property assignment anywhere kills the WHOLE config load and the instance exits instantly (cascading `Type unavailable`) — see testing discipline below.
- QtObject root has NO default property — child Timers/Processes fail; use `Singleton` as root (childless QtObject fine).
- Every `pragma Singleton` file needs `singleton X 1.0 X.qml` in qmldir — listed as plain type, reads yield `[undefined] to bool` dead bindings. Once a directory has qmldir, imports are STRICT: list every top-level type including windows.
- `console.log` during singleton boot doesn't reach nohup stderr; `console.warn` does. From bash, QML logs stream reliably via `qs -p <path> log > file &` or `/run/user/1000/quickshell/by-{pid,id}/…/log.log`.
- This Qt build lacks `String.trimStart/trimEnd` — use `.replace(/^\s+/, "")`.
- `Qt.callLater` samples pre-compositor-configure (sizes 0×0) — probe geometry from a Timer ≥500 ms after visible.
- `Keys.on*Pressed` handlers must declare the param: `Keys.onUpPressed: event => {…}`.
- Auto-changed signal for `property var _dispList` is `on_DispListChanged` (first letter after underscore capitalizes).
- Row-level MouseArea spanning the row eats trailing-slot clicks — constrain its right edge to `trailingHost.left`.
- Nav rails / tight click strips MUST NOT sit inside a Flickable (gestures swallow clicks) — plain Column unless content truly scrolls.
- Don't reference another file's window instance (`MediaWidget.player` type access = undefined) — resolve services directly (`Mpris.players.values`).
- Offscreen platform can't create PanelWindows — validate against the live Wayland session under `timeout`.
- JS-function bindings (`readonly var x: Singleton.fn()`) do re-evaluate, but recreate all delegates per persist — small lists only.
- **A `component X:` root `id` is invisible from the delegate usage body** — not in JS closures (`Component.onCompleted`), `NumberAnimation.target`, nor even direct QML bindings on the delegate. Component-internal references work (e.g. `item.x` inside the `component X` block). Keep delegate logic INSIDE the component and declare `required property int index` on the delegate, or drive it from the usage body with pure bindings (no closures). (PowerMenu stagger.)
- **`Mpris` has NO `playersChanged` signal** (type `MprisQml`; `players` is a constant model) — media polling must run on a timer (`IdleInhibitor._checkMedia`, 3 s). A `Connections { target: Mpris; onPlayersChanged }` is a silent no-op.
- **Design tokens must exist before use** — audit `Theme.` references against Theme.qml (an undefined token binds to `undefined`, e.g. `border.color:` → invisible border, `String(Theme.x ?? "")` → always `""`). Previously-undefined: `Theme.line`→`lineStrong`, `Theme.warn`→`alert`, `Theme.accentOverride`→`ShellState.accentOverride`, `theme.r2`→`Theme.radius`, and `sp6`/`sp8` are now real tokens.
- `Recording.active` can read `undefined` during singleton warm-up — coerce with `!!Recording.active` before it feeds a `bool` binding.
- **YField stretched via anchors.fill loops if a parent sizes from its live `height`** — size the parent from `implicitHeight` (`searchField.implicitHeight + Theme.sp2 * 2`), not `searchField.height`.

### 5. Surfaces: compose the kit, don't hand-animate
- Bar sits at `WlrLayer.Overlay`; popups at `Top`; entrances emerge from behind the bar.
- Floating surfaces MUST compose **YSurface** (drop-in choreography, scanline, power line, optional `cascade:` stagger) — never re-animate a popup by hand. Cascade children expose `reveal()`; dynamic animations come from `Component { id: kidAnim … }` + createObject (**inline `component X:` cannot be createObject'd**) and self-destruct in `onStopped`.
- Closing: ESC/keybind/IPC + **YClickAway** (fullscreen catcher as FIRST child, card after; window `mask: Region { item: open ? clickAway : null }`; YSurface's swallow MouseArea keeps in-card clicks local). PolkitDialog/LockScreen stay modal; Toasts/Osd/Dock skip the catcher. Windows linger `Theme.lingerMs` (190 ms) post-close so the exit ceremony renders while the mask nulls instantly.
- FastWheel is the standard wheel handler for every Flickable/GridView/ListView.
- Perf guardrails: animate opacity/transforms, never layout of anchored items (YSection scales xScale instead of width); pulses gate on `visible`; toast cards are stable in-place QtObjects across countdown ticks (reassigning arrays kills hover-pause).

### 6. Template snippet engine + matugen
- Include-style templates edit the TARGET APP's config (managed `# >>> yutashell-matugen` blocks) serialized `_snipQueue` → reader Process → staged FileView → copier Process.
- TOML configs can't take appended include lines (duplicate keys invalid; keys after table headers land in the last table) — alacritty-style configs use `mode: "toml-import"` merging into the existing `import = [...]`.
- Custom templates get NO snippet rules by design — they render only during matugen apply. Startup binProbe maps catalog ids → installed apps; absent apps refuse enable and get pruned; unknown ids pass `appInstalled`.
- matugen hard-fails without a TTY on multiple source-color candidates — always pass `--source-color-index 0` non-interactively. TOML literal strings don't support `''` escaping — generate multiline literals `'''…'''`.
- FileView semantics that DO work: JsonAdapter+writeAdapter for structured prefs; setText for staging+write; watchChanges+reload-on-callback for live theme recolor.

### 7. Architecture rules
- **SystemStats is the one sampler** — any new stat reader binds to `SystemStats.*` (FAST 2 s FileViews, SLOW 5 s Process); never open a second FileView/Timer over /proc//hwmon/nvidia-smi. Shared formatters `fmtRate/fmtBytes/fmtTime/fmtTemp/fmtDuration` live there. Now reads fan RPM from `sensors -j` (`fans[]` array), battery health from sysfs (`batWearPct`, `batTimeLeft`, `batTimeToFull`), and emits `thermalWarning`/`thermalCritical` signals.
- Widgets split into singleton services (probe backend once, expose `available`) vs PanelWindows. Missing backend ⇒ flat "not installed" message or hidden feature + `Health.report(module,msg)` — never a dead button. Bar shows `!` chip while `Health.count > 0`.
- Bar is data-driven: `ShellState.barSegments` ordered `{id,zone,enabled}`; new segment = Component in Bar.qml + `BarSegments.meta` + `present()` case (+ optional `BarActions.dispatch` action). Height-only scaling via `transform: Scale { yScale }`. `BarSegments` now exposes `layoutPresets[]` (7 built-in bar layout presets), `applyPreset(id)`, `presetIds()`. Compact mode filter via `compactIds[]`. `BarActions` supports compound actions (JSON array), `shell:<cmd>`, `theme:<scheme>`, click profiles (productivity/media-first/dev). `ShellState.barCompact` (bool, default false), `ShellState.customPresets` (JSON array of user presets).
- SettingsPanel: 15 declarative pages behind lazy Loaders + switch; searchable two-level nav rail. ControlCenter: 11 tabs from `ShellState.ccTabs`; per-tab Timers gate on `activePageId === "x" && ShellState.ccOpen`.
- SNI tray menu needs `//@ pragma UseQApplication` in shell.qml — takes effect only on fresh start, so the warning still logs mid-session after hot-reloads.
- **StorageMonitor** (widgets) — singleton reading `df -h` every 5 s, per-mount usage with warn/crit thresholds; feeds disk bar segment and surface panel.
- **NetDetails** (net) — YSurface panel showing IP4/IP6/gateway/DNS/signal; IPC: `network details`, `network copy-ip`.
- **ProcessKiller** (widgets) — YSurface panel with process search + kill; IPC: `processes open/close/kill <pid>`.
- **Launcher prefix modes** — search input prefixed with `=`, `>`, `@`, `#`, or `~` switches to a dedicated mode (calc/command/notify/color/recent). Each mode has its own UI component (CalcStrip, CommandCard, NotifyList, ColorResult, RecentFileList). Calculator uses a recursive descent parser (`CalcParser.qml`) — never `Function()` or `eval`. Frecency ranking: `ShellState.launchStats` per-app `{count, timestamps[]}`, score = `count * 1/(1+daysSince*0.1)`, 30-day decay. Sort: pinned → recent → frecency → alpha.

## Conventions (enforced)

- Colors/fonts/metrics ONLY from `Theme.*` — no hardcoded values; this is what makes live recoloring free. `Theme.compactScale` factor (0.7x when `barCompact`); `Theme.scaledBarHeight` now includes compactScale.
- UI primitives ONLY from `modules/common/ui` (YButton/YSwitch/YRow/YSection/YField/YChip/YScroll) — compose the kit, never hand-roll.
- Type ramp fsDisplay > fsTitle > fsBody > fsLabel > fsMicro; body copy sentence-case at fsBody; UPPERCASE+tracking reserved for micro-chrome.
- Acid is semantic (active/focus/primary CTA/status ticks), never decoration; may pulse/draw/sweep only where meaningful.
- Motion: hover/focus snap (`movSnap`); indicators movFast/movMed OutCubic; idle life = opacity-only at movDrift; never pulse text. YButton hard-shadow press collapse is the one physical flourish.
- User actions go through IpcHandlers (keybinds + CLI + panel share one implementation). Persistence only via `ShellState.set(key,value)` → state.json.
- Compositor calls through wrapper functions (Lua form), never inline strings. JP labels gated on `Theme.jpEnabled` with romaji fallback.
- Name IPC list functions `list`, not `show` (collides with built-in target listing).

## Testing protocol

```
make lint-qml        # Qt6 qmllint + .qlint/qs shim; fails on syntax errors only
make test            # scripts/smoke.sh: isolated spawn, IPC drive, log grep, RSS check
make dist            # release tarball
tail -n 30 /run/user/1000/quickshell/by-pid/$(pgrep -f 'qs -c')/log.log   # clean-load signal
ps -o rss -p $(pgrep -f 'qs -c')
qs ipc -c yuta-qs call panel toggle
```

- `/usr/sbin/qmllint` is an UNRELATED v1.0 binary that exits 255 on modern syntax — use `/usr/lib/qt6/bin/qmllint` (Makefile already does). In pipes, `$?` reports the last command; `grep -c … || echo 0` double-fires on zero matches.
- Background spawns between tool calls: `setsid nohup … < /dev/null & disown` in their own short-timeout call (plain nohup gets reaped; spawns may hold the pipe open past timeout — output arrives anyway).
- Bare `qs ipc call` fails for `-p`-launched instances — pass the same `-p`. Without `--pid`/`--id`, ipc targets exactly ONE instance per path (usually the user's live shell) — mutating verification calls DO hit it; note prefs from logs first or target the test PID.
- Capture the spawn PID explicitly (`$!`) and kill THAT pid — NEVER `pkill -f` patterns (matches the user's live shell; this killed a session once).
- Failed-config instances exit instantly, so `pgrep -n` falls through to the user's shell — another reason to pass `--pid`.
- Hot-reload makes mid-edit-sequence logs full of transient errors (caller saved before callee) — edit-order artifacts, not bugs; verify settled code against a freshly spawned instance.
- `YUTA_DEBUG_CYCLE=1` walks all settings pages but requires zero other instances (briefly stopping the session shell).
- **Crash reports (`.cache/quickshell/crashes/`), Aug 2026: 9 of 11 are QtSvg icon crashes** — SIGSEGV in `QSvgNode::appendStyleProperty`, `QIcon::~QIcon`, `QPen::~QPen` (and garbled `Cannot open file 'stop-color:…'`/UTF-16 filenames) after loading system SVG icons like `network-wired`/`Alacritty` through `Quickshell.iconPath` + `IconImage`. This is the known **Qt 6.11.2 QtSvg recursive-destructor / heap-corruption bug (CVE-2026-8168)**, NOT a config bug — do NOT chase it in shell QML. Fix = update `qt6-svg` to a patched build. The remaining two are old (Aug 24): a `QQuickRepeater` infinite recursion (the toast ObjectModel/Repeater combo — now guarded by the smoke test's `notifycenter test` path) and a Core-frame crash. Keep the smoke toast drive intact so that regression stays caught.
