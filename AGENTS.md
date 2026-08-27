# YUTASHELL

Quickshell desktop shell for Hyprland — every compositor call uses `hl.dsp.*` Lua forms, never raw dispatch strings.
Entry: `shell.qml`. Design tokens: `theme/Theme.qml` (`qs.theme`). UI primitives: `modules/common/ui`. State: `modules/common/ShellState.qml`.
README.md is the public-facing doc (features, install, IPC table) — keep it accurate when features change.
**Maintenance mode (v1.5.0)**: half-complete/dead feature modules were removed (AI, Profiles, Automation, Dev command center, Focus, System monitor, Snapshots, Pomodoro, Scratchpad, LogTailer). Keep the tree lean; don't reintroduce speculative features. 21 bar segment types, 39 IPC targets.

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
- **Notifications** (`NotificationServer`): caps props on server; `onNotification(n)` → `n.actions` is a plain JS array (NO `.values`). `tracked=true` holds it; `expire()/dismiss()` close it; C++ may enforce client expireTimeout first and destroy the wrapper — shrink our timeout by ~300 ms, set `dead` via `closed.connect`, never touch the object after close. **Inline reply**: `n.hasInlineReply` (bool), `n.inlineReplyPlaceholder` (string), `n.sendInlineReply(text)`. Server: `inlineReplySupported` (writable bool). Toast dedup (same-app 3s window bumps count badge), grouped history by appName, snooze (`_snoozeUntil`, `dnd snooze <minutes>`), search.
- **Networking**: `Networking.devices.values` → WifiDevice (`networks/scannerEnabled/mode`) / WiredDevice (`hasLink/linkSpeed/address`); enum name is **NetworkConnectivity** (not Connectivity).
- **Bluetooth**: root singleton exports as **`Bluetooth`**: `Bluetooth.defaultAdapter` → devices have `deviceName/icon/state/paired/trusted/battery` + `pair()/connect()/disconnect()/forget()`. **`Bluetooth.agent` does NOT exist in QS 0.3.1** — only `pair()`/`cancelPair()` for Just Works pairing.
- **Pipewire**: `Pipewire.nodes.values` → node `.audio` (volume LINEAR 0..1+, `muted`) + `.isStream`; perceptual steps need cubic mapping (see `AudioService.qml` `nodeFrac/stepPct`). `defaultAudioSink/Source` writable. **`PwNodePeakMonitor`** (`node`, `enabled`, `peak` float 0..1, `peaks` float list, `channels` PwAudioChannel list) — create in `Quickshell.Services.Pipewire`.
- **GlobalShortcuts**: `Quickshell.Hyprland._GlobalShortcuts` — `GlobalShortcut` type with `appid/name/description/triggerDescription` + `pressed`/`released` signals. NOT a singleton — create declaratively, handle `onPressed`.
- **IdleInhibitor**: `Quickshell.Wayland._IdleInhibitor` — `IdleInhibitor` type with `enabled` (bool) and `window`. Attach to any PanelWindow's surface to suppress idle. Not the same as `IdleMonitor`. The session segment's caffeine chip calls `IdleInhibitor.toggle()`; IPC: `session idle-inhibit`.
- **Session APIs**: `WlSessionLock` default property is `surface` (Component) with `WlSessionLockSurface {}`; `.screen` is **null until compositor assigns it** — guard before `.name`. `PamContext.config` = `/etc/pam.d/` service. `UPower` AND **`PowerProfiles`** are separate singletons (profile enum 0=saver/1=balanced/2=performance); probe power-profiles-daemon via `busctl --system introspect net.hadess.PowerProfiles …`. `PolkitAgent` instantiable; `IdleMonitor` under `Quickshell.Wayland._IdleNotify`. Exit = `Quickshell.quit()`.
- **Process**: assigning `command` does NOT start it — nothing runs until `running: true`. `StdioWriter` does not exist; write files via FileView, move with Process. Singletons instantiate lazily — shell.qml's warm-up Timer touches each service's `available` at boot.
- **ClipboardService** (widgets) — reactive clipboard monitor, polls `wl-paste`, feeds `cliphist add`.

## Launcher (kept features)

- **Frecency ranking**: `ShellState.launchStats` per-app `{count,lastLaunch}`; `frecencyScore()` = `count * 1/(1+daysSince*0.1)`.
- **Multi-mode prefixes**: `=` calculator, `>` shell command, `@` notification history, `#` color converter, `~` recent files.
- **Safe calculator**: recursive descent parser (`CalcParser.qml`) — never `Function()`/`eval`.
- **Result kinds**: `app`, `action`, `recentfile`, `shellcmd`, `notifyitem`.
- **RecentFiles** (launcher) — reads `~/.local/state/recently-used.xbel`, top 20 files, opens with `xdg-open`.

