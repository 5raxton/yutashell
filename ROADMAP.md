# YUTASHELL ROADMAP

> Living document. Each phase ships independently — no phase depends on a later
> one being complete. Philosophy: **Theme-only tokens, UI-kit primitives,
> IPC-driven actions, singleton services, `ShellState.set()` persistence**.
> Every new surface composes `YSurface`; every new button is `YButton`; every
> color comes from `Theme.*`.

---

## Phase 1 — Native API Adoption

> Replace subprocess shelling with Quickshell-native APIs. Unlocks every later
> phase by making the shell reactive instead of poll-based.

### 1.1 Clipboard Singleton (replace cliphist polling)

**File:** `modules/widgets/Clipboard.qml`, `modules/widgets/ClipboardPanel.qml`

Quickshell exports a `Clipboard` singleton with reactive `text` property and
change events via `wlr-data-control-unstable-v1`. Today we spawn `cliphist`
subprocesses for every copy/paste.

**Plan:**
- Create `ClipboardService.qml` singleton wrapping `Quickshell.Clipboard` +
  `cliphist` for history (cliphist still owns the ring buffer; the singleton
  watches clipboard changes reactively and only calls `cliphist add` on new
  entries).
- `Clipboard.qml` drops its `copyProc`/`delProc` polling; the panel becomes
  a live view over `ClipboardService.history`.
- Add search field (`YField`) at the top of `ClipboardPanel.qml` — filter
  `history` by substring.
- Add image preview for `Clipboard.image` entries (small `Image` thumbnail in
  `ToastCard`-style entries).

**Touches:** `ClipboardService.qml` (new), `Clipboard.qml`, `ClipboardPanel.qml`,
`qmldir`.

### 1.2 Idle Inhibitor

**File:** `modules/audio/NightLight.qml` area + new `modules/session/IdleInhibitor.qml`

Quickshell ships `Quickshell.Wayland.IdleInhibitor` which talks
`idle-inhibit-unstable-v1`. Today the shell has no way to prevent idle during
video playback or screen recording.

**Plan:**
- New singleton `IdleInhibitor.qml` exposing `active: bool` and `reason: string`.
- Auto-inhibit when `Mpris.players` has `isPlaying === true` (configurable
  in SETTINGS > POWER).
- Auto-inhibit when `Recording.active === true`.
- Manual toggle via IPC `idle inhibit`, bar chip in `session` segment, or
  a CC POWER tab toggle.
- Persist `ShellState.idleInhibitAuto` (default true).

**Touches:** `IdleInhibitor.qml` (new), `Session.qml` (IPC), `BarSegments` (chip),
`ControlCenter.qml` (POWER tab), `settings/PowerPage.qml`.

### 1.3 PipeWire Peak Monitor (Audio Visualizer)

**File:** `modules/audio/AudioService.qml`, `modules/control/ControlCenter.qml`

`PwNodePeakMonitor` gives real-time per-channel peak levels (0.0–1.0) from
any PipeWire node. Today the MEDIA tab has a static fake cava.

**Plan:**
- Add `peakMonitor` to `AudioService.qml`: a `PwNodePeakMonitor` bound to the
  default audio sink. Expose `peaks: var` (array of float) and `peakCount: int`.
- Replace the 48 static bars in the CC MEDIA tab with a reactive `Repeater`
  over `peaks`, each bar's `height` bound to `peaks[index] * maxHeight` with a
  fast `NumberAnimation` for smooth decay.
- Add an optional bar segment `audiobars` showing 5–8 tiny peak bars inline.
- Gate on `AudioService.available` (hide chip/bars when no PipeWire).

**Touches:** `AudioService.qml`, `ControlCenter.qml` MEDIA tab,
`BarSegments.qml` + new `AudioBars.qml` segment.

### 1.4 Hyprland Global Shortcuts

**Files:** `shell.qml`, new `modules/common/GlobalKeys.qml`

Today keybinds live in hyprland.conf and call `qs ipc`. `GlobalShortcut` from
`Quickshell.Hyprland` binds directly — no subprocess, lower latency, works
even when IPC is flooded.

**Plan:**
- New singleton `GlobalKeys.qml` declaring `HyprlandFocusGrab` +
  `GlobalShortcut` entries for shell-internal actions (toggle launcher, toggle
  CC, toggle picker, etc.).
- Keep external Hyprland keybinds as the user-facing default (familiar);
  `GlobalKeys` provides the low-level fast path that IPC can also reach.
- Document both paths in README.

**Touches:** `GlobalKeys.qml` (new), `shell.qml` (import), `README.md`.

---

## Phase 2 — Per-App Audio Mixer

> The single most-requested feature in every Wayland shell survey. PipeWire
> makes this trivial; the UX is the hard part.

### 2.1 Mixer Service

**File:** New `modules/audio/MixerService.qml`

**Plan:**
- Singleton reading `Pipewire.nodes.values`.
- Filter nodes where `isStream === true` (these are per-app streams).
- For each stream: expose `name`, `icon`, `volume` (linear), `muted`, `sink`
  (target device), and write-back functions `setVolume(v)`, `setMuted(m)`,
  `setSink(sinkId)`.
