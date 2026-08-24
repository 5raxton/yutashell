# Yuta Shell Roadmap v2.0 — "Operation Perfection"

**Goal**: Integrate every feature from DankMaterialShell, Ryoku, and caelestia-shell into the yuta shell, producing a feature-complete, production-ready configuration with zero dependencies on other configs.

This roadmap covers 10 phases, from foundation to polish. Each phase builds on the previous one. Track progress by checking off items and verifying against the live shell log.

---

## PHASE 1: Foundation & Module Infrastructure

**Objective**: Establish the core architecture that all other phases depend on.

- [ ] **1.1** Ensure all modules have `qmldir` declarations (already fixed: launcher, picker, settings, widgets)
- [ ] **1.2** Audit all `pragma Singleton` declarations — ensure every singleton has `id: root` and `import QtQuick / import Quickshell` at top
- [ ] **1.3** Add `Component.onCompleted` startup probes to all service singletons that need binary detection (DisplayService, Weather, NightLight, ColorPicker, Updates, Recording, ColorPicker) — see `DisplayService.qml` fix as template
- [ ] **1.4** Implement `ShellState.set()` coalescing flush timer (80ms) across all modules — already in place, verify no warnings in logs
- [ ] **1.5** Add warm-up `Timer` in `shell.qml` that reads `*.available` properties to pre-instantiate lazy singletons at boot (already present, verify it runs at startup)
- [ ] **1.6** Ensure `UseQApplication` pragma only takes effect on fresh start (document in AGENTS.md lesson 9)
- [ ] **1.7** Verify `qmldir` files in ALL modules declare types correctly (singleton vs regular) — run `ls modules/*/qmldir` and confirm each

**Cool bits from references**:
- DankMaterialShell: `Variants` per-screen bar/dock instances via `Quickshell.screens`
- Ryoku: `ShellRoot` with per-monitor `ShellState` slices via `barkit` pattern
- caelestia-shell: Modular `ShellRoot` with `GSFLoader` / `ServiceLoader` singletons

**Verification**: `qs -p .` starts clean; `pgrep -af 'qs -c'` shows correct PID; RSS in 250-500 MB range.

---

## PHASE 2: Service Layer — IPC & System Integration

**Objective**: Deploy every system service (audio, network, bluetooth, display, weather, etc.) as singletons that communicate with the Go backend via IPC.

- [ ] **2.1** `AudioService` — volume control, mute, overdrive ceiling, node property tracking (already complete; verify `AudioService.stepPct()`, `AudioService.toggleMute()`, `AudioService.nodePct()`, `AudioService.nodeFrac()` work)
- [ ] **2.2** `DisplayService` — ddcutil brightness control with auto-probe on startup (`Component.onCompleted` calls `poll()`), threshold reporting via `Health.report()`, `_dispList` property, `on_DispListChanged` signal
- [ ] **2.3** `NightLight` — hyprsunset integration, temperature control, `available`/`active` properties, `Health.report()` when binary absent
- [ ] **2.4** `Weather` — open-meteo fetch via curl, 30-min poll interval, cached payload, `configured`/`available`/`fetching` properties, `codeInfo()` for WMO weather codes
- [ ] **2.5** `Updates` — `checkupdates` poll (pacman-contrib), 6h re-check, `Notify.announce()` on updates available, `openTerminal()` launch
- [ ] **2.6** `Bluetooth` — `Bluetooth.defaultAdapter` with `devices`, `enabled`, `pair()`, `connect()`, `disconnect()`, `forget()`
- [ ] **2.7** `Connectivity` — WiFi + wired state, `strength` tiers, `activeWifi`, `wiredSpeed`, `airplane` mode, `NetWatch` lazy polling via nmcli
- [ ] **2.8** `Session` — power menu (lock/suspend/hibernate/reboot/poweroff), `PowerProfiles` via `busctl introspect`, idle monitor with `respectInhibitors`, logind inhibitor poll (`loginctl list-inhibitors`)
- [ ] **2.9** `Pipewire` — `Pipewire.defaultAudioSink`/`defaultAudioSource` (writable), `Pipewire.nodes.values` with `PwNodeAudio` (`volume` linear 0..1+, `muted`), `PwObjectTracker` for node tracking, `fracToVol()`/`volToFrac()` cubic taper
- [ ] **2.10** `Clipboard` — cliphist 0.7 support: `list` output `id<TAB>preview`, binary entries with raw bytes, `cliphist decode <id> | wl-copy`, `cliphist delete <id>`
- [ ] **2.11** `ColorPicker` — hyprpicker absence reporting via `Health.report("hyprpicker", ...)`, `pick()` degrades to toast, `lastColor` property
- [ ] **2.12** `Recording` — `gpu-screen-recorder` detection, `active` property, 5s poll interval, `stopProc` with `pkill -INT`
- [ ] **2.13** `Screenshot` — region/full/window capture via `grim`, `copyLast()`, `status()` returns last saved path
- [ ] **2.14** `SystemStats` — PH.13 one sampler: FAST 2s (cpu/mem/net/load/uptime via FileView), SLOW 5s (disk/hwmon-temps/nvidia-smi/battery via Process), `fmtRate()`/`fmtBytes()`/`fmtTemp()` formatters, `warnRaised`/`critRaised` signals once per crossing
- [ ] **2.15** `TemplateCatalog` — 70+ template entries with `byId()`, `labelOf()`, catalog JSON, input/output paths, post-hooks
- [ ] **2.15** `Wallpaper` — matugen 4.x pipeline with `--source-color-index 0`, template enable/disable with managed `# >>> yutashell-matugen` blocks, `_snipToml()` TOML import-array surgery, `_toml()` multi-line literal strings, `writeGenConfig()` coalescing with 100ms flush

