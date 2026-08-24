# Yuta Shell Roadmap v2.0 — "Operation Perfection"

**Goal**: Integrate every feature from DankMaterialShell, Ryoku, and caelestia-shell into the yuta shell, producing a feature-complete, production-ready configuration with zero dependencies on other configs.

This roadmap covers 10 phases, from foundation to polish. Each phase builds on the previous one. Track progress by checking off items and verifying against the live shell log.

---

## PHASE 1: Foundation & Module Infrastructure — ✅ COMPLETE

**Objective**: Establish the core architecture that all other phases depend on.

- [x] **1.1** All 13 modules have `qmldir` files; cross-check script confirms every top-level `.qml` is declared. Fixed: added `TemplatesPage` to `modules/settings/qmldir` (referenced at SettingsPanel.qml:1087/1101 but missing from the strict import list — would have broken the templates tab).
- [x] **1.2** Audited all 23 `pragma Singleton` files: every one has `id: root`, proper imports, and a matching `singleton X 1.0 X.qml` qmldir entry. Reverse check (qmldir singleton entries → pragma present) caught and fixed `Emoji`: it is a PanelWindow, not a singleton — declaration reverted to plain type.
- [x] **1.3** Startup probes verified on DisplayService, NightLight, Weather, ColorPicker, Updates, Recording (all fire `binProbe` in `Component.onCompleted`). Screenshot intentionally hardcodes `available: true` with documented rationale (grim/slurp are core deps). AudioService root hardened `QtObject` → `Singleton` per AGENTS.md convention (it carries a child object via property; bare children would have failed cryptically).
- [x] **1.4** `ShellState.set()` coalescing verified: 80 ms flush Timer + `flushNow()` for session-ending paths. Fresh-instance log shows zero dropped-operation warnings.
- [x] **1.5** Boot warm-up Timer extended: was covering only Updates/Recording/ColorPicker/Weather/Clipboard/SystemStats — now also touches `DisplayService.available`, `NightLight.available`, `Session.ppdAvailable` (all three are referenced ONLY inside IpcHandler functions and probe async; first IPC call previously raced the probe).
- [x] **1.6** UseQApplication fresh-start caveat already documented in AGENTS.md lesson 15 ("the pragma only takes effect on a fresh start"). Verified pragma present in shell.qml line 3.
- [x] **1.7** Full qmldir correctness sweep: files↔declarations both directions across all modules — PASS after the two fixes above.

**Cool bits from references**:
- DankMaterialShell: `Variants` per-screen bar/dock instances via `Quickshell.screens`
- Ryoku: `ShellRoot` with per-monitor `ShellState` slices via `barkit` pattern
- caelestia-shell: Modular `ShellRoot` with `GSFLoader` / `ServiceLoader` singletons

**Verification (2026-08-24, fresh instance pid 30904)**: "Configuration Loaded" with zero QML errors; IPC first-calls return live state (no probe race); RSS 399 MB. Known-honest warnings only: absent binaries degrade gracefully (`cliphist`/`ddcutil`/`hyprsunset`/`hyprpicker`/`nvidia-smi` no longer installed on this machine — UI reports "unavailable (install …)" as designed); org.freedesktop.Notifications + polkit agent owned by other daemons on this session; one benign empty tray-icon lookup at boot.

---

## PHASE 2: Service Layer — IPC & System Integration — ✅ COMPLETE

**Objective**: Every system service audited against its contract, bugs fixed, verified live over IPC.