- Derived `streams` property re-evaluates on `Pipewire.nodes.values` change.
- Each stream icon resolved via `DesktopEntries.heuristicLookup(node.name)`.

### 2.2 Mixer Panel UI

**File:** New `modules/audio/MixerPanel.qml`, registered in `BarActions.qml`

**Plan:**
- `YSurface` panel (spawn from bar via `audiomixer` action or IPC `mixer`).
- Vertical list of stream cards: icon + name + `YSlider` + mute `YButton`.
- Output device selector at top (current sink + switch button).
- Input streams section (microphone apps) below a divider.
- Per-stream app icon from desktop entries; fallback to speaker icon.
- IPC target `mixer` (toggle/open/close).

### 2.3 Bar Segment + OSD

**Plan:**
- New bar segment `mixer` showing the current output device icon + volume.
- Click action opens `MixerPanel`.
- Scroll wheel adjusts master volume (like `audio` segment does today).
- OSD shows which app changed when per-app volume differs from master.

**Touches:** `MixerService.qml` (new), `MixerPanel.qml` (new),
`AudioService.qml` (merge peak monitor), `BarSegments.qml`,
`BarActions.qml`, `ShellState.qml`, `qmldir`.

---

## Phase 3 — Notification Intelligence

> Notifications are the most interactive surface. Today they're flat history
> with replay. Make them smart.

### 3.1 Smart Stacking & Grouping

**File:** `modules/notify/Notify.qml`, `modules/notify/NotificationCenter.qml`

**Plan:**
- Group by `appName` in the notification center. Each group is an expandable
  card: collapsed shows latest + count badge; expanded shows all with timestamps.
- `ToastStack.qml` deduplicates: if a new toast has the same `appName` as an
  existing visible toast, update the existing card in-place (fade the text) rather
  than spawning a second card. This is how COSMIC and GNOME handle chat floods.
- Persist `ShellState.notifyGrouped` (default true).

### 3.2 Inline Reply

**File:** `modules/notify/Notify.qml`, `modules/notify/ui/ToastCard.qml`

Quickshell's `NotificationServer` already supports `inlineReply`. The card UI
just doesn't expose it.

**Plan:**
- When `notification.hasReply`, show a small `YField` + send button at the
  bottom of the toast card and in the expanded center view.
- On submit: call `notification.sendInlineReply(text)`.
- Add a 2-second delay before auto-dismiss after reply (let the user see their
  message land).
- Gate on `ShellState.notifyActions` (existing toggle).

### 3.3 Notification Snooze

**File:** `modules/notify/Notify.qml`

**Plan:**
- New IPC: `dnd snooze <minutes>` — temporarily suppresses non-critical
  toasts for N minutes while keeping DND off.
- Snooze state stored as `property real _snoozeUntil: 0` (timestamp); a
  Timer fires at expiry.
- Bar chip shows "Zzz" icon when snoozed, with remaining time on hover.

### 3.4 Notification History Search

**File:** `modules/notify/NotificationCenter.qml`

**Plan:**
- Add `YField` search input at the top of the notifications tab.
- Filter the history list by body/app substring match.
- Clear button resets filter.

**Touches:** `Notify.qml`, `NotificationCenter.qml`, `ToastCard.qml`,
`ToastStack.qml`, `BarActions.qml` (DND snooze), `ShellState.qml`.

---

## Phase 4 — Workspace Intelligence

> Make workspaces visual, not just numbered. Users think in spatial terms.

### 4.1 Workspace Thumbnail Strip

**File:** `modules/bar/Workspaces.qml`

**Plan:**
- New mode `thumbnails` alongside default/numbers/pills/active.
- Uses `ScreencopyView` from `Quickshell.Wayland._Screencopy` to capture
  each workspace as a live mini-preview.
- Each workspace slot shows a scaled thumbnail (40×24 px) with the workspace
  number overlaid. Focused workspace has an acid border.
- Performance: only capture visible workspaces (bar viewport); throttle to
  1 fps for non-focused; instant for focused.
- Persist `ShellState.wsMode` extended with `"thumbnails"`.

### 4.2 Scratchpad Manager

**File:** New `modules/overview/Scratchpad.qml`

**Plan:**
- Reads `Hyprland.workspaces.values` for `special:magic` (the scratchpad
  workspace used by `Dock.qml`).
- Lists each window in the scratchpad with app icon + title.
- Click to restore (dispatch `window.move({ workspace = "previous" })`).
- Right-click to close.
- Accessible via IPC `overview scratchpad`, bar segment `scratchpad`, or
  keybind.
- Visual: `YSurface` popup with a compact list, same style as AltTab.

### 4.3 Window Pin to All Workspaces

**File:** `modules/dock/Dock.qml`, `modules/bar/Taskbar.qml`

**Plan:**
- Right-click context menu on dock icon or taskbar entry adds "Pin to All
  Workspaces" option.
