# YUTASHELL ROADMAP

> Living document. Each phase ships independently — no phase depends on a later
> one being complete. Philosophy: **Theme-only tokens, UI-kit primitives,
> IPC-driven actions, singleton services, `ShellState.set()` persistence**.
> Every new surface composes `YSurface`; every new button is `YButton`; every
> color comes from `Theme.*`.

The phases below are **future work** (planned, not yet implemented). Completed
features (formerly "Phases 1–7") are documented in `AGENTS.md` and `README.md`.

---

## Phase 1 — Visual Workspace Intelligence

> Make workspaces visual, spatial, and informative. Users think in spatial
> terms, not numbered lists.

### 1.1 Workspace Heatmap Overlay

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

### 1.2 Named Workspaces

**File:** Extend `modules/bar/Workspaces.qml`

**Plan:**
- `ShellState.wsNames`: JSON map `{1: "Code", 2: "Comms", 3: "Media", ...}`.
- Bar segment shows names instead of numbers when `wsMode === "names"`.
- New mode alongside default/numbers/pills/active/thumbnails.
- Overview shows workspace names in the grid cells.
- IPC `bar wsname <id> <name>` to assign names.

### 1.3 Cross-Monitor Workspace Awareness

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

### 1.4 Workspace Memory Usage Bars

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

## Phase 2 — Plugin Marketplace & Theme Store

> Build the ecosystem. Community plugins and themes drive adoption.

### 2.1 Plugin Registry

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

### 2.2 Theme Store

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

### 2.3 In-Shell Auto-Update

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

## Phase 3 — Context Engine & Ambient Intelligence

> The shell should adapt to the user, not the other way around. Time,
> location, activity, patterns — the shell should "just know."

### 3.1 Context Service

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

### 3.2 Adaptive Behaviors

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

### 3.3 Proactive Suggestions

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

### 3.4 Pattern Learning

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

### 3.5 Ambient Display

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

## Phase 4 — Gaming & Streaming

> Game detection, auto-configuration, OBS integration, replay buffer,
> streaming controls. The shell adapts to gaming, not the other way around.

### 4.1 Game Detector & GameMode

**File:** New `modules/gaming/GameDetector.qml` (singleton)

**Plan:**
- Detect games from focused window: `appId.startsWith("steam_app_")`
  || `appId.startsWith("wine-")` || known game list.
- On game launch:
  - Activate Feral GameMode via D-Bus (`org.feralinteractive.GameMode`).
  - Apply Hyprland rules: `render_unfocused` (fixes UE4/5 disconnect
    bug), disable blur, optionally move to dedicated workspace.
  - Switch RGB profile via OpenRGB (if available).
  - Pause break reminders when focus mode is active.
  - Hold Performance power profile.
  - Increase GPU polling rate.
- On game exit: restore all defaults.
- Expose: `gameRunning: bool`, `activeGame: string`, `gameModeActive: bool`.
- Gate GameMode on `busctl call org.feralinteractive.GameMode` probe.

### 4.2 OBS WebSocket Controller

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

### 4.3 Replay Buffer

**File:** New `modules/gaming/ReplayBuffer.qml`