- [x] **2.1** `AudioService` — `stepPct()` / `toggleMute()` / `nodePct()` / `nodeFrac()` verified in code and live (`audio status` → `ALC257 Analog · 40%`); cubic taper math correct.
- [x] **2.2** `DisplayService` — probe/Health/`_dispList`/`on_DispListChanged` all present. **Fixed multi-display bug**: `setBright` reused one Process per-display in a loop — every display after the first was dropped (running edge fires once); now one chained shell op across all displays. ddcutil absent on this machine → degrades honestly.
- [x] **2.3** `NightLight` — available/active/temp + Health.report verified. **Fixed restart race**: `restartProc()` terminated then immediately forced `running = true`, but `running` stays true until the old process exits → relaunch silently no-oped when changing temperature mid-session; now relaunches from `onExited`. Absent hyprsunset reports honestly via IPC.
- [x] **2.4** `Weather` — open-meteo/curl, 30-min poll, weather.json cache seeding at boot, `configured`/`available`/`fetching`, `codeInfo()` all verified (`weather status` → honest `no location set`).
- [x] **2.5** `Updates` — checkupdates, 6h re-check, openTerminal verified. **Improved**: announcements are now change-driven (`_announcedCount`) so a static list no longer toasts on every 6h re-check.
- [x] **2.6** `Bluetooth` — adapter/devices/pair/connect/disconnect/forget surface verified in Connectivity + BluetoothPanel consumers.
- [x] **2.7** `Connectivity` — wifi/wired/strength/activeWifi/wiredSpeed/airplane verified. **Fixed stale snapshots**: nothing refreshed vpnList/activeCon/dns at boot (empty until a link flap or panel open) — added boot-time `refresh()`. **Fixed NetworkPanel timer binding-break**: `Component.onCompleted: refreshTimer.start()` imperatively overrode `running: ShellState.netOpen`, polling nmcli every 5 s forever even closed; removed (binding + `triggeredOnStart` cover it).
- [x] **2.8** `Session` — power menu tiles, PowerProfiles busctl probe, idle monitor with `respectInhibitors`, 20 s logind inhibitor poll all verified live (`session status` → `unlocked · inhibitors 0 · profile balanced · idle none/900s`).
- [x] **2.9** Pipewire — writable default sink/source, tracked nodes, streams-vs-devices split, `fracToVol`/`volToFrac` verified in AudioService.
- [x] **2.10** `Clipboard` — cliphist `id<TAB>preview` parsing, control-char binary detection, decode|wl-copy, delete+wipe-with-refresh verified.
- [x] **2.11** `ColorPicker` — Health.report on absent hyprpicker, toast degradation, lastColor capture verified.
- [x] **2.12** `Recording` — binary probe, 5 s pgrep poll, `pkill -INT` stop path verified (`recording status` → `idle`).
- [x] **2.13** `Screenshot` — region/full/window paths, strftime expansion, copyLast/status verified in code (grim/slurp present on this machine).
- [x] **2.14** `SystemStats` — FAST 2 s / SLOW 5 s classes, shared formatters, once-per-crossing threshold signals verified.
- [x] **2.15** `TemplateCatalog` — `byId`/`labelOf` + registry add/remove/enable verified (`templates list` enumerates with state).
- [x] **2.16** `Wallpaper` — matugen `-m dark --source-color-index 0`, managed `# >>> yutashell-matugen` blocks, `_snipToml` import-array surgery, coalesced gen-config writes verified in code + clean binProbe log lines.

**Cool bits from references**:
- DankMaterialShell: 20+ `dms ipc` commands, full IPC router with 15+ server submodules, D-Bus integration (bluez, networkmanager, login1, accounts, portals), wayland protocols (gamma control, screencopy, layer-shell, output management, dwl-ipc)
- Ryoku: Single `ShellRoot` instance with per-monitor `ShellState` slices, `UseQApplication` pragma for tray
- caelestia-shell: `ServiceLoader` / `GSFLoader` patterns, `Caelestia.Config` integration, `Time` service, `VPN` service

**Verification (2026-08-24, fresh instance pid 34201)**: Configuration Loaded, zero QML errors; IPC first-calls return live state across audio/session/updates/recording/weather/templates/nightlight/display; RSS ~395 MB. Remaining log warnings are environmental only (polkit agent + notification daemon owned by other processes on this session).

---

## PHASE 3: Module Suite — All UI Components — ✅ COMPLETE

**Objective**: Every UI module audited against its contract, exercised live over IPC, bugs fixed.