- Dispatch: `hl.dsp.window.move({ workspace = "special:pinned" })` then
  toggle `pinned` state in a local map.
- Pinned windows show a small pin icon overlay in the taskbar.
- Persist pinned window app IDs in `ShellState.pinnedApps`.

### 4.4 Overview Improvements

**File:** `modules/overview/OverviewGrid.qml`

**Plan:**
- Live window thumbnails via `ScreencopyView` (same API as 4.1).
- Drag windows between workspaces in the grid.
- Hover preview: enlarge the window thumbnail on mouse-over.
- Search field to filter windows by app name.

**Touches:** `Workspaces.qml`, `Scratchpad.qml` (new), `Dock.qml`,
`Taskbar.qml`, `OverviewGrid.qml`, `ShellState.qml`, `BarSegments.qml`,
`qmldir`.

---

## Phase 5 — Secure Session & Bluetooth

> Lock screen is a security surface. Make it crash-safe. Bluetooth pairing
> should be native, not `bluetoothctl`.

### 5.1 Wayland Session Lock

**File:** `modules/session/LockScreen.qml`

Today the lock screen is a FloatingWindow with PAM auth. If Quickshell
crashes, the session is unlocked. `WlSessionLock` is the Wayland-native
solution: the compositor blacks out the session and only unlocks when the
lock surface confirms.

**Plan:**
- Replace the `FloatingWindow` root with `WlSessionLock`.
- Inside: `WlSessionLockSurface` per screen (guarded `.screen` null check).
- Each surface shows: avatar + clock + password field + PAM bridge.
- `PamContext` integration unchanged (already correct).
- Multi-monitor: iterate `Quickshell.screens`, create a `WlSessionLockSurface`
  for each; guard `.name` until compositor assigns.
- Fallback: if `WlSessionLock` unavailable (older compositor), fall back to
  the current FloatingWindow approach with a health warning.
- On successful unlock: `lock.unlock()` releases the session lock.
- On crash: compositor kills the session (secure by default).

### 5.2 Bluetooth Pairing Agent

**File:** `modules/net/BluetoothPanel.qml`

Quickshell's `Bluetooth.agent` handles pairing requests natively. Today we
rely on `bluetoothctl` subprocesses.

**Plan:**
- In `BluetoothPanel.qml`, when the user taps "Pair" on a discovered device:
  call `device.pair()`.
- Connect to `Bluetooth.agent.pairingRequested` signal: show a `YSurface`
  modal dialog with PIN/passkey entry field.
- On confirm: `Bluetooth.agent.respondToRequest(response)`.
- On cancel: `Bluetooth.agent.reject()`.
- Show pairing progress (spinner in the device card).
- Persist paired device state via existing `Bluetooth.defaultAdapter` tracking.

### 5.3 Caffeine Toggle (Idle Inhibitor Manual)

**File:** `modules/session/Session.qml`, bar `session` segment

**Plan:**
- Wire `IdleInhibitor.active` toggle into the session segment's right-click
  context menu or a dedicated bar chip.
- Keyboard shortcut: `ipc session idle toggle`.
- Visual: small coffee cup icon in the bar when inhibitor is active.
- Auto-activate during fullscreen apps (detect `HyprlandToplevel.fullscreen`).

**Touches:** `LockScreen.qml`, `BluetoothPanel.qml`, `Session.qml`,
`IdleInhibitor.qml`, `BarSegments.qml`.

---

## Phase 6 — Information Density Widgets

> Give power users the data they need at a glance, without leaving the shell.

### 6.1 Network Details Widget

**File:** New `modules/net/NetDetails.qml`

**Plan:**
- `YSurface` panel showing: active interface, SSID/ESSID, IP4/IP6 addresses,
  gateway, DNS servers, signal strength dBm + percentage, link speed (wired),
  VPN status.
- Data sourced from `nmcli` (one-shot `Process` + `StdioCollector`, 5s refresh).
- Accessible via IPC `network details`, right-click on the bar `net` segment,
  or CC NETWORK tab "Details" button.