**Cool bits from references**:
- DankMaterialShell: 20+ `dms ipc` commands, full IPC router with 15+ server submodules, D-Bus integration (bluez, networkmanager, login1, accounts, portals), wayland protocols (gamma control, screencopy, layer-shell, output management, dwl-ipc)
- Ryoku: Single `ShellRoot` instance with per-monitor `ShellState` slices, `UseQApplication` pragma for tray
- caelestia-shell: `ServiceLoader` / `GSFLoader` patterns, `Caelestia.Config` integration, `Time` service, `VPN` service

**Verification**: All services report correct `available` status; `Health.count` reflects any reported issues; system stats update at correct intervals.

---

## PHASE 3: Module Suite — All UI Components

**Objective**: Include every UI module from all three references, each lazily loaded via `Loader` in the settings panel.

- [ ] **3.1** `TopBar` / `Bar` — Data-driven v2 with `ShellState.barSegments` (17 segments across left/center/right zones), `BarSegments.setEnabled()`, `BarSegments.setZone()`, `BarSegments.setClick()`, `BarSegments.move()`, `BarSegments.scale()`, `BarSegments.position()`. `IdentityBlock`, `Workspaces`, `Taskbar`, `TrayCluster`, `MediaBlock`, `NetBlock`, `BtBlock`, `AudioBlock`, `StatsCluster`, `ClockBlock`
- [ ] **3.2** `ControlCenter` — 11 lazy tabs (`home`, `media`, `audio`, `monitors`, `system`, `power`, `network`, `bluetooth`, `weather`, `calendar`, `notifications`) behind `switch (activePageId)`, `ccAnchor`/`ccTabs` persistence, MPRIS player resolution, per-tab `Timer` gating on `activePageId === "x" && ShellState.ccOpen`
- [ ] **3.3** `SettingsPanel` — 14-tab nav rail (`appearance`, `dock`, `panels`, `launcher`, `controlcenter`, `notifications`, `osd`, `bar`, `shell`, `security`, `system`, `services`, `power`, `about`) with global search (`searchQuery` filters rail by label/jp/keywords), two-level nav (groups + pages), content area shifted right of rail by `railW`, `matchesQuery(p)` filtering
- [ ] **3.4** `WallpaperPicker` — ARCHIVE UI: numbered index spine + large preview stage, filter field drives navigation, `sourceSize` on thumbnails (256×160), `source` gated on visibility, `Wallpaper.apply()` pipeline, template enable/disable with managed `# >>> yutashell-matugen` blocks, `_snipToml()` TOML import-array surgery, `--source-color-index 0` for matugen 4.x non-interactive mode
- [ ] **3.5** `AppLauncher` — fuzzy subsequence ranking (`score()`/`entryScore()` in `fuzzy.js`), grid/list modes, pins + recents weighting, `:command` mode (`:scheme`, `:wall`, `:dark`, `:accent`, `:panel`, `:picker`), calculator row with charset whitelist (no `eval`), `wl-copy` on copy, `execute()` via `DesktopEntries`
- [ ] **3.6** `Dock` — per-screen instances (DockBar), `Dock.toggleEnabled()`, `Dock.pin()`, `Dock.unpin()`, `Dock.isPinned()`, `Dock.activeAppId()`, `Dock.windowsOf()`, `Dock.entryFor()`, `Dock.apps` model (pinned then running), `Dock.click()`, `Dock.launch()`, `Dock.newInstance()`, `Dock.cycle()`, `Dock.closeAll()`, `Dock.focusNextWindow()`, `Component.onCompleted` calls `Hyprland.refreshToplevels()` / `Hyprland.refreshWorkspaces()`
- [ ] **3.7** `OverviewGrid` — fullscreen workspace map with one tile per workspace: number, windows on it, click to jump, `Overview.toggleGrid()`, `Overview.openGrid()`, `Overview.closeGrid()`, `Overview.cycleAltTab()`, `Overview.scratchpad()`, `Overview.scratchsend()`, `Overview.tile()`, `Overview.alttab()`
- [ ] **3.8** `AltTab` — window switching cycle
- [ ] **3.9** `Notifications` — `Notify` singleton with `announce()`, `clearAll()`, `clearHistory()`, `setTimeoutSec()`, `setMaxVisible()`, `setCorner()`, `setFields()`, `setOverrideMode()`, `addOverride()`, `removeOverride()`, `replay()`, `overrides` list, `live` list, `history` list, `dead` tracking, `tracked` property, `closed` signal, `n.closed.connect()` pattern, actions as plain JS array `n.actions[i]`
- [ ] **3.10** `NetworkPanel` — WiFi list + join dialog, wired status, VPN toggle, DNS view + quick-set, airplane master switch, `Connectivity` model, 5s refresh while open, `nmcli` snapshots, `Notify.setCorner()`, `Notify.setTimeoutSec()`
- [ ] **3.11** `Picker` / `WallpaperPicker` — as detailed in Phase 2
- [ ] **3.12** `Dock` — as detailed in Phase 3.6
- [ ] **3.13** `Calendar` — month grid with today boxed in acid, nav arrows, JP weekday glyphs when CJK font present, `ShellState.calendarOpen`
- [ ] **3.14** `ShotFlash` — 1px acid border pulse on overlay layer when screenshot lands, click-through mask, `Screenshot.onFlashed()` connection
- [ ] **3.15** `Emoji` — JP-first categories (faces, kaomoji, symbols, hearts), click copies to selection via `wl-keyboard`/`wl-copy`, dismisses with toast, `root.copy(s)`, `ShellState.closeEmoji()`
- [ ] **3.16** `ColorPicker` — as detailed in Phase 2.11
- [ ] **3.17** `Recording` — as detailed in Phase 2.12
- [ ] **3.18** `Updates` — as detailed in Phase 2.10
- [ ] **3.19** `Weather` — as detailed in Phase 2.3
- [ ] **3.20** `ClipboardPanel` / `Clipboard` — cliphist 0.7 `list` output handling (id<TAB>preview, binary entries with raw bytes), `cliphist decode <id> | wl-copy`, `cliphist delete <id>`
- [ ] **3.21** `WeatherPanel` — weather widget display
- [ ] **3.22** `Osd` — OSD window for volume/brightness/mic notifications
- [ ] **3.23** `MediaWidget` — MPRIS integration via `Quickshell.Services.Mpris`, `Mpris.players.values`, `play/pause/next/previous`, `trackArtist`/`trackTitle`, `canTogglePlaying`/`togglePlaying()`, `canGoNext/Previous`/`next()`/`previous()`, `volume`+`volumeSupported`