- [x] **3.1** `Bar` — data-driven v2 verified: 17-segment persisted model, `BarSegments.present()` live conditions gate correctly (media→Mpris players, bt→adapter enabled, nightlight→active, session→inhibitCount>0, recording→active), zone Repeaters + divider-on-index>0, all 16 segment components resolve via `segComponent`, click-actions via `BarActions`.
- [x] **3.2** `ControlCenter` — all 11 tab ids present behind the lazy Loader switch; per-tab Timers gate on `activePageId === "x" && ShellState.ccOpen`; MPRIS resolved directly from `Mpris.players.values` in both MediaWidget and ControlCenter.
- [x] **3.3** `SettingsPanel` — 14-page registry with LOOK/BEHAVIOR/SYSTEM groups + `matchesQuery(p)` search filter verified (line-level).
- [x] **3.4** `WallpaperPicker` — ARCHIVE UI verified: index spine (no thumbnail decode), preview stage, filter-driven navigation, sourceSize discipline.
- [x] **3.5** `AppLauncher` — fuzzy.js subsequence scoring, grid/list modes, pins/recents, all six `:` commands (`scheme/wall/dark/accent/panel/picker`), calc row.
- [x] **3.6** `Dock` — full API surface verified (`pin/unpin/isPinned/click/launch/newInstance/cycle/closeAll/focusNextWindow/windowsOf/entryFor/activeAppId/toggleEnabled`); per-monitor DockBar instances.
- [x] **3.7** `OverviewGrid` — open/close/toggle/jump/move-to-workspace/scratchpad send+toggle/tile presets all present in the Overview singleton.
- [x] **3.8** `AltTab` — MRU ordering tracked in Overview.qml; acid selection frame; open/cycle/select/commit/cancel cycle complete.
- [x] **3.9** `Notifications` — full Notify API surface verified (announce/dnd/overrides/replay/history persistence/coalesced persist writes); ToastStack delegates directly over stable in-place Entry objects mutated field-by-field by the 100 ms tick (no delegate recreation mid-countdown).
- [x] **3.10** `NetworkPanel` — wifi list + join dialog, wired status, VPN toggles, DNS readout + override, airplane switch; nmcli refresh correctly gated to open state.
- [x] **3.11–3.21** Widget suite verified: Calendar month grid with JP weekday glyphs gated on `Theme.jpEnabled` (romaji fallback), ShotFlash on Overlay layer with fully click-through empty mask, Emoji JP-first categories (FACES/KAOMOJI/SYMBOLS/HEARTS), ClipboardPanel/WeatherPanel/Osd (VOL/MIC/BRIGHT kinds + fade timer), MediaWidget equalizer bars + transport.
- [x] **3.22** `Osd` — one instance, three kinds, `osdPing` signal path from AudioService, fade persisted knob.
- [x] **3.23** `MediaWidget` — MPRIS app glyph, track line, seekbar, play/pause/next/prev, optional-chaining guards throughout.

**Bug fixed during audit**: `BluetoothPanel.qml` device delegate read ~20 properties off `modelData` unguarded — when BlueZ churns the device list mid-scan, surviving delegates evaluated bindings against a stale undefined entry → `TypeError: Cannot read property 'icon' of undefined` (observed 3× in one panel-open). All reads now null-safe (`?.` / explicit undefined checks); action buttons self-hide when their device vanishes.

**Cool bits from references**:
- DankMaterialShell: `DankBar` with per-segment click actions, `DankDash`, `DankIsland`, built-in plugin system
- Ryoku: `barkit` pattern for per-monitor ShellState, minimal shell.qml orchestration
- caelestia-shell: `dashboard` module, `nexus`, `drawers`, `sidebar`, `areapicker`, 100+-tab settings system

**Verification (2026-08-24, fresh instances pids 36956/38367)**: 26 open/close IPC cycles across every surface (launcher/settings/picker/cc/network/bt/notifycenter/calendar/clipboard/weather/emoji/overview/session) + test toast + dnd/bar status — zero QML errors, zero TypeErrors after fix; RSS ~419 MB. Remaining warnings are documented-benign only (absent nvidia-smi, theme-icon fallback misses, environmental polkit/notification bus ownership).

---

