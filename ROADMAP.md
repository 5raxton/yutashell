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

Total: ~16 new files, ~35 modified files across all phases.