**Cool bits from references**:
- DankMaterialShell: `DankBar` with per-segment click actions, `DankDash`, `DankIsland`, built-in plugin system, `BuiltinDesktopPlugins`, `BuiltinPlugins`
- Ryoku: `barkit` pattern for per-monitor ShellState, `components` system, `modules` system, `services` system, `shell.qml` minimal orchestration
- caelestia-shell: `dashboard` module, `nexus` module, `drawers` system, `sidebar` system, `areapicker`, `BatteryMonitor.qml`, `ServiceLoader.qml`, `GSFLoader.qml`, `ConfigToasts.qml`, full settings tab system (100+ tabs from `AboutTab` to `WorkspaceAppearanceColorOptions`)

**Verification**: All 23+ modules load lazily without errors; bar segments persist in state.json; control center tabs save/load correctly; settings panel search filters work.

---

## PHASE 4: Widget Kit — Reusable UI Components

**Objective**: Use the shared kit (`modules/common/ui/`) for all buttons, rows, switches, sections, chips, scroll areas — never hand-roll these.

- [ ] **4.1** `YButton` — tone system (`"acid"`/`"default"`/`"danger"`), hover fill wipe, interrogation tick, `onClicked` handler pattern
- [ ] **4.2** `YRow` — title + sub + trailing slot, `trailingW` consumer-set width (NEVER from childrenRect), `on_` property, `interactive` property, `hovered` signal, `toggled()` signal, MouseArea covering up to `trailingHost.left`
- [ ] **4.3** `YSwitch` — checked/unchecked with tone, `onToggled` handler
- [ ] **4.4** `YSection` — header with label, chip, index
- [ ] **4.5** `YChip` — small tagged chip with `tone` property
- [ ] **4.6** `YField` — text input with `placeholder`, `onAccepted`, `onTextChanged`
- [ ] **4.7** `YScroll` — Flickable sibling over content (NOT child), `target` property, `FastWheel` child
- [ ] **4.8** `YClickAway` — fullscreen transparent `MouseArea` emitting `outsideClicked`, pattern: declare first child of content root, card (YSurface) after it
- [ ] **4.9** `YPulse` — opacity breathing (lo 0.62, drift 2600ms), for idle chrome pulses
- [ ] **4.9** `YSpark` — small animated sparkle/decoration widget
- [ ] **4.10** `YSurface` — the standard popup card with entrance ritual (drop from behind bar, acid scanline, border burn/cool, power line, family tick), exit ceremony (reverse scanline + lift), `cascade` staggered reveal, `onOpenChanged` driver, `FlareShape` concave shoulders, `powerLine` 2px acid bottom edge, `scanline`/`familyTick` animations
- [ ] **4.11** `FastWheel` — clamped step 132, standard wheel handler for every Flickable/GridView/ListView
- [ ] **4.12** `YPulse` — idle life pulses (opacity-only, never pulse text), lo 0.62, movDrift 2600ms
- [ ] **4.12** `YSpark` — decorative animation widget