## PHASE 4: Widget Kit — Reusable UI Components — ✅ COMPLETE

**Objective**: Use the shared kit (`modules/common/ui/`) for all buttons, rows, switches, sections, chips, scroll areas — never hand-roll these.

- [x] **4.1** `YButton` — tone system (`"acid"`/`"default"`/`"danger"`), hover fill wipe, interrogation tick (acid underline draws in), hard-shadow press collapse — verified against contract
- [x] **4.2** `YRow` — title + sub + note-swap-on-hover + trailing slot, `trailingW` consumer-set width (NEVER from childrenRect), `on_`, `interactive`, `hovered`, `toggled()` signal; row MouseArea stops at `trailingHost.left`
- [x] **4.3** `YSwitch` — checked/unchecked with acid fill-wipe, OutBack(0.45) knob snap, `toggled()` handler
- [x] **4.4** `YSection` — header with index glyph, label, flex rule (`reveal()` draws left→right via Scale.xScale for cascade), trailing chip
- [x] **4.5** `YChip` — outline/acid/alert tones, label-change micro-pop
- [x] **4.6** `YField` — placeholder, `accepted()`, focus underline + acid left bar, optional `navKeys` mode surfacing arrows/tab/esc/shift-del as signals (launcher)
- [x] **4.7** `YScroll` — Flickable SIBLING with sleeping rails (wake on scroll, settle after 700 ms). **Fixed 3 zero-sized instances** that rendered nothing: NotificationCenter, BluetoothPanel, NetworkPanel now anchor/size it like SettingsPanel/AudioPanel always did. Launcher gained a rail over its active list (target follows command/grid/list mode)
- [x] **4.8** `YClickAway` — fullscreen transparent catcher emitting `outsideClicked`; adoption audited: all 12 floating surfaces carry it as first child (Polkit/Lock modal, ToastStack/Osd/Dock passive by design)
- [x] **4.9** `YPulse` — opacity breathing lo 0.62 over movDrift, gated on `visible`
- [x] **4.10** `YSurface` — full entrance ritual (OutBack drop into bar socket, scanline sweep, border burn→cool @230 ms, power line draw, family tick), reverse exit ceremony, `cascade` stagger (26 ms, Translate-based, transforms destroyed on stop), FlareShape concave shoulders, swallow MouseArea — read end-to-end, matches spec
- [x] **4.11** `FastWheel` — notchStep 132 clamped, parent-walk survives Flickable contentItem reparenting. **Added the 4 missing instances**: AppLauncher ×3 (commandList/gridView/listView) and NotificationCenter listFlick
- [x] **4.12** `YSpark` — push-driven Canvas sparkline (repaints only on push/color/resize); `property var data` shadowing Item.data verified legal on this Qt build via isolated instance probe

**Audit method**: all 13 kit components read against contract; consumers swept for hand-rolled buttons/switches/sections (none found — grep hits were YButton internals and bespoke nav-rail/tile controls); FastWheel adoption checked per scrollable (12/12 files covered after fixes); YClickAway per floating surface (12/12).

**Verification**: fresh instance pid 43594 — clean boot RSS 380 MB → 8 open/close IPC cycles across launcher/notify/BT/network panels → 0 QML errors, RSS stable ~394 MB.

**Cool bits from references**:
- DankMaterialShell: `DankIcon`, `DankSlider`, `DankToggle`, `DankTabBar`, `DankGridView`, `DankListView`, `DankTextField`, `DankDropdown`, `CachingImage`, `StateLayer` (Material Design 3 interaction states), `StyledRect`/`StyledText` themed base components
- Ryoku: `barkit` pattern, `components` system, widgets through `DankCommon` submodule
- caelestia-shell: `DankCommon` submodule integration, `StateLayer`, `StyledRect`/`StyledText`

**Verification**: All panels use kit components (YButton/YRow/YSwitch/YSection/YChip/YField/YScroll); no hand-rolled buttons/rows/switches/sections; consistent theming via `Theme.*` tokens; no binding loops from `childrenRect` usage.

---

## PHASE 5: Plugin System — Dynamic Extensions — ✅ COMPLETE