## Night Light (kept, extends audio)

`ShellState.nlSchedule` JSON `{on:"HH:MM", off:"HH:MM", enabled:bool}`. Timer checks every 60 s; handles midnight wrap (on > off = overnight). Settings: 3 presets. IPC: `nightlight schedule <on> <off> <bool>`, `nightlight schedulestatus`.

## Hyprland facts

- **Warm-client rule**: `Hyprland.dispatch('hl.dsp.*')` silently no-ops from a fresh instance unless the event socket is subscribed AND ~8 s uptime elapsed. Live shell always qualifies; 2 s test instances don't. `hyprctl eval '<lua>'` is always cold.
- `Hyprland.dispatch()` return value is meaningless — verify by effect, not return.
- Verified working verbs (see `modules/overview/Overview.qml`): `hl.dsp.focus({window="class:X"|address:"0x…"})`, `focus({workspace="N"})` (existing only; `"previous"` works), `hl.dsp.window.{float({action="toggle"}),center(),fullscreen(),resize{x,y},move{x,y},close()}`, `window.move({workspace=N})`. **INERT**: `hl.dsp.workspace.toggle_special(...)`, `focus({workspace="special:*"})`, and raw keyword strings.
- Runtime config only via `hyprctl eval '<lua>'` — plain `hyprctl keyword` fails. Nested Lua tables mirror option paths: `hl.config({general={col={active_border="…"}}})` → `general:col.active_border`.
- Color formats: `rgba()` hex parses RRGGBBAA (trailing alpha!); bare `"0xAARRGGBB"` strings parse directly; internal form is always AARRGGBB.
- `WlrLayershell` anchors are ONLY left/right/top/bottom — no horizontalCenter. Centered dock = full-width window + `mask: Region { item: <centered content> }`.
- **Workspaces**: five render modes via `ShellState.wsMode`: `default/numbers/pills/active/thumbnails`. `Dock.pinnedWindows` tracks addresses pinned to all workspaces. 21 segment types total.

## Hard-won lessons (do not regress)

### 1. Never decode full-res images for thumbnails — OOM incident
Full-res decode of 194 wallpapers hit 7–13 GB RSS and the kernel OOM-killed the session. Rules: every preview `Image` sets `sourceSize`; gate `source` on visibility; remember components inside always-instantiated singletons run at startup even when "closed". Watch RSS after opening model-heavy surfaces (healthy ≈ 370–420 MB).

### 2. awww socket race
Spawn detached (`setsid`), retry `awww img` up to 8× with 0.25 s gaps (Wallpaper.qml).

### 3. FileView drops overlapping operations
Back-to-back `writeAdapter()`/`setText()`/`reload()` within a few hundred ms silently drop. `setText()`/`writeAdapter()` also fail from async callback contexts — only reliable from `Component.onCompleted`/synchronous init. `ShellState.set()` coalesces via 80 ms flush timer; Wallpaper.writeGenConfig 100 ms; startup seeding writes only if file absent AND empty. Keep ≥0.5 s between mutating IPC calls. state.json is not watched — inject prefs via IPC or restart.