**Cool bits from references**:
- DankMaterialShell: `DankIcon`, `DankSlider`, `DankToggle`, `DankTabBar`, `DankGridView`, `DankListView`, `DankTextField`, `DankDropdown`, `CachingImage`, `StateLayer` (Material Design 3 interaction states), `StyledRect`/`StyledText` themed base components
- Ryoku: `barkit` pattern, `components` system, widgets through `DankCommon` submodule
- caelestia-shell: `DankCommon` submodule integration, `StateLayer`, `StyledRect`/`StyledText`

**Verification**: All panels use kit components (YButton/YRow/YSwitch/YSection/YChip/YField/YScroll); no hand-rolled buttons/rows/switches/sections; consistent theming via `Theme.*` tokens; no binding loops from `childrenRect` usage.

---

## PHASE 5: Plugin System — Dynamic Extensions

**Objective**: Implement a plugin system where external QML components can be loaded at runtime, with isolated settings.

- [ ] **5.1** `PluginService` — discovers, loads, and manages plugin lifecycle from `$CONFIGPATH/DankMaterialShell/plugins/` (or yuta-qs equivalent)
- [ ] **5.2** Plugin manifest (`plugin.json`) — `id`, `name`, `description`, `version`, `author`, `icon`, `type` (`"widget"` or `"daemon"`), `component`, `settings`, `permissions`
- [ ] **5.3** Widget plugins — render UI components in the bar/dock/settings, `pluginService.loadPluginData(pluginId, key, default)` / `pluginService.savePluginData(pluginId, key, value)`
- [ ] **5.4** Daemon plugins — run invisibly in background, monitor system events, `pluginService.savePluginData()` for persistence
- [ ] **5.5** Plugin scanner — Settings → Plugins → "Scan for Plugins" toggle
- [ ] **5.6** Plugin isolation — settings stored in `settings.json` under `pluginSettings.{pluginId}`, namespaced from core DMS settings
- [ ] **5.7** Example plugin — `PLUGINS/WallpaperWatcherDaemon/` as reference: daemon that monitors wallpaper changes

**Cool bits from references**:
- DankMaterialShell: Full plugin system with `PLUGINS/` directory, `BuiltinDesktopPlugins`, `BuiltinPlugins`, widget + daemon types, `plugin.json` manifest, `pluginService` injected property, settings persistence
- Ryoku: Plugin discovery system, per-monitor plugin instances

**Verification**: Plugins appear in Settings → Plugins after scan; widget plugins render in bar; daemon plugins run in background; settings persist across restarts.

---

## PHASE 6: Multi-Monitor & Surface Architecture

**Objective**: Full per-monitor support with proper layer management and surface choreography.

- [ ] **6.1** `Variants` per screen — `Quickshell.screens` model drives `Bar` and `DockBar` instances, each with `modelData` (screen info)
- [ ] **6.2** Bar layer — `WlrLayershell.layer: WlrLayer.Overlay` (topmost), popups on `WlrLayer.Top`, anything sliding down emerges from behind the bar
- [ ] **6.3** YSurface entrance ritual — drop from behind bar with OutBack overshoot, acid scanline sweep, border burn acid→cool to hairline, power line left→right, family tick down left edge, ~400ms
- [ ] **6.4** YSurface exit ceremony — reverse scanline up as card lifts, outro scanline + opacity fade, ~190ms hideDelay
- [ ] **6.5** Content cascade — `cascade: <content Item>` on YSurface; direct children stagger-rise (26ms apart, opacity + Translate y14→0) after 140ms revealDelay; `kidAnim.createObject()` + `SequentialAnimation` with `PauseAnimation`; `onStopped` cleans up transforms
- [ ] **6.6** YClickAway pattern — fullscreen transparent `MouseArea` as FIRST child of content root; `onOutsideClicked: <close>`; card (YSurface) AFTER it; keeps in-card clicks from reaching catcher
- [ ] **6.7** No scrims by default — popups fullscreen transparent, input confined to card via `mask: Region { item: open ? clickAway : null }`
- [ ] **6.8** Dolphin/standard surface — every floating surface composes YSurface instead of re-animating by hand
- [ ] **6.9** FastWheel on all Flickables/GridViews/ListViews — drop-in child with `notchStep 132`, clamped
- [ ] **6.10** Bar v2 data-driven — `ShellState.barSegments` ordered `[{id,zone,enabled}]` array; `BarSegments.present(id)` runtime visibility; 17 segments across 3 zones; `BarActions.dispatch(action)` for click-actions