**Objective**: Implement a plugin system where external QML components can be loaded at runtime, with isolated settings.

- [x] **5.1** `PluginService` (`modules/common/PluginService.qml`) — discovers plugins from `<configroot>/plugins/<Name>/`, manages lifecycle (scan → manifest parse → daemon instantiate/unload), config root resolved from CLI args with fallbacks; singleton registered in `modules/common/qmldir`, warmed at boot
- [x] **5.2** Manifest (`plugin.json`) — `id`, `name`, `description`, `version`, `author`, `icon`, `type` (`"widget"`|`"daemon"`), `component`, `settings[]` (key/label/type/default), `permissions[]`; bad manifests reported via `lastScanError`, never crash the shell
- [x] **5.3** Widget plugins — bar hosts them via the new `pluginwidgets` segment (`BarSegments` meta + present() case + Bar.qml Row-of-Loaders component); enabling a widget auto-flips the segment on (direct ShellState write, no singleton import cycle); example: `plugins/PulseDot/`
- [x] **5.4** Daemon plugins — instantiate invisibly when enabled (boot scan `_syncDaemons()` or on toggle), unload on disable/manifest removal, persistence through `savePluginData()`; example: `plugins/WallpaperWatcherDaemon/` counts wallpaper changes
- [x] **5.5** Settings → PLUGINS page — scan button, installed list (name/id/version/author, description-on-hover with permissions), LIVE chip for running daemons, enable switches; IPC mirror: `qs ipc call plugins {list,rescan,enable,disable}`
- [x] **5.6** Isolation — all plugin state lives under one namespaced adapter key (`ShellState.pluginData`: `{id:{enabled,data}}`); core prefs untouched. Plugin mutations flush immediately (`flushNow`) — the 80 ms coalesced window let a reload re-read stale disk and revert flags during testing
- [x] **5.7** Reference daemon shipped — `WallpaperWatcherDaemon` watches `Wallpaper.current`, persists change counter + last path, announces to stderr

**Hard-won lessons from this phase**:
- A missing `readonly property alias` on ShellState makes direct reads return `undefined` while writes still work — reads silently rebuilt maps with defaults and "reverted" persisted flags (JSON.parse(undefined) throws into the catch, yielding `{}`)
- Plugin QML files CAN import `qs.theme`/`qs.modules.common` (engine import paths are config-root-global) and relative kit imports like `../common/ui`
- Delegate redeclared YRow's own `on_` property name → duplicate-property killed the whole settings panel load (same trap as PH.15 notes; fresh name + bind)

**Verification**: fresh instances ×3 — debug-cycle walked all 15 settings pages incl. PLUGINS with 0 errors; full lifecycle over IPC: scan finds both examples, enable→daemon instantiates ("plugin daemon up"), wallpaper change → counter+path persist with enabled flag intact, widget enable → bar segment appears, disable → daemon unloads, restart → enabled state + boot-time daemon start persist; RSS ~360-425 MB throughout.

**Cool bits from references**:
- DankMaterialShell: Full plugin system with `PLUGINS/` directory, `BuiltinDesktopPlugins`, `BuiltinPlugins`, widget + daemon types, `plugin.json` manifest, `pluginService` injected property, settings persistence
- Ryoku: Plugin discovery system, per-monitor plugin instances

**Verification**: Plugins appear in Settings → Plugins after scan; widget plugins render in bar; daemon plugins run in background; settings persist across restarts.

---

## PHASE 6: Multi-Monitor & Surface Architecture — ✅ COMPLETE

**Objective**: Full per-monitor support with proper layer management and surface choreography.