### 4. QML gotchas (one line each)
- Flickable/GridView/ListView reparent declared children into contentItem — overlays MUST be siblings (`YScroll { target }`).
- Binding loops: `contentHeight ← childrenRect.height`; hosts sized from childrenRect while children anchor to them (YRow.trailingW exists).
- `contentHeight ← loader.item.height` can go stale — sync imperatively + retargetable `Connections { target: loader.item }`.
- Declare `required property var modelData` exactly ONCE per delegate root.
- Repeater delegate redeclaring a host property → `Property value set multiple times`.
- **Anchored Loaders STRETCH their loaded root** — wrap in a filler Item + alias `loader.item.surface`; mask points at the alias.
- `IconImage` sizes ONLY via `implicitSize`; needs real URLs — resolve icon *names* via `Quickshell.iconPath(name)`. See **icon crash** section below.
- Duplicate property assignment kills the WHOLE config load (cascading `Type unavailable`).
- QtObject root has NO default property — use `Singleton` as root (childless QtObject fine).
- Every `pragma Singleton` file needs `singleton X 1.0 X.qml` in qmldir. Once a directory has qmldir, imports are STRICT: list every top-level type including windows.
- `console.log` during singleton boot doesn't reach nohup stderr; `console.warn` does. From bash, stream via `qs -p <path> log > file &`.
- This Qt build lacks `String.trimStart/trimEnd` — use `.replace(/^\s+/, "")`.
- `Qt.callLater` samples pre-compositor-configure (0×0) — probe geometry from a Timer ≥500 ms after visible.
- `Keys.on*Pressed` handlers must declare the param: `Keys.onUpPressed: event => {…}`.
- Auto-changed signal for `property var _dispList` is `on_DispListChanged`.
- Row-level MouseArea spanning the row eats trailing-slot clicks — constrain to `trailingHost.left`.
- Nav rails MUST NOT sit inside a Flickable — plain Column unless content truly scrolls.
- Don't reference another file's window instance — resolve services directly.
- A `component X:` root `id` is invisible from the delegate usage body (not in JS closures either). Keep delegate logic INSIDE the component with `required property int index`, or drive from the usage body with pure bindings.
- **`Mpris` has NO `playersChanged` signal** — media polling must run on a timer.
- **Design tokens must exist before use** — audit `Theme.` references against Theme.qml (undefined token binds `undefined`).
- `Recording.active` can read `undefined` during warm-up — coerce with `!!`.
- **YField stretched via anchors.fill loops if a parent sizes from live `height`** — size parent from `implicitHeight`.

### 5. Icon crash mitigation (QtSvg CVE-2026-8168)
Qt 6.11.2's QtSvg crashes (SIGSEGV in `QPen::~QPen` / `QSvgHandler::init`, garbage UTF-16 `Cannot open file` warns) when loading **SVG** icons through the icon engine — triggered by `Quickshell.iconPath(...)` + `IconImage`/Image for names that resolve to `.svg` (e.g. `Alacritty`, `network-wired`). Do NOT chase this in QML beyond the existing mitigation. Fix = update `qt6-svg` to a patched build. **Mitigation shipped**: all icon loads route through `ShellState.safeIcon(name)` which returns `""` for `.svg` paths so delegates fall back to their accent-square/initial/dot — never invoking the buggy plugin. When adding a new icon load, use `ShellState.safeIcon(...)`, not bare `Quickshell.iconPath(...)`.

### 6. Surfaces: compose the kit, don't hand-animate
- Bar sits at `WlrLayer.Overlay`; popups at `Top`; entrances emerge from behind the bar.
- Floating surfaces MUST compose **YSurface** — never re-animate by hand. Cascade children expose `reveal()`; dynamic animations via `Component { id: kidAnim }` + createObject.
- Closing: ESC/keybind/IPC + **YClickAway** (fullscreen catcher FIRST, card after; `mask: Region { item: open ? clickAway : null }`). PolkitDialog/LockScreen stay modal; Toasts/Osd/Dock skip the catcher. Windows linger `Theme.lingerMs` post-close.
- FastWheel is the standard wheel handler for every Flickable/GridView/ListView.
- Perf guardrails: animate opacity/transforms, never layout of anchored items (YSection scales xScale); pulses gate on `visible`; toast cards are stable in-place QtObjects across countdown ticks.

### 7. Template snippet engine + matugen
- Include-style templates edit the TARGET APP's config (managed `# >>> yutashell-matugen` blocks) via serialized `_snipQueue` → reader Process → staged FileView → copier Process.
- TOML configs use `mode: "toml-import"` merging into the existing `import`.
- Custom templates render only during matugen apply. Startup binProbe maps catalog ids → installed apps.
- matugen hard-fails without a TTY on multiple source-color candidates — always pass `--source-color-index 0`. TOML literal `'''…'''` for escaping.
- FileView semantics: JsonAdapter+writeAdapter for prefs; setText for stage+write; watchChanges+reload-on-callback for live theme recolor.