**Cool bits from references**:
- DankMaterialShell: Multi-compositor support (6), per-output workspaces, `wlr-layer-shell` layers (Overlay/Top), `Variants` per-screen, `DankBar` with zone system
- Ryoku: `barkit` per-monitor ShellState slices, each monitor gets one `Scope` carrying its slice
- caelestia-shell: Per-monitor configurations, `dashboard` with monitor-aware settings

**Verification**: On multi-monitor setup, each screen has its own bar/dock; workspace switching works per-monitor; popups from one monitor don't affect another; RSS stays in range.

---

## PHASE 7: Compositor Integration

**Objective**: Integrate with all major Wayland compositors via native protocols.

- [ ] **7.1** `Hyprland` — `hl.dsp.focus({window = "address:..."})`, `hl.dsp.workspace.toggle_special("magic")`, `hl.dsp.window.move({workspace = N})`, `hl.dsp.focus({workspace = "N"})`, `hl.config({general.col.active_border = "..."})`, `hl.refreshToplevels()`, `hl.refreshWorkspaces()`, `Hyprland.toplevels.values`, `Hyprland.activeToplevel` (never populates — track via raw events)
- [ ] **7.2** `Niri` — `wlr-gamma-control-unstable-v1` night mode, `wlr-screencopy-unstable-v1` screenshots + color picker, `wlr-layer-shell` integration
- [ ] **7.3** `MangoWC` / `dwl` — `dwl-ipc-unstable-v2` tag management, IPC messages
- [ ] **7.4** `Sway` / `labwc` / `i3` — standard i3 IPC integration, `executable` `$mod+c` style keybinds
- [ ] **7.5** `Scroll` — fractional scaling via `wp-viewporter`, output configuration
- [ ] **7.6** Wayland protocols client implementations:
  - `wlr-gamma-control-unstable-v1` — night mode color temperature
  - `wlr-screencopy-unstable-v1` — screenshots and color picker
  - `wlr-layer-shell-unstable-v1` — overlay surfaces
  - `wlr-output-management-unstable-v1` — display configuration
  - `wlr-output-power-management-unstable-v1` — DPMS control
  - `ext-data-control-v1` — clipboard history
  - `ext-workspace-v1` — workspace integration
  - `keyboard-shortcuts-inhibit-unstable-v1` — shortcut inhibition
- [ ] **7.7** D-Bus integration:
  - `org.bluez` — Bluetooth with pairing agent
  - `org.freedesktop.NetworkManager` — Network management
  - `net.connman.iwd` — iwd Wi-Fi backend
  - `org.freedesktop.login1` — Session control, inhibitors, brightness
  - `org.freedesktop.Accounts` — User account info
  - `org.freedesktop.portal.Desktop` — Desktop appearance settings
  - CUPS via IPP — Printer management
  - `org.freedesktop.ScreenSaver` — Screensaver inhibition for media playback

**Cool bits from references**:
- DankMaterialShell: 6 compositor support, native protocol clients, D-Bus server + client, `dms features` command, `WAYLAND_DEBUG` support
- Ryoku: Single instance model, `UseQApplication` for tray, per-monitor `Scope`
- caelestia-shell: `Caelestia` import, `Hypr` service, `GameMode` service, `Nmcli` service, `VPN` service

**Verification**: Keybinds work on target compositor; protocols initialize correctly; D-Bus services available; night mode works when supported; screenshots capture correctly.

---

## PHASE 8: Nix & Distribution Support

**Objective**: Support installation across multiple Linux distributions with automatic dependency detection.

- [ ] **8.1** `flake.nix` — Nix module for yuta shell configuration, declarative shell setup
- [ ] **8.2** ` .envrc` — environment setup with `export QS_CONFIG_DIR=...`, `export EDITOR=...`, key vars
- [ ] **8.3** ` .clang-format` — code style configuration for any C/C++ components
- [ ] **8.4** Distribution installers — pattern from DankMaterialShell's `make dankinstall`:
  - **Arch Linux** — AUR package with `pmbuild/` or `git2aur/`
  - **Fedora** — DNF + COPR repo
  - **Debian** — apt + OBS repos
  - **Ubuntu** — apt + PPAs
  - **openSUSE** — zypper + OBS
  - **Gentoo** — emerge + GURU overlay + USE flags