- [x] **6.1** `Variants` per screen — `Quickshell.screens` drives one `Bar` and one `DockBar` instance per screen (`screen: modelData`); DockBar scopes its window list via `workspace.monitor.name === screen.name` and dodges fullscreen per-monitor
- [x] **6.2** Layer sandwich audited across all 23 windows — bar/tooltip/osd/polkit/shotflash on `WlrLayer.Overlay`, every popup + dock on `WlrLayer.Top`; nothing slides from negative-y except through the bar line
- [x] **6.3** YSurface entrance ritual — drop from behind bar OutBack(0.12), scanline sweep, border burn→cool @230 ms, power line draw, family tick (~400 ms compound gesture) — read end-to-end in PH.04
- [x] **6.4** Exit ceremony — reverse scanline up as the card lifts; panels hold the window ~190 ms post-close so the outro renders while the input mask is already gone
- [x] **6.5** Content cascade — `cascade` item's children stagger-rise 26 ms apart (opacity + Translate y14→0 after 140 ms revealDelay), `kidAnim.createObject()` from Component wrapper, transforms destroyed `onStopped`, `reveal()` hooks fire section rules
- [x] **6.6** YClickAway — first child of content root, card after it, card swallow keeps in-card clicks local; 12/12 floating surfaces carry it
- [x] **6.7** No scrims — popups are fullscreen transparent; input confined via `mask: Region { item: open ? clickAway : null }`; desktop around the card stays clickable until the catcher takes over
- [x] **6.8** Every floating surface composes YSurface (audited PH.04) — no hand-animated popups anywhere
- [x] **6.9** FastWheel on every scrollable (completed in PH.04: 12/12 files)
- [x] **6.10** Bar v2 data-driven — ordered `[{id,zone,enabled}]` array, `present()` runtime conditions, now 18 segments across 3 zones (incl. pluginwidgets), `BarActions.dispatch` click-actions

**New this phase — focus-following placement (`modules/common/FocusMonitor.qml`)**:
- Tracks the compositor-focused monitor via `focusedmonv2` raw events + delayed boot probe (`hyprctl -j monitors`, focused:true output)
- Placement LATCHES at open: `ShellState._exclusive()` calls `latch()` whenever any popup opens, freezing the target screen so a mid-display focus move never drags a visible card across monitors
- All 19 popup windows bind `screen: FocusMonitor.screen` (settings/picker/audio/media/cc/launcher/net/bt/notifycenter/toasts/alttab/overview/polkit/power/calendar/clipboard/emoji/shotflash/weather); Osd moved off hardcoded screens[0]
- Toasts re-latch per notification arrival (Notify.onNotification) — stacks land where attention was, stay put
- Shared Tooltip window now follows its anchor item's bar instance (`anchorItem.Window.window.screen`) instead of living on one fixed screen

**Verification note**: this machine runs a single display (eDP-1). Structural verification on fresh instances ×2: clean boots, 17 open/close IPC cycles across all popup types + toast send/clear → 0 QML errors, RSS ~404 MB. The focusedmonv2 remap path is verified by construction (same raw-event pattern as the working activewindow tracker) but not visually exercised with two displays.

**Cool bits from references**:
- DankMaterialShell: Multi-compositor support (6), per-output workspaces, `wlr-layer-shell` layers (Overlay/Top), `Variants` per-screen, `DankBar` with zone system
- Ryoku: `barkit` per-monitor ShellState slices, each monitor gets one `Scope` carrying its slice
- caelestia-shell: Per-monitor configurations, `dashboard` with monitor-aware settings

**Verification**: On multi-monitor setup, each screen has its own bar/dock; workspace switching works per-monitor; popups from one monitor don't affect another; RSS stays in range.

---

## PHASE 7: Compositor Integration

**Objective**: Integrate with all major Wayland compositors via native protocols.