### 8. Architecture rules
- **SystemStats is the one sampler** — any new stat reader binds to `SystemStats.*`; never open a second FileView/Timer over /proc//hwmon/nvidia-smi. Shared formatters `fmtRate/fmtBytes/fmtTime/fmtTemp/fmtDuration` live there. Reads fan RPM from `sensors -j`, battery health from sysfs, emits `thermalWarning`/`thermalCritical`.
- Widgets split into singleton services (probe backend once, expose `available`) vs PanelWindows. Missing backend ⇒ flat "not installed" message or hidden feature + `Health.report(module,msg)`. **`Health` is internal-only diagnostics** — its `report`/`clear` calls coexist with feature gating; it is NOT surfaced as a bar `!` chip anymore.
- Bar is data-driven: `ShellState.barSegments` ordered `{id,zone,enabled}`; new segment = Component in Bar.qml + `BarSegments.meta` + `present()` case (+ optional `BarActions.dispatch` action). `BarSegments` exposes `layoutPresets[]` (7 presets: minimal/classic/macos/gnome/developer/gaming/ultraminimal), `applyPreset(id)`, `presetIds()`. Compact filter via `compactIds[]` (`["identity","workspaces","clock"]`). `BarActions` supports compound actions (JSON array), `shell:<cmd>`, `theme:<scheme>`, click profiles (productivity/media-first/dev). `ShellState.barCompact`, `ShellState.customPresets`.
- SettingsPanel: declarative pages behind lazy Loaders + switch; searchable two-level nav rail. ControlCenter: tabs from `ShellState.ccTabs`; per-tab Timers gate on `activePageId`/`ccOpen`.
- SNI tray menu needs `//@ pragma UseQApplication` in shell.qml — takes effect only on fresh start.
- **StorageMonitor** (widgets) — reads `df -h` every 5 s, per-mount usage with warn/crit thresholds.
- **Launcher prefix modes** — see Launcher section. Calculator uses `CalcParser.qml` (recursive descent), never `eval`.

## Conventions (enforced)

- Colors/fonts/metrics ONLY from `Theme.*` — no hardcoded values. `Theme.compactScale` (0.7x when `barCompact`); `Theme.scaledBarHeight` includes compactScale.
- UI primitives ONLY from `modules/common/ui` (YButton/YSwitch/YRow/YSection/YField/YChip/YScroll).
- Type ramp fsDisplay > fsTitle > fsBody > fsLabel > fsMicro; body sentence-case at fsBody; UPPERCASE+tracking reserved for micro-chrome.
- Acid is semantic (active/focus/primary CTA/status ticks); may pulse/draw/sweep only where meaningful.
- Motion: hover/focus snap (`movSnap`); indicators movFast/movMed OutCubic; idle life = opacity-only at movDrift; never pulse text. YButton hard-shadow press collapse is the one physical flourish.
- User actions go through IpcHandlers (keybinds + CLI + panel share one implementation). Persistence only via `ShellState.set(key,value)` → state.json.
- Compositor calls through wrapper functions (Lua form), never inline strings. JP labels gated on `Theme.jpEnabled` with romaji fallback.
- Name IPC list functions `list`, not `show`.
- **Icon loads**: always `ShellState.safeIcon(...)`, never bare `Quickshell.iconPath(...)` (see QtSvg mitigation).

## Testing protocol

```
make lint-qml        # Qt6 qmllint + .qlint/qs shim; fails on syntax errors only
make test            # scripts/smoke.sh: isolated spawn, IPC drive, log grep, RSS check
make dist            # release tarball
tail -n 30 /run/user/1000/quickshell/by-pid/$(pgrep -f 'qs -c')/log.log   # clean-load signal
ps -o rss -p $(pgrep -f 'qs -c')
qs ipc -c yuta-qs call panel toggle
```

- `/usr/sbin/qmllint` is an UNRELATED v1.0 binary that exits 255 on modern syntax — use `/usr/lib/qt6/bin/qmllint` (Makefile already does). In pipes, `$?` reports the last command.
- Background spawns between tool calls: `setsid nohup … < /dev/null & disown` in their own short-timeout call.
- Bare `qs ipc call` fails for `-p`-launched instances — pass the same `-p`. Without `--pid`/`--id`, ipc targets exactly ONE instance per path (usually the user's live shell).
- Capture the spawn PID explicitly (`$!`) and kill THAT pid — NEVER `pkill -f` patterns (matches the user's live shell).
- Failed-config instances exit instantly, so `pgrep -n` falls through to the user's shell — pass `--pid`.
- Hot-reload makes mid-edit-sequence logs full of transient errors — verify settled code against a freshly spawned instance.
- `YUTA_DEBUG_CYCLE=1` walks all settings pages but requires zero other instances.
- **Crash reports** (`.cache/quickshell/crashes/`): all are the known Qt 6.11.2 QtSvg icon bug (CVE-2026-8168), NOT config bugs — do NOT chase in shell QML. `ShellState.safeIcon` mitigates; fixing requires updating `qt6-svg`.