- [ ] **8.5** `make dankinstall` — TUI installer with full distro support, dependency detection, automatic tool install (yay/paru for Arch, dnf plugin for Fedora, apt packages for Debian/Ubuntu, etc.)
- [ ] **8.6** `make dist` — Distribution binaries build (no update/greeter features)
- [ ] **8.7** `make test` — Run unit tests for Go backend, integration tests for QML
- [ ] **8.8** `make lint-qml` — QML formatting and linting (after `qs -p .` generates `.qmlls.ini`)
- [ ] **8.8** `qmlfmt -t 4 -i 4 -b 250 -w` — Format all QML files (4-space indent, max 250 char lines)

**Cool bits from references**:
- DankMaterialShell: Full `make dankinstall` TUI, 6 distro support, `make dist`, `make test`, `golangci-lint run`, AUR packages, COPR repos, apt/OBS repos
- caelestia-shell: `flake.nix`, ` .envrc`, ` .clang-format`, GitHub Actions CI, AUR package (`caelestia-shell`)

**Verification**: `make install` works on target distro; `nix run github:...` works; all dependency detections are correct; `make test` passes; `make lint-qml` passes.

---

## PHASE 9: Advanced Features & Wallpaper Pipeline

**Objective**: Full-featured wallpaper management, template system, and advanced customization.

- [ ] **9.1** matugen 4.x integration with `--source-color-index 0` for non-interactive use
- [ ] **9.2** TOML config generation — `_toml()` multi-line literals (`'''…'''`), no escape processing; `_snipToml()` import-array surgery (merge into existing `import = [...]`, add after `[general]`, or append managed `[general]` block)
- [ ] **9.3** Template registry — `TemplateCatalog` with 70+ entries, `byId()`, `labelOf()`, enabled/disabled state in `ShellState.tplEnabled`, custom templates via `ShellState.customTpl`, `Wallpaper.addTemplate()`, `Wallpaper.removeTemplate()`, `Wallpaper.setTemplateEnabled()`
- [ ] **9.4** Managed `# >>> yutashell-matugen` / `# <<< yutashell-matugen` blocks in app configs (alacritty, kitty, ghostty, mako, swaync, hyprland, hyprlock, waybar, gtk3, gtk4, wlogout) with `mode: "toml-import"` / `mode: "block"` semantics
- [ ] **9.5** Wallpaper template apply pipeline: `awww-daemon` spawn + retry (8× with 0.25s gaps), `matugen -c genConfigPath image <path> -m dark --source-color-index 0`, `paintTimer` retry loop, `genConfigFile` writes `matugen.toml`, post-hooks applied
- [ ] **9.6** Follow wallpaper — when enabled, wallpaper palette applied and dynamically re-applied on changes via `wallThemeFile.onLoaded` / `wallThemeFile.reload()` (not synchronous)
- [ ] **9.7** Light mode generation — `_toLight()` HSL-remaps any token map to paper/ink; `_fitOnLight()` darkens acid/alert against live bg until contrast thresholds passed (3.0/2.5); contrast self-check asserts zero warnings across full preset cycles in light mode
- [ ] **9.8** Accent override — any color can take the "acid" slot via `Theme.setAccent(color)`; `ShellState.accentOverride` persisted; `_applyAccentOverride()` re-runs current source through engine
- [ ] **9.9** Scheme engine — 12 preset schemes (acid, crimson, cyan, amber, catppuccin, cyberpunk, doom, gruvbox, mono, tokyonight, kanagawa, dracula); `Theme.setDark(true/false/toggle)`; `Theme.setFollowWallpaper(true/false)`; `Theme.applyPreset(id)`; `Theme.previewOf(id)` for swatch previews; `checkContrast()` asserts 3.0/2.5 ratios
- [ ] **9.10** Japanese labels gated behind `Theme.jpEnabled` (checks `Qt.fontFamilies()` for CJK); romaji fallbacks everywhere; `fsMicro` for decorative chrome only

**Cool bits from references**:
- DankMaterialShell: matugen integration, template system, theme mode switching, contrast checking, `Theme` singleton with all 11 tokens, light mode generation
- Ryoku: Wallpaper picker with archive UI, index spine + large stage, no full-res decode (sourceSize gated on visibility)
- caelestia-shell: Weather service, `ConfigToasts`, `Time` service, `VPN` service, advanced settings system