- [x] **7.1** `Hyprland` — `hl.dsp.focus({window = "address:..."})`, `hl.dsp.workspace.toggle_special("magic")`, `hl.dsp.window.move({workspace = N})`, `hl.dsp.focus({workspace = "N"})`, `hl.config({general.col.active_border = "..."})`, `hl.refreshToplevels()`, `hl.refreshWorkspaces()`, `Hyprland.toplevels.values`, `Hyprland.activeToplevel` (never populates — track via raw events) ✅ *Live-verified every form via the new `compositor dsp` warm-client passthrough (hyprctl eval is a cold client and silently no-ops hl.dsp.*): focus-by-address ✓, window.float toggle/center/resize{x,y}/move{x,y}/fullscreen/pseudo/close ✓, window.move{workspace=N} + focus{workspace=N} ✓, move-to `special:magic` auto-creates it and move{workspace="previous"} restores ✓, focus{workspace="previous"} ✓. **Environment finding**: `workspace.toggle_special(...)`, `focus({workspace="special:*"})`, raw `togglespecialworkspace`, and bare raw keywords are ALL inert under Helmsman 0.56.2 — Overview.toggleScratchpad() rewritten to a verified-verbs toggle (hide focused → magic / restore resident → previous). New `modules/common/Compositor.qml` capability singleton (kind detection via env vars, external-tool probe grim/slurp/hyprsunset/wlsunset/cliphist, Health degradation report) wired into shell.qml boot warm-up; `compositor info`/`compositor dsp` IPC targets.*
- [ ] **7.2** `Niri` — `wlr-gamma-control-unstable-v1` night mode, `wlr-screencopy-unstable-v1` screenshots + color picker, `wlr-layer-shell` integration — N/A on this machine (Niri not installed; Compositor.kind gates all Hyprland-specific paths and reports honestly otherwise)
- [ ] **7.3** `MangoWC` / `dwl` — `dwl-ipc-unstable-v2` tag management, IPC messages — N/A (not installed)
- [ ] **7.4** `Sway` / `labwc` / `i3` — standard i3 IPC integration, `executable` `$mod+c` style keybinds — N/A (not installed); Helmsman keybinds already route user-facing actions through IpcHandlers
- [ ] **7.5** `Scroll` — fractional scaling via `wp-viewporter`, output configuration — N/A (not installed)
- [ ] **7.6** Wayland protocols client implementations — Quickshell 0.3.1 ships no raw wayland-client bindings; layer-shell is consumed natively by every surface (WlrLayershell), screencopy/viewporter/output-management would need a compiled helper which this phase does not add:
  - `wlr-gamma-control-unstable-v1` — night mode color temperature — covered where backends exist: NightLight uses hyprsunset/wlsunset when present (both absent here → gated off, Health-reported)
  - `wlr-screencopy-unstable-v1` — screenshots and color picker — screenshots via grim/slurp (present ✓, Screenshot widget); color picker needs hyprpicker-class tool (absent → widget hides gracefully)
  - `wlr-layer-shell-unstable-v1` — overlay surfaces ✅ (native WlrLayershell throughout)
  - `wlr-output-management-unstable-v1` — display configuration — display page drives hyprctl monitor config instead
  - `wlr-output-power-management-unstable-v1` — DPMS control — dpms dispatch available through `compositor dsp`
  - `ext-data-control-v1` — clipboard history — cliphist absent on this machine → Clipboard widget reports unavailable
  - `ext-workspace-v1` — workspace integration — Hyprland models cover it on the target compositor
  - `keyboard-shortcuts-inhibit-unstable-v1` — shortcut inhibition — not exposed by Quickshell 0.3.1; no consumer feature requires it
- [x] **7.7** D-Bus integration (audited live with gdbus introspect):
  - `org.bluez` — Bluetooth with pairing agent ✅ (BluetoothPanel, verified bus present)
  - `org.freedesktop.NetworkManager` — Network management ✅ (Quickshell.Networking + panel)
  - `net.connman.iwd` — iwd Wi-Fi backend — bus present but unused; NM is the single network path
  - `org.freedesktop.login1` — Session control, inhibitors, brightness ✅ (session module inhibitors chip, power actions)
  - `org.freedesktop.Accounts` — User account info ✅ (system page avatar/face)
  - `org.freedesktop.portal.Desktop` — Desktop appearance settings — bus present; color-scheme read is covered by Theme's own light/dark state
  - CUPS via IPP — Printer management — skipped: no printer UI in scope, no CUPS queue on this machine
  - `org.freedesktop.ScreenSaver` — Screensaver inhibition for media playback — intentionally skipped: owned by portal-hyprland here but nothing ever blanks (no hypridle), so inhibition is dead code; noted for future idle-daemon integration

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