- Copy IP address to clipboard on click (like iNiR's network widget).

### 6.2 Storage Monitor

**File:** New `modules/widgets/StorageMonitor.qml`

**Plan:**
- Singleton reading `df -h` via Process (5s interval, like SystemStats SLOW).
- Expose per-mount: device, mount point, used/total, percent, fs type.
- Derived signals: `warnAt` (85%), `critAt` (95%) per mount.
- Bar segment `disk` already shows I/O rates; enhance it with a tooltip
  showing per-mount usage breakdown.
- CC SYSTEM tab: add a storage section below the sparklines.

### 6.3 Process Killer

**File:** New `modules/widgets/ProcessKiller.qml`

**Plan:**
- `YSurface` panel with a `YField` search + list of matching processes.
- Data from `ps aux --sort=-%mem` (one-shot Process).
- Each row: PID, user, CPU%, MEM%, command (truncated).
- Kill button (`YButton` danger tone) sends `SIGTERM`; shift+click sends
  `SIGKILL`.
- Confirmation dialog for SIGKILL via `YClickAway` modal.
- IPC `processes kill <pid>`.

### 6.4 Battery Health & Time Estimates

**File:** `modules/common/SystemStats.qml`

**Plan:**
- Extend battery stats: read `energy_full` / `energy_full_design` from UPower
  (or `/sys/class/power_supply/BAT*/energy_*` files).
- Compute wear level: `(1 - full/design) * 100`.
- Compute time-to-empty/charge from `energy_rate` and current capacity.
- Expose: `batHealth`, `batWearPct`, `batTimeLeft`, `batTimeToFull`.
- `StatCell` shows time remaining instead of just percentage when
  `batTimeLeft > 0`.
- CC POWER tab: show battery health ring + wear percentage.

### 6.5 Fan Speed / Thermal OSD

**File:** `modules/audio/Osd.qml`, `modules/common/SystemStats.qml`

**Plan:**
- Extend `SystemStats._sampleTempJson` to also read `fan*_input` from hwmon.
- New `Osd` kind `"thermal"`: shows a warning card when any sensor crosses
  `Theme.tempWarn` or `Theme.tempCrit`.
- Non-intrusive: appears once per threshold crossing, auto-dismiss after 4s.
- Gate on `ShellState.osdThermal` toggle.

**Touches:** `NetDetails.qml` (new), `StorageMonitor.qml` (new),
`ProcessKiller.qml` (new), `SystemStats.qml`, `Osd.qml`,
`ControlCenter.qml` (SYSTEM + POWER tabs), `BarSegments.qml`,
`ShellState.qml`.

---

## Phase 7 — Customization Power

> Let users reshape the shell without touching QML.

### 7.1 Layout Presets

**File:** New `modules/settings/PresetsPage.qml`

**Plan:**
- 7 built-in presets shipped as JSON files in `theme/presets/`:
  - **Minimal** — identity + workspaces + clock (3 segments, small bar)
  - **Classic** — identity + workspaces + taskbar + tray + media + clock
  - **macOS** — centered dock-style: workspaces + activewindow + clock (centered)
  - **GNOME** — top bar: workspaces + clock + system tray (right)
  - **Developer** — identity + workspaces + taskbar + cpu + mem + net + clock
  - **Gaming** — workspaces + media + session + clock + recording chip
  - **Ultra-minimal** — clock only (floating)
- Each preset is a JSON object matching the `barSegments` format.
- One-click apply: `ShellState.set("barSegments", JSON.stringify(preset.segments))`.
  Also sets `barScale`, `barPosition`, `wsMode`, `dockEnabled`, `dockMode`.
- Custom presets: "Save current as preset" button stores to
  `ShellState.customPresets`.
- Settings page: grid of preset cards with thumbnail preview + name + apply
  button.

### 7.2 Per-Monitor Bar Configuration

**File:** `modules/bar/Bar.qml`, `modules/bar/BarSegments.qml`

**Plan:**
- Extend `barSegments` to support per-monitor overrides:
  `ShellState.barSegmentsMonitor` keyed by screen name.
- When a monitor has no override, inherit the global config.
- Settings UI: dropdown to select target monitor before editing segments.
- Bar reads its `screen.name` and resolves the correct segment list.
- Keep the default behavior identical (global config for all monitors).

### 7.3 Compact/Full Bar Toggle

**File:** `modules/bar/Bar.qml`

**Plan:**
- New persisted `ShellState.barCompact` (default false).
- Compact mode: only shows identity + workspaces + clock. All other segments
  hide. Bar height scales to 0.7x.
- Full mode: all enabled segments visible (current behavior).
- Toggle via IPC `bar compact`, right-click on bar, or keybind.
- Animated transition: segments fade out, bar height tweens via
  `transform: Scale`.

### 7.4 Custom Bar Click Actions (Enhanced)

**File:** `modules/bar/BarActions.qml`

**Plan:**
- Extend the existing `barClick` map to support compound actions:
  `"action": ["action1", "action2"]` executes in sequence.
- Add new action types: `toggle` (toggle any panel), `ipc` (arbitrary IPC
  call), `shell` (run a shell command), `theme` (switch scheme).
- Preset click profiles in settings: "productivity" (CC on click),
  "media-first" (media widget on click), "dev" (clipboard on click).

**Touches:** `PresetsPage.qml` (new), `theme/presets/*.json` (new),
`Bar.qml`, `BarSegments.qml`, `BarActions.qml`, `ShellState.qml`,
`SettingsPanel.qml`, `qmldir`.

---

## Phase 8 — Smart Launcher & Command Palette

> The launcher is the primary interaction point. Make it think.

### 8.1 Frecency Ranking

**File:** `modules/launcher/AppLauncher.qml`

**Plan:**
- Track launch counts and timestamps in `ShellState.launchStats`:
  `{ "appId": { "count": N, "lastLaunch": timestamp } }`.
- On app launch (`e.execute()`), increment count and update timestamp.
- Sort search results by frecency score:
  `score = count * (1 / (1 + daysSinceLastLaunch))`.
- Pinned apps always appear first; recents second; frecency third; alpha last.
- Decay factor: apps not launched in 30+ days drop below never-launched apps.

### 8.2 Multi-Mode Launcher (Command Palette)

**File:** `modules/launcher/AppLauncher.qml`

**Plan:**
- Extend the existing `:command` mode with additional built-in evaluators:
  - `=` prefix: math expression evaluator (JS `eval` with sandboxed Math).
  - `>` prefix: run shell command, show output in a card.
  - `@` prefix: search notification history.
  - `#` prefix: color converter (hex → rgb → hsl).
  - `~` prefix: file browser (show recent files from xdg-recent, or
    fuzzy-match files in `~/`).
- Each mode has a distinct icon chip in the search bar.
- Results render in a unified card format with app icon / result icon +
  primary text + secondary text.
- Keep current app search as default (no prefix).

### 8.3 Recent Files Integration

**File:** New `modules/launcher/RecentFiles.qml`

**Plan:**
- Read `recently-used.xbel` (XDG standard) via FileView.
- Parse the XML into a list of `{ uri, name, timestamp, mimeType }`.
- Expose top 20 most recent files.
- In launcher: typing `~` shows recent files; clicking opens with
  `xdg-open`.
- IPC `launcher recents` to open directly to the recent files view.

### 8.4 Launcher Calculator Widget

**File:** `modules/launcher/AppLauncher.qml`

**Plan:**
- When input starts with `=`, evaluate the expression using a safe parser
  (no `eval`; tokenize numbers, operators, parentheses; recursive descent).
- Show result in a large display card at the top of results.
- Copy result to clipboard on Enter.
- Support basic ops: `+`, `-`, `*`, `/`, `%`, `^`, `sqrt()`, `sin()`,
  `cos()`, `pi`, `e`.

**Touches:** `AppLauncher.qml`, `RecentFiles.qml` (new),
`fuzzy.js` (extend), `ShellState.qml`.

---

## Phase 9 — Power User Tools

> Small, focused tools that power users reach for daily.

### 9.1 Pomodoro Timer

**File:** New `modules/widgets/Pomodoro.qml`

**Plan:**
- Singleton with `workMin` (default 25), `breakMin` (default 5),
  `longBreakMin` (default 15), `roundsBeforeLong` (default 4).
- State machine: idle → work → break → work → ... → longBreak → idle.
- Timer drives a bar chip showing remaining time (MM:SS countdown).
- On phase change: `Notify.announce("POMODORO", "Time for a break!", 3)` or
  "Back to work!".
- IPC: `pomodoro start/pause/reset/status`.
- Visual: bar chip color toggles acid (work) vs faint (break).
- Settings: configurable durations in SETTINGS > SYSTEM > Misc.

### 9.2 Keybind Cheatsheet

**File:** New `modules/widgets/Cheatsheet.qml`

**Plan:**
- Parse Hyprland keybinds from `hl.config` or `hyprctl -j binds` (one-shot
  Process).
- Display in a `YSurface` panel: grouped by category (general, windows,
  workspaces, media, session, custom).
- Search field filters by key combo or description.
- Accessible via IPC `compositor binds` or bar chip in `session` segment.
- Falls back to a static embedded list if parsing fails.

### 9.3 World Clock

**File:** New `modules/widgets/WorldClock.qml`

**Plan:**
- Configurable list of timezones in `ShellState.worldClockZones`:
  `["America/New_York", "Europe/London", "Asia/Tokyo"]`.
- Each timezone shows in a `YSurface` card: city name + analog/digital clock
  + offset from local.
- Bar segment `worldclock` shows the next timezone's time with city label.
- Click cycles through timezones; scroll adjusts.
- Add timezone via a search field (fuzzy match against IANA timezone list).

### 9.4 Screen Time Tracker

**File:** New `modules/widgets/ScreenTime.qml`

**Plan:**
- Singleton tracking active window changes via `Hyprland.toplevels.values`
  activation events.
- For each app: accumulate time-in-foreground (seconds).
- Reset daily at midnight (persist today's data in
  `~/.local/state/yutashell/screentime.json`).
- `YSurface` panel with a bar chart of top 10 apps by time.
- Bar chip showing total active time today.
- IPC `screentime status/list/reset`.
- Privacy: all data local, never uploaded. Opt-in via `ShellState.screentimeEnabled`.

### 9.5 Night Light Schedule

**File:** `modules/audio/NightLight.qml`

**Plan:**
- Extend `NightLight` with scheduling: `ShellState.nlSchedule` holds
  `{ on: "21:00", off: "07:00", enabled: false }`.
- Timer checks every 60s; auto-enables/disables based on current time.
- Handles midnight wrap (on > off means overnight).
- 3 presets in settings: "Sunset–Sunrise" (manual), "21:00–07:00",
  "Custom".
- Gate on `NightLight.available`.

**Touches:** `Pomodoro.qml` (new), `Cheatsheet.qml` (new),
`WorldClock.qml` (new), `ScreenTime.qml` (new), `NightLight.qml`,
`BarSegments.qml`, `ShellState.qml`, `SettingsPanel.qml`.

---

## Phase 10 — Polish, Accessibility & Performance

> The difference between "cool project" and "daily driver." Every animation
> smooth, every interaction keyboard-accessible, every pixel intentional.

### 10.1 Reduced Motion Support

**File:** `theme/Theme.qml`, all animated surfaces

**Plan:**
- Add `Theme.reducedMotion: bool` (persisted in `ShellState.reducedMotion`,
  default auto-detect from `Quickshell.env("prefers-reduced-motion")` or
  manual toggle).
- When true: all `NumberAnimation` durations snap to 0 (except toast entrance
  which fades at 80ms). `Behavior on` blocks use `enabled: !Theme.reducedMotion`.
- `YButton` press shadow collapse → instant opacity toggle.
- Scanline sweep → instant.
- `YPulse` breathing → static.
- Boot entrance → instant.
- Settings: Accessibility page with reduced motion toggle + preview.

### 10.2 High Contrast Mode

**File:** `theme/Theme.qml`, `theme/schemes/`

**Plan:**
- Add `Theme.highContrast: bool` (persisted).
- When true: override `Theme.ink` → `#000000` (light) or `#ffffff` (dark),
  `Theme.bg` → `#ffffff` (light) or `#000000` (dark), `Theme.line` → full
  opacity, `Theme.faint` → `Theme.ink`.
- Acid color stays the same (user's accent).
- Add a `high-contrast.json` scheme that auto-enables this mode.
- All UI primitives already use `Theme.*` tokens — this "just works."

### 10.3 Keyboard Navigation

**File:** All panel surfaces

**Plan:**
- Every `YSurface` panel gets `Keys.onEscapePressed: root.close()` (most
  already have this).
- `FocusScope` on panel open: first interactive element grabs focus.
- `Keys.onTabPressed` / `Keys.onBacktabPressed` cycle through interactive
  elements (`YButton`, `YField`, `YSwitch`) within the panel.
- Visible focus ring: `Rectangle` border on `activeFocus` for all
  interactive elements (add `focusVisible: true` styling to UI kit).
- `Keys.onLeftPressed` / `Keys.onRightPressed` for slider adjustments.
- Settings panel already mostly keyboard-nav; extend to CC and launcher.

### 10.4 Performance Audit & Optimization

**Plan:**
- Profile RSS after opening each panel (target: <500 MB steady state).
- Audit all `readonly property var` bindings that recreate objects per
  evaluation — convert to imperative updates where list size > 20 items.
- Gate `ScreencopyView` (Phase 4.1) captures behind `visible` to avoid
  offscreen rendering.
- Ensure all `Image` elements gate `source` on `visible` (OOM guardrail
  from AGENTS.md lesson #1).
- Audit `FileView` instances: consolidate where possible (one FileView per
  file, not per consumer).
- `Timer` audit: ensure no timer runs when its consumer is invisible.
- Use `Component.onDestruction` to clean up process handles.

### 10.5 Documentation & Onboarding

**Files:** `README.md`, `AGENTS.md`, new `docs/`

**Plan:**
- Update README.md with all new features, updated IPC table, new keybinds.
- Add `docs/ARCHITECTURE.md`: module map, singleton graph, data flow diagram.
- Add `docs/IPC.md`: complete IPC reference (every target, every function,
  every parameter, return value).
- Add `docs/THEMING.md`: how to create custom schemes, how matugen integration
  works, how to add custom templates.
- Add `docs/PLUGINS.md`: how to write a plugin (manifest format, available
  APIs, examples).
- Add `docs/KEYBINDS.md`: recommended Hyprland keybinds for every action.
- Settings > About page: link to docs, show version, state dump.

**Touches:** `Theme.qml`, `Theme.qml` high-contrast scheme, all panel
surfaces (keyboard nav), `README.md`, `docs/*`.

---

## Dependency Graph

```
Phase 1  (Native APIs)
  ├── 2  (Audio Mixer)         ← needs PwNodePeakMonitor
  ├── 4  (Workspace Intel)     ← needs ScreencopyView
  ├── 5  (Session Security)    ← needs IdleInhibitor
  └── 10 (Polish)              ← needs ReducedMotion from Theme

Phase 3  (Notifications)       ← independent
Phase 6  (Info Widgets)        ← independent
Phase 7  (Customization)       ← independent
Phase 8  (Smart Launcher)      ← independent
Phase 9  (Power User Tools)    ← independent
```

Phases 3, 6, 7, 8, 9 are fully independent and can be developed in any order
or in parallel. Phase 1 is the foundation for 2, 4, 5, and parts of 10.

---

## Estimate Summary

| Phase | New Files | Modified Files | Effort |
|-------|-----------|----------------|--------|
| 1 — Native APIs | 3 | 6 | Medium |
| 2 — Audio Mixer | 2 | 4 | Medium |
| 3 — Notifications | 0 | 4 | Low |
| 4 — Workspace Intel | 1 | 5 | High |
| 5 — Secure Session | 0 | 3 | Medium |
| 6 — Info Widgets | 3 | 3 | Medium |
| 7 — Customization | 2 | 5 | Medium |
| 8 — Smart Launcher | 1 | 2 | Medium |
| 9 — Power User Tools | 4 | 2 | Medium |
| 10 — Polish & A11y | 0 | All | Low (per file) |

---

## Phase 11 — AI Desktop Agent

> The single biggest differentiator. No Quickshell shell has deep AI
> integration. YUTA already knows everything about the desktop state —
> pipe that context to an LLM and the shell becomes genuinely intelligent.

### 11.1 AiService Core

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

### 11.2 Context Engine

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

### 11.3 Command Palette (AI-Powered)

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

### 11.4 Chat Sidebar

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

### 11.5 Voice Input

**File:** New `modules/ai/VoiceInput.qml`

**Plan:**
- Keybind or button triggers recording via PipeWire (default source).
- Save to temp WAV via Process: `pw-record --format=s16le --rate=16000
  /tmp/yuta-voice.wav`.
- Transcribe via `faster-whisper` (local) or `whisper.cpp` Process.
- Inject transcript into Command Palette or Chat input.
- Visual: pulsing mic icon in the command palette during recording.
- Gate on `available`: probe `which faster-whisper` at boot.

### 11.6 Screenshot-to-Action

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

## Phase 12 — Project Profiles

> One-switch workspace contexts. The desktop equivalent of "workspaces" but
> at a higher level: apps, wallpaper, power, DND, and layout — all bundled.

### 12.1 Profile Service

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

### 12.2 Profile Picker

**File:** New `modules/profiles/ProfilePicker.qml`

**Plan:**
- `YSurface` panel showing profile cards in a grid.
- Each card: icon + name + active indicator + edit/delete buttons.
- "Save Current" button creates a new profile from live state.
- "Apply" button switches to that profile.
- Drag-to-reorder (reuses the Kanban pattern from Bar settings).
- IPC `profiles list/apply/save`.

### 12.3 Bar Segment + Auto-Switch

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

## Phase 13 — Automation Rules Engine

> Declarative triggers + actions. "When X happens, do Y." Power user
> superpowers without writing scripts.

### 13.1 Rules Service

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

### 13.2 Rules Editor

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

### 13.3 Built-in Rule Templates

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

## Phase 14 — Developer Command Center

> Everything a developer needs in one surface: git, Docker, CI/CD, logs,
> tmux. No more alt-tabbing between terminal windows.

### 14.1 Git Status Bar Widget

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

### 14.2 Docker Compose Monitor

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

### 14.3 CI/CD Pipeline Status

**File:** New `modules/dev/CIService.qml`

**Plan:**
- Reads GitHub Actions via `gh run list --json` (60s refresh).
- Model: `{repo, branch, name, status, conclusion, url, createdAt}`.
- Bar segment `cicd` showing checkmark/X/spinner per pinned repo.
- Failure triggers notification with "View" action opening browser.
- Configurable repos in `ShellState.cicdRepos`: `["owner/repo1", ...]`.
- Auto-detect repos from focused terminal's git remote.

### 14.4 Log Tailer

**File:** New `modules/dev/LogTailer.qml`

**Plan:**
- `YSurface` panel with tabbed log views.
- Sources: `journalctl -f -p warning` (system), `hyprland` (via log path),
  Docker containers (per-service), custom `Process` streams.
- Search bar with regex filter; errors highlighted in `Theme.alert`.
- Pin favorite sources (persisted in `ShellState.logPins`).
- Auto-scroll with pause on manual scroll-up.
- IPC `dev logs`.

### 14.5 Tmux/Zellij Dashboard

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

### 14.6 Port Scanner & Tunnel Manager

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

## Phase 15 — Focus & Wellness

> Productivity isn't just about features — it's about healthy computer use.
> Deep focus mode, break reminders, screen time awareness.

### 15.1 Deep Focus Mode

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

### 15.2 Focus Calendar & Heatmap

**File:** New `modules/focus/FocusCalendar.qml`

**Plan:**
- CalendarGrid (reusing existing component) with day cells colored by
  focus minutes: no data → transparent, < 30m → light acid, < 2h →
  medium acid, 2h+ → full acid.
- Month view with navigation.
- Click a day to see that day's sessions list.
- CC CALENDAR tab extension: "Focus" sub-tab showing the heatmap.
- Stats summary: total this week, current streak, best streak.

### 15.3 Break Overlay

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

### 15.4 Caffeine Toggle (Deep)

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

## Phase 16 — Smart System Monitor

> Go beyond basic stats. Battery health, thermal intelligence, power
> budgets, network diagnostics, workspace memory visualization.

### 16.1 Battery Intelligence

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

### 16.2 Thermal Monitor & Auto-Throttle

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

### 16.3 Power Budget Visualizer

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

### 16.4 Network Health Monitor

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

### 16.5 Workspace Memory Heatmap

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

## Phase 17 — Session Snapshots & Restore

> Save and restore entire desktop states. Disaster recovery meets workflow
> portability.

### 17.1 Snapshot Service

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

### 17.2 Snapshot Picker

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

### 17.3 Bar Segment

**Plan:**
- New bar segment `snapshots` showing a save icon + count.
- Click saves a quick snapshot (auto-named by timestamp).
- Right-click opens the snapshot picker.
- Notification on successful save/restore.

**Touches:** `SnapshotService.qml`, `SnapshotPicker.qml` (new),
`BarSegments.qml`, `BarActions.qml`, `Session.qml`,
`ShellState.qml`, `qmldir`.

---

## Phase 18 — Visual Workspace Intelligence

> Make workspaces visual, spatial, and informative. Users think in spatial
> terms, not numbered lists.

### 18.1 Workspace Heatmap Overlay

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

### 18.2 Named Workspaces

**File:** Extend `modules/bar/Workspaces.qml`

**Plan:**
- `ShellState.wsNames`: JSON map `{1: "Code", 2: "Comms", 3: "Media", ...}`.
- Bar segment shows names instead of numbers when `wsMode === "names"`.
- New mode alongside default/numbers/pills/active/thumbnails.
- Overview shows workspace names in the grid cells.
- IPC `bar wsname <id> <name>` to assign names.

### 18.3 Cross-Monitor Workspace Awareness

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

### 18.4 Workspace Memory Usage Bars

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

## Phase 19 — Plugin Marketplace & Theme Store

> Build the ecosystem. Community plugins and themes drive adoption.

### 19.1 Plugin Registry

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

### 19.2 Theme Store

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

### 19.3 In-Shell Auto-Update

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

## Phase 20 — Context Engine & Ambient Intelligence

> The shell should adapt to the user, not the other way around. Time,
> location, activity, patterns — the shell should "just know."

### 20.1 Context Service

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

### 20.2 Adaptive Behaviors

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

### 20.3 Proactive Suggestions

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

### 20.4 Pattern Learning

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

### 20.5 Ambient Display

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

## Updated Dependency Graph

```
Phase 1  (Native APIs)
  ├── 2  (Audio Mixer)              ← PwPeakMonitor
  ├── 4  (Workspace Intel)          ← ScreencopyView
  ├── 5  (Session Security)         ← IdleInhibitor
  └── 10 (Polish & A11y)            ← ReducedMotion

Phase 3  (Notifications)            ← independent
Phase 6  (Info Widgets)             ← independent
Phase 7  (Customization)            ← independent
Phase 8  (Smart Launcher)           ← independent
Phase 9  (Power User Tools)         ← independent

Phase 11 (AI Agent)                 ← independent (uses existing APIs)
Phase 12 (Project Profiles)         ← independent
Phase 13 (Automation Rules)         ← benefits from Phase 12 profiles
Phase 14 (Dev Command Center)       ← independent
Phase 15 (Focus & Wellness)         ← benefits from Phase 1 idle inhibitor
Phase 16 (Smart System Monitor)     ← benefits from Phase 6 info widgets
Phase 17 (Session Snapshots)        ← independent
Phase 18 (Visual Workspace Intel)   ← benefits from Phase 4 workspace thumbnails
Phase 19 (Plugin/Theme Store)       ← independent
Phase 20 (Context Engine)           ← benefits from Phase 12 profiles + Phase 13 rules
```

---

## Full Estimate Summary (All 20 Phases)

| Phase | New Files | Modified Files | Effort |
|-------|-----------|----------------|--------|
| 1 — Native APIs | 3 | 6 | Medium |
| 2 — Audio Mixer | 2 | 4 | Medium |
| 3 — Notifications | 0 | 4 | Low |
| 4 — Workspace Intel | 1 | 5 | High |
| 5 — Secure Session | 0 | 3 | Medium |
| 6 — Info Widgets | 3 | 3 | Medium |
| 7 — Customization | 2 | 5 | Medium |
| 8 — Smart Launcher | 1 | 2 | Medium |
| 9 — Power User Tools | 4 | 2 | Medium |
| 10 — Polish & A11y | 0 | All | Low (per file) |
| 11 — AI Desktop Agent | 6 | 3 | High |
| 12 — Project Profiles | 2 | 3 | Medium |
| 13 — Automation Rules | 2 | 2 | Medium |
| 14 — Dev Command Center | 6 | 3 | High |
| 15 — Focus & Wellness | 3 | 3 | Medium |
| 16 — Smart System Monitor | 4 | 3 | Medium |
| 17 — Session Snapshots | 2 | 2 | Medium |
| 18 — Visual Workspace Intel | 2 | 3 | Medium |
| 19 — Plugin/Theme Store | 2 | 3 | Medium |
| 20 — Context Engine | 3 | 2 | High |

**Total: ~47 new files, ~55 modified files across all 20 phases.**