**Plan:**
- Persistent `gpu-screen-recorder -r 120` process (2-minute ring buffer).
- "Save Clip" button (bar chip or keybind) sends `SIGUSR1` to dump.
- Notification: "Clip saved to ~/Videos/Replays/".
- Gate on `Recording.active` (don't run alongside manual recording).
- Configurable buffer length in `ShellState.replayBufferSec` (30–300).

### 4.4 Game Session Analytics

**File:** Extend `modules/focus/FocusMode.qml`

**Plan:**
- Log game sessions: `{game, start, end, duration}` to
  `~/.local/state/yutashell/gaming-sessions.json`.
- Stats: total time per game, daily gaming time, weekly summary.
- Bar chip in `session` segment shows today's gaming time when a game
  was played.
- Integrate with the Focus heatmap: gaming sessions shown in
  a different color.

### 4.5 MangoHud Integration

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

## Phase 5 — Smart Home Control

> Home Assistant, MQTT, Zigbee/Z-Wave — control your physical environment
> from the same shell that controls your digital one.

### 5.1 Home Assistant Service

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

### 5.2 Device Control UI

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

### 5.3 Bar Segment + Quick Controls

**Plan:**
- New bar segment `smarthome` showing:
  - Icon for most-active device (light on = bulb icon).
  - Climate temperature if thermostat is in "home" area.
  - Click opens `DevicePanel`.
  - Scroll on bar adjusts most-recent light brightness.
- Quick toggles: pin favorite devices to bar as micro-chips
  (e.g., "Living Room Light" toggle).

### 5.4 MQTT Bridge (Optional)

**File:** New `modules/smarthome/MqttBridge.qml`

**Plan:**
- For users without Home Assistant: direct MQTT via `mosquitto_sub`/
  `mosquitto_pub` (Process-based).
- Subscribe to topics: `home/sensor/#`, `home/+/state`.
- Publish commands: `home/light/office/set` → `{"brightness": 200}`.
- Config: `ShellState.mqttBroker` (host, port, topic prefix).
- Discovery: subscribe to `homeassistant/+/config` for auto-discovered
  devices (HA MQTT discovery format).

### 5.5 Automation Triggers (Extension of the rules engine)

**Plan:**
- New trigger type for the automation rules engine: `smarthome`.
  - Condition: entity state equals/contains value.
  - Action: call HA service.
- Example: "When motion sensor triggers after 11 PM, turn on hallway
  light at 20% and send notification."
- Bidirectional: HA automations can trigger YUTA shell actions via
  `qs ipc call` (external process).

**Touches:** `HomeAssistant.qml`, `DevicePanel.qml`, `MqttBridge.qml`
(all new), `BarSegments.qml`, `BarActions.qml`, `ShellState.qml`,
`RuleService.qml` (rules-engine extension), `qmldir`.

---

## Phase 6 — Phone Companion

> KDE Connect integration: phone notifications, battery, clipboard sync,
> remote commands, find-my-phone. Your phone and desktop, unified.

### 6.1 KDE Connect Service

**File:** New `modules/companion/PhoneService.qml` (singleton)

**Plan:**
- Probe: `which kdeconnect-cli` at boot; set `available: bool`.
- Poll: `kdeconnect-cli -l --refresh` (10s) for device list.
- Model: `{id, name, type, paired, connected, batteryPct,
  charging, lastSeen}`.
- Events via D-Bus subscription (`org.kde.kdeconnect.device` signals):
  battery changes, notification received, clipboard received, ringer
  triggered.

### 6.2 Phone Status Bar

**Plan:**
- New bar segment `phone` showing:
  - Phone icon (connected/disconnected).
  - Battery percentage + charging indicator.
  - Missed notification count badge.
  - Click opens `PhonePanel`.

### 6.3 Notification Relay

**Plan:**
- Mirror phone notifications to YUTA's notification server.
- When phone receives a notification: create a YUTA toast with the
  phone's app icon, title, and body.
- Inline reply: text input on the toast → `kdeconnect-cli -d <id>
  --send-sms "reply" --destination "<number>"`.
- Action buttons: "Open on Phone" (sends URL), "Dismiss" (dismisses
  on phone).

### 6.4 Clipboard Sync

**Plan:**
- Bidirectional clipboard sync between phone and desktop.
- On desktop clipboard change (from `ClipboardService`):
  `kdeconnect-cli -d <id> --share-text "$(wl-paste)"`.
- On phone clipboard change (D-Bus event): `wl-copy "$(kdeconnect-cli
  -d <id> --receive-text)"`.
- Gate: `ShellState.phoneClipSync` toggle (default false for privacy).

### 6.5 Remote Commands & Find My Phone

**Plan:**
- Remote commands: `ShellState.phoneCommands` stores
  `{name, command}` pairs. Execute via `kdeconnect-cli -d <id>
  --run-command <name>`.
- Find my phone: `kdeconnect-cli -d <id> --ring` → phone plays a loud
  ringtone. Bar button + IPC `phone find`.
- Remote input: optional mouse/keyboard forwarding (KDE Connect's
  remote input plugin).

### 6.6 Device Panel

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

## Phase 7 — Security Dashboard

> Privacy auditing, firewall management, open port visibility, VPN
> health — know your system's security posture at a glance.

### 7.1 Security Service

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

### 7.2 Firewall Manager

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

### 7.3 Open Port Monitor

**File:** New `modules/security/PortMonitor.qml`

**Plan:**
- Read `ss -tlnp` + `ss -ulnp` (15s refresh, reuses the port-scanner pattern).
- Filter: show only non-localhost listeners (external exposure).
- Color-coded: green (expected service), yellow (unknown), red
  (dangerous port open).
- Known ports database: map common ports to services (80=HTTP, 443=HTTPS,
  22=SSH, 3306=MySQL, etc.).
- Click to add firewall rule to block an exposed port.
- Integrate with CC SECURITY tab.

### 7.4 VPN Health Monitor

**File:** Extend `modules/net/Connectivity.qml`

**Plan:**
- Read `wg show` via Process (30s): handshake timestamp per peer.
- If handshake > 180s old: "VPN stale" warning.
- If `wg0` interface missing: "VPN down" alert.
- Bar chip `net` shows VPN indicator: shield icon (green = connected,
  yellow = stale, red = down, hidden = no VPN).
- Auto-reconnect: `wg-quick up wg0` if interface drops (configurable
  via `ShellState.vpnAutoReconnect`).

### 7.5 Security Score Display

**Plan:**
- Lynis security score (0-100) displayed in CC SECURITY tab as a
  ring gauge.
- Breakdown: list of passed/failed/warning tests.
- "Rescan" button triggers a fresh `lynis` audit.
- History: track score over time, show trend line (YSpark).
- Bar chip: shield icon with score number (color: green > 80,
  yellow > 60, red ≤ 60).

### 7.6 Login Audit Log

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

## Phase 8 — File Intelligence

> Beyond file browsing: intelligent search, duplicate detection,
> sync status, quick actions on the filesystem.

### 8.1 File Search Service

**File:** New `modules/files/FileSearch.qml` (singleton)

**Plan:**
- Indexed search via `fd` (if installed) or `find` fallback.
- Index: scan `~/` (maxdepth 4, skip `.cache`, `.local/share/Trash`)
  on boot and every 10 minutes.
- Model: `{path, name, ext, size, mtime, mime}`.
- Search: fuzzy match on filename + path.
- IPC `files search <query>`.

### 8.2 File Picker Panel

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

### 8.3 Duplicate Finder

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

### 8.4 Storage Visualizer

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

### 8.5 Quick File Actions

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

## Phase 9 — Hardware Control

> Fan curves, RGB lighting, keyboard backlight, GPU clocks — direct
> hardware control from the shell. Power user territory.

### 9.1 GPU Service

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

### 9.2 Fan Curve Editor

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

### 9.3 OpenRGB Controller

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

### 9.4 Keyboard Backlight Control

**File:** New `modules/hardware/KeyboardBacklight.qml`

**Plan:**
- Read/write `/sys/class/leds/*/brightness` via FileView.
- Expose: `level: int`, `maxLevel: int`, `available: bool`.
- OSD on brightness change (like display brightness OSD).
- Bar chip: keyboard icon with brightness indicator.
- Auto-dim on idle (configurable delay).

### 9.5 Hardware Monitor Panel

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

## Phase 10 — Ergonomics & Health

> Beyond break reminders: posture tracking, eye care, work-life balance,
> screen time analytics. The shell cares about the human using it.

### 10.1 Break Reminder (Enhanced)

**File:** New `modules/health/BreakReminder.qml` (singleton)

**Plan:**
- Extends Focus mode with ergonomic-specific features:
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

### 10.2 Screen Time Analytics

**File:** New `modules/health/ScreenTimeAnalytics.qml`

**Plan:**
- Track per-app foreground time (already partially done in Phase 2.4).
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

### 10.3 Work-Life Balance Indicator

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

### 10.4 Ergonomic Settings Page

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

### 10.5 Health Dashboard

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

## Phase 11 — Cross-Device Sync

> Syncthing integration, clipboard sharing, file transfer between
> desktop and other devices. One unified file ecosystem.

### 11.1 Syncthing Service

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

### 11.2 Sync Status Bar

**Plan:**
- New bar segment `sync` showing:
  - Sync icon (green = up to date, yellow = syncing, red = error).
  - Count of files needing sync.
  - Click opens `SyncPanel`.
- Notifications on: new device request, folder sync error, completed
  large sync.

### 11.3 Sync Panel

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

### 11.4 LocalSend Integration

**File:** New `modules/sync/LocalSend.qml`

**Plan:**
- Probe: `which localsend` or check port 53317.
- On local clipboard image: offer "Send to device" action on
  notification toast.
- Discovery: `GET http://localhost:53317/api/v2/neighbors` for
  visible devices.
- Send file: `POST http://<device>:53317/api/v2/upload` with multipart.
- Simple send UI: select device from discovered list → send.

### 11.5 Sync Automation

**Plan:**
- Trigger: automation rules can use Syncthing state as a
  condition (folder paused, device disconnected).
- Auto-pause sync during gaming (save bandwidth).
- Auto-resume on work profile activation.

**Touches:** `SyncthingService.qml`, `SyncPanel.qml`, `LocalSend.qml`
(all new), `BarSegments.qml`, `BarActions.qml`, `ShellState.qml`,
`RuleService.qml` (rules-engine extension), `qmldir`.

---

## Phase 12 — Notification Intelligence (Advanced)

> Beyond early notification features: smart triage, VIP contacts, digest
> batching, notification analytics, per-channel rules.

### 12.1 Smart Triage

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

### 12.2 Digest Batching

**File:** Extend `modules/notify/Notify.qml`

**Plan:**
- For "informational" priority notifications: batch into hourly digests.
- Timer collects notifications; at the hour mark, send one summary
  notification: "12 new notifications: 4 from Reddit, 3 from Hacker
  News, 3 from Twitter, 2 from GitHub."
- Per-app grouping within the digest.
- Gate: `ShellState.notifyDigest` toggle, per-app override.
- Critical notifications bypass the digest entirely.

### 12.3 Notification Analytics

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

### 12.4 Per-Channel Rules

**Plan:**
- For messaging apps (Signal, Telegram, Slack): parse notification
  body for channel/group context.
- Rules: `ShellState.notifyChannelRules`:
  `{"Slack": {"#general": "quiet", "#alerts": "vip", "#random": "block"}}`.
- Channel detection: first line of notification body often contains
  the channel name.

### 12.5 Notification Summary Card

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

## Phase 13 — Desktop Blueprint (Capstone)

> The final phase ties everything together: a complete configuration
> export/import system, first-run experience, recovery mode, and
> documentation generator. YUTA becomes a portable, reproducible
> desktop environment.

### 13.1 Blueprint Export

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

### 13.2 Blueprint Import

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

### 13.3 Blueprint Picker

**File:** New `modules/blueprint/BlueprintPicker.qml`

**Plan:**
- `YSurface` panel showing saved blueprints as cards.
- Each card: name, date, preview (bar layout thumbnail + scheme
  colors), size.
- Actions: Apply, Export (copy to clipboard), Delete, Rename.
- "Share" button: copy blueprint JSON to clipboard for pasting into
  another machine's picker.
- Community blueprints: link to a GitHub repo of shared blueprints
  (Phase 2 marketplace integration).

### 13.4 First-Run Experience

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

### 13.5 Recovery Mode

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

### 13.6 Documentation Generator

**Plan:**
- Auto-generate personalized documentation from current config:
  - `qs ipc call blueprint docs` → markdown document with:
    - Current bar layout with segment descriptions.
    - Active plugins list.
    - Custom schemes installed.
    - Automation rules summary.
    - Project profiles list.
    - Recommended keybinds.
    - IPC command reference (from the existing About page).
  - Save to `~/.local/state/yutashell/DOCS.md`.
  - Share button copies to clipboard.

### 13.7 Version Migration

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
Phase 1  (Visual Workspace Intel)  ← benefits from workspace thumbnails (complete)
Phase 2  (Plugin/Theme Store)      ← independent
Phase 3  (Context Engine)          ← benefits from profiles + automation rules (complete)
Phase 4  (Gaming & Streaming)      ← independent
Phase 5  (Smart Home)              ← independent
Phase 6  (Phone Companion)         ← independent
Phase 7  (Security Dashboard)      ← independent
Phase 8  (File Intelligence)       ← independent
Phase 9  (Hardware Control)        ← independent
Phase 10 (Ergonomics & Health)     ← benefits from focus mode
Phase 11 (Cross-Device Sync)       ← independent
Phase 12 (Notification Intel)      ← benefits from notification work (complete)
Phase 13 (Desktop Blueprint)       ← capstone: ties all phases together
```


---

## Estimate Summary

| Phase | New Files | Modified Files | Effort |
|-------|-----------|----------------|--------|
| 1 — Visual Workspace Intel | 2 | 3 | Medium |
| 2 — Plugin/Theme Store | 2 | 3 | Medium |
| 3 — Context Engine | 3 | 2 | High |
| 4 — Gaming & Streaming | 4 | 3 | Medium |
| 5 — Smart Home | 3 | 2 | Medium |
| 6 — Phone Companion | 2 | 2 | Medium |
| 7 — Security Dashboard | 3 | 2 | Medium |
| 8 — File Intelligence | 4 | 1 | Medium |
| 9 — Hardware Control | 5 | 2 | High |
| 10 — Ergonomics & Health | 5 | 2 | Medium |
| 11 — Cross-Device Sync | 3 | 2 | Medium |
| 12 — Notification Intel | 2 | 3 | Medium |
| 13 — Desktop Blueprint | 3 | 3 | Medium |

**Total: ~41 new files, ~30 modified files across all 13 remaining phases.**