**Verification**: Wallpaper changes apply without OOM (thumbnail size limited to 256×160); template enabling/disabling works without config errors; light mode generates without contrast warnings; accent override persists across restarts.

---

## PHASE 10: Polish, QA & Edge Cases

**Objective**: Final testing, edge case handling, and perfection polishing.

- [ ] **10.1** OOM prevention — verify no full-res image decoding: all thumbnail `Image` objects have `sourceSize` set (256×160); `source` gated on `root.visible`; `Repeater` in singletons only renders when `visible`; `Loader` per tab keeps heavy lists from building at startup
- [ ] **10.2** Race condition fixes — `Wallpaper.apply()` not synchronously after `FileView.reload()` (relies on `onLoaded` handler); `DisplayService.setBright()` not called synchronously on hover; `Notify` not touched after `n.closed.connect()` — check `dead` before closing
- [ ] **10.3** QML error handling — `console.warn` during boot-phase diagnostics (not `console.log`); `Component.onCompleted` errors are edit-order artifacts against live instance, not code bugs; verify against freshly spawned instance
- [ ] **10.4** PID tracking — never `pkill -f "quickshell -p <path>"` (matches user's live instance); record test instance PID at spawn (`$!` from `setsid`) and kill exact PID only
- [ ] **10.5** Config persistence — `ShellState.set()` → `state.json`; `ShellState.flushNow()` for session-ending paths; state seeds only when file absent/empty (transient read race never clobbers user prefs)
- [ ] **10.5** Linting & formatting — run `make lint-qml` after `qs -p .`; run `qmlfmt -t 4 -i 4 -b 250 -w **/*.qml`; run `gofmt -w .`; run `go mod tidy`; run `golangci-lint run`
- [ ] **10.6** Background quickshell between bash calls — `setsid nohup ... < /dev/null & disown` pattern; plain nohup gets reaped when tool session ends
- [ ] **10.7** Console logging — `qs -p <path> log > file &` to capture stderr; `console.log` from QML does NOT reliably reach nohup-captured stderr; use `warn` for boot-phase diagnostics
- [ ] **10.8** IPC targeting — `qs ipc call ...` without `--pid`/`--id` targets exactly ONE instance (first found, usually live shell); to drive specific instance: `qs ipc --pid <pid> call <target> <fn>`; or `-i <id-substring>`; bare `-p` targets live session — note prefs from logs first and restore after, or target test PID directly
- [ ] **10.9** Failed-config instances — editing QML while instance runs triggers hot-reload mid-edit-sequence: saving caller before callee produces transient `ReferenceError`s; don't chase in log captures; verify against freshly spawned instance instead
- [ ] **10.10** Final RSS check — `ps -o rss -p $(pgrep -f 'qs -c')` should be 250-500 MB; tail clean-load log: `tail -n 30 /run/user/1000/quickshell/by-pid/$(pgrep -f 'qs -c')/log.log`; `qs ipc -c yuta-qs call panel toggle` exercises panel via IPC

**Cool bits from references**:
- DankMaterialShell: Lessons documented in AGENTS.md (OOM incident, daemon race, QML gotchas, test harness, never `pkill -f quickshell`, hot-reload artifacts, `pgrep -n` pitfalls, `UseQApplication` only fresh start, singleton lazy instantiation, `trimStart`/`trimEnd` missing, `Property value set multiple times` kills config, `Process.command` does NOT start it, `StdioWriter` does not exist, duplicate property assignment exits instantly, `pgrep -n` returns live shell, hot-reload mid-edit, `Qt.callLater` pre-compositor-configure, `QtObject` root has no default property, `qmldir` must declare singleton, no `Quickshell.primaryScreen`, `anchors.fill` inside Row warns, underscore property handlers `on_DispListChanged`, `Keys.on*Pressed` must declare `event`, never call `applyWallpaperTokens()` sync after `FileView.reload()`, matugen 4.x TTY requirement, TOML literal strings `'…'` no `''` escaping, post-hooks with embedded quotes, `Notification.actions` plain JS array, C++ side enforce expireTimeout, hot-reload zombie bus registration, directory qmldir strict imports, state.json not watched for external edits, toast cards stable across 100ms countdown, warm lazy singletons at boot, `shell.qml` needs `import QtQuick`, `IconImage` needs `implicitSize`, anchored loaders stretch to Loader size, flickable/gridview/listview reparent, `Flickable.contentHeight` binding loop, `IconImage.source` real URLs, `Quickshell.iconPath(name)`, binding `contentHeight` to `loader.item.height` latches dying item, row-level MouseArea eats trailing clicks, anchored loaders stretch geometry, `Qt.callLater` pre-compositor-configure, `QtObject` root no default property, `qmldir` must declare singleton, no `Quickshell.primaryScreen`, `anchors.fill/left/right` inside Row warns, auto-changed underscore properties `on_DispListChanged`, `Keys.on*Pressed` must declare `event`, never call `applyWallpaperTokens()` sync after `FileView.reload()`, `Process` works with `import Quickshell.Io`, `WlSessionLockSurface.screen` null until compositor assigns, `Keys.on*Pressed` must declare `event`, never call `applyWallpaperTokens()` sync after `FileView.reload()`, matugen 4.x TTY requirement, TOML literal strings no `''` escaping, post-hooks with embedded quotes, `Notification.actions` plain JS array, C++ side enforce expireTimeout, zombie bus registration, directory qmldir strict, state.json not watched, toast cards stable, warm singletons at boot, `shell.qml` needs `import QtQuick`, `IconImage` needs `implicitSize`, anchored loaders stretch, flickable/gridview/listview reparent, `Flickable.contentHeight` binding loop, `IconImage.source` real URLs, `Quickshell.iconPath(name)`, binding `contentHeight` latches dying item, row MouseArea eats clicks, anchored loaders stretch geometry, `Qt.callLater` pre-compositor-configure, `QtObject` root no default property, `qmldir` must declare singleton, no `primaryScreen`, `anchors.fill/left/right` inside Row warns, underscore property handlers, `Keys.on*Pressed` must declare `event`)
- Ryoku: `DankCommon` submodule for shared widgets, `barkit` per-monitor, `qmlformat-all.sh`, `make lint-qml`
- caelestia-shell: GitHub Actions CI, AUR packages, `make test`, `make lint-qml`, `flake.nix`

**Verification**: RSS 250-500 MB; clean-load log signal; IPC panel toggle works; all 10 phases checked off; no log warnings on fresh start; all edge cases handled gracefully.

---

## QUICK REFERENCE: Key Patterns Across All Three References

### Singleton Pattern (all three)
```qml
Singleton {
    id: root
    property type value: defaultValue
    function performAction() { /* ... */ }
}
```

### YSurface Entrance/Ritual (DankMaterialShell + yuta)
```qml
// onOpenChanged drives the whole ceremony
onOpenChanged: {
    if (open) {
        _landed = false;
        familyTick.height = 0;
        powerLine.width = 0;
        scanline.y = -2;
        scanline.opacity = 0.85;
        landTimer.restart();
        intro.restart();
        powerLine.width = root.width;
        revealDelay.restart();
    } else {
        intro.stop();
        landTimer.stop();
        _landed = false;
        outro.restart();
        familyTick.height = 0;
        powerLine.width = 0;
    }
}
```

### YClickAway Pattern (all three)
```qml
YClickAway {
    id: clickAway
    onOutsideClicked: ShellState.closePanel()
}
// Must be FIRST child of content root; card (YSurface) AFTER it
```

### IPC Pattern (DankMaterialShell)
```qml
// QML service sends JSON-RPC to Go backend
ipcClient.send("some.method", {param: value})
// Go backend handles, responds
// QML service property updates → reactive UI
```

### Theme Pattern (DankMaterialShell + yuta)
```qml
// All tokens from Theme singleton, never hardcoded
color: Theme.acid
font.pixelSize: Theme.fsBody
// Light mode generated at runtime
property bool dark: true
Theme.setDark(false)
// Contrast self-check
checkContrast() // asserts 3.0 (ink/bg), 3.0 (acid/bg), 2.5 (alert/bg)
```

### Plugin Pattern (DankMaterialShell)
```qml
// plugin.json manifest
{
    "id": "myPlugin",
    "type": "widget",
    "component": "./MyWidget.qml",
    "settings": "./MySettings.qml"
}
// In QML: pluginService.loadPluginData("myPlugin", "key", default)
```

---

## SUCCESS METRICS

When all 10 phases are complete, the yuta shell should:

1. **Start clean** — `qs -p .` produces zero warnings in authoritative log
2. **RSS in range** — `ps -o rss -p $(pgrep -f 'qs -c')` shows 250-500 MB
3. **All features available** — every module, service, and widget from all three references works
4. **Multi-monitor works** — each screen independent, no cross-contamination
5. **Theme consistent** — `Theme.*` tokens used everywhere, no hardcoded colors
6. **Live recoloring free** — `Theme._toLight()` auto-generates light mode; accent overrides persist
7. **No OOM** — thumbnail decoding limited, off-screen gated, delegate recycling working
8. **Graceful degradation** — every service reports `available: false` when binary absent; UI hides gracefully
9. **Plugin system operational** — widgets and daemons load from plugin directory
10. **Full IPC surface** — `qs ipc --pid <pid> call <target> <fn>` works for all targets

---

*Roadmap maintained in `/home/braxton/.config/quickshell/yuta-qs/ROADMAP.md`. Track progress by checking off phases and verifying against the live shell log after each phase completion.*