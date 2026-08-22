# YUTASHELL // ROADMAP

A full desktop shell for Hyprland, built on Quickshell 0.3.1.
Design language: neo-brutalist Japanese cyber-minimalist — flat black surfaces, bone-white ink, one acid accent, hairline structure, registration-mark details, uppercase mono type, sparse Japanese micro-labels. No rounded corners. Motion is either instant or a short eased slide. Every pixel earns its place.

**The one-organism rule:** every surface — bar, launcher, control center, OSD, clipboard, screenshot chrome, lock screen — must read as the *same* object viewed from different angles. Same kit primitives, same hairline weight, same corner-tick motifs, same motion curves, same type ramp. If a new panel could be mistaken for another project's popup, it is wrong and gets rebuilt. We are not shipping a bag of tools; we are shipping one machine.

This file is the master checklist. Work top to bottom within the sequencing given at the bottom. Check items off as they land — nothing here is speculative filler; each item names the concrete API it will use, verified against this machine.

Legend: `[x]` shipped · `[ ]` open · phase header marked ✅ DONE / ◐ PARTIAL / ⬜ OPEN

---

## Verified environment facts (build against these)

Confirmed on this machine (re-verify after major system updates):

### Quickshell 0.3.1 — QML modules present under `/usr/lib/qt6/qml/Quickshell`

| module | what it gives us | feeds phase |
|---|---|---|
| `Quickshell.Bluetooth` | BlueZ adapters/devices/pairing/trust/battery | PH.06, CC |
| `Quickshell.Networking` | NetworkManager: devices, wireless scan, connect, state | PH.06, CC |
| `Quickshell.Services.Mpris` | players, metadata, transport, position | PH.07, CC |
| `Quickshell.Services.Pipewire` | nodes, streams, volumes, defaults, mutes | PH.07, CC |
| `Quickshell.Services.Notifications` | `NotificationServer` — claim org.freedesktop.Notifications | PH.05 |
| `Quickshell.Services.Pam` | PAM auth for the lock screen | PH.08 |
| `Quickshell.Services.Greetd` | greeter hooks (future) | PH.08+ |
| `Quickshell.Services.Polkit` | themed privilege agent | PH.08 |
| `Quickshell.Services.UPower` | battery device model (alternative to raw sysfs) | PH.13 |
| `Quickshell.Wayland._Screencopy` | native Wayland screencopy — candidate for window previews without spawning grim | PH.09, PH.10 |
| `Quickshell.Wayland._IdleInhibitor` / `_IdleNotify` | manual + event-driven idle control | PH.08 |
| `Quickshell.Wayland._ToplevelManagement` | extra window control surface | PH.10 |
| `Quickshell.Hyprland._GlobalShortcuts` | register shell shortcuts without editing binds manually | PH.04+ |
| `Quickshell.Widgets`, `DBusMenu`, `WindowManager` | icon rendering, tray menus, window models | existing |

### CLI dependencies

| present | absent (gates listed phase — install then, not before) |
|---|---|
| `matugen`, `awww` (theme pipeline, live) | `cava` → PH.15 media visualizer (must degrade gracefully without it) |
| `grim`, `slurp`, `wl-copy`, `cliphist` (capture + clipboard, live) | `ddcutil` → PH.07/PH.16 external-monitor brightness (**no `/sys/class/backlight` exists — this is a desktop**) |
| `nvidia-smi` (GPU stats source), `gpu-screen-recorder` 6.x (recording) | `hyprsunset` → PH.07 night light |
| | `powerprofilesctl` (power-profiles-daemon) → PH.08 power plans |
| | `hyprpicker` → PH.11 color picker |

### Hardware / compositor quirks

- NVIDIA RTX 5080 (GB203): GPU utilization/temp via batched `nvidia-smi --query-gpu=...` probes; never spawn more than one at a time.
- Sensors live in `/sys/class/hwmon`: `coretemp` (CPU), `nvme` ×2 (SSD), `asus`, `spd5118` ×2 (RAM temp), `acpitz`.
- Helmsman Lua dispatcher — raw dispatch strings fail; wrapper functions send `hl.dsp.*` forms (see AGENTS.md).
- `Hyprland.activeToplevel` never populates — track focused windows via `activewindow`/`activewindowv2` events + one-shot `hyprctl -j activewindow` probe.
- No CJK font installed today → `Theme.jpEnabled` false → every kanji string needs a romaji fallback (this includes the new identity wordmark).

---

## Conventions (read before building anything)

These rules keep the shell coherent as it grows. Breaking them creates rework later.

- [x] Single source of truth for visuals: everything reads colors/fonts/metrics from the `Theme` singleton (`theme/Theme.qml`, imported as `qs.theme`). No hardcoded colors in modules — this contract is what makes matugen-driven recoloring possible without touching module code.
- [x] Imports use the quickshell scheme: `import qs.theme` for tokens, relative imports within a module folder, `import "ui"` for a module's private components.
- [x] Module folders are self-contained under `modules/<feature>/` with an entry component named after the feature. Cross-module reuse goes into `modules/common/`.
- [x] State persistence pattern: JSON config read/written with `FileView` (`JsonAdapter` + `writeAdapter()` to persist, coalesced through the flush timer). One file: `~/.local/state/yutashell/state.json`. Modules never write their own dotfiles.
- [x] IPC pattern: every user-facing action is exposed through `IpcHandler` so keybinds, CLI, and panels all drive the same functions instead of duplicating logic.
- [x] Layer policy: bars/docks use plain `PanelWindow`; transient UI uses `PanelWindow` + `WlrLayershell.layer: WlrLayer.Overlay` with keyboard focus `Exclusive` while open, `None` closed. (Settings panel + picker already follow this.)
- [x] Animation policy: hover/focus snap instantly (brutalist). Only positional indicators animate — 120–180 ms OutCubic (`Theme.movFast`/`movMed`); surface entrances use `Theme.movSlow` 260 via YSurface. YButton's hard-shadow press collapse is the one physical flourish.
- [x] Japanese labels: kanji/kana always gated behind `Theme.jpEnabled` with a romaji fallback, so nothing ever renders tofu.
- [x] Compositor dispatches go through small wrapper functions (e.g. `Workspaces.switchTo(id)` sending `hl.dsp.focus({ workspace = "N" })`), never inline strings.
- [ ] **One poller per datum:** periodic sampling (/proc, hwmon, nvidia-smi) lives ONLY in the PH.13 `SystemStats` singleton. Bar, control center, thresholds and future widgets consume it — no module spins up a second Timer over the same file. (StatsCluster gets migrated onto it.)
- [ ] **Optional-dep graceful degradation:** any feature backed by an absent CLI (`cava`, `hyprsunset`, `ddcutil`, `hyprpicker`) hides itself or renders a flat fallback. Never crash, never show a dead button.
- [ ] **Live identity tokens:** hostname and version render from probed sources (`/proc/sys/kernel/hostname`, `Theme.version`) — never hardcoded strings.
- [ ] **Panels are read-mostly:** popups (control center, OSD, calendar) expose glanceable state + quick actions only. All deep configuration belongs to the settings panel. If a popup starts growing steppers and path pickers, move them.
- [ ] **Kit-only composition:** every new surface composes from `modules/common/ui` (YButton/YSwitch/YRow/YSection/YField/YChip/YScroll) plus Theme tokens. Hand-rolled buttons/rows inside a feature are a bug.

---

## Phase 0 — Foundations ✅ DONE

The skeleton the rest of the shell grows into.

- [x] Repository structure: `shell.qml` entry, `theme/` singleton module, `modules/bar/`
- [x] `Theme.qml` design-token singleton (palette, fonts, metrics, JP-font detection)
- [x] Verified import scheme works (`qs.theme` + qmldir singleton registration)
- [x] Verified runtime APIs against installed Quickshell 0.3.1 (Hyprland IPC, SystemTray, FileView, Io.Process, event stream shapes)
- [x] Discovered + documented environment quirks (Lua dispatcher, inactive `activeToplevel`, missing CJK font)

## Phase 1 — Taskbar v1 ✅ DONE

Top bar: identity block, workspace switcher, focused-window title, system tray, live stats cluster (NET/CPU/MEM/BAT), clock. All live data, no placeholders.

- [x] PanelWindow frame: flat `bg`, bottom hairline, acid brand tick
- [x] Divider primitives with crosshair registration marks
- [x] Identity block: notched square, wordmark stack, blinking cursor block, hover inversion
- [x] Workspace switcher: dynamic slots (min 6), occupied/empty states, active fill + sliding acid underline, urgent red-blink via `rawEvent("urgent")` address matching, click-to-focus via Lua-form dispatch
- [x] Focused window title: event-tracked via `activewindow`/`activewindowv2` events + startup `hyprctl -j activewindow` probe (this build's `activeToplevel` never populates)
- [x] System tray: SNI icons, left-click menu (`display()`), middle-click `secondaryActivate()`, wheel `scroll(delta, false)`
- [x] Stats cluster: `/proc/net/dev` rate deltas, `/proc/stat` CPU % + 6-cell VU meter (top cell alerts red), `MemAvailable` %, battery via sysfs BAT1→BAT0 fallback, charging bolt, low-battery red
- [x] Clock: blinking colon, acid seconds, weekday/date line, kanji weekday when CJK font present (romaji/year fallback otherwise)
- [x] Tooltips for tray icons + stats columns (small brutal label card, Overlay layer, click-through `mask`, margins-positioned window in shell.qml)
- [x] Wheel-over-workspaces cycles workspaces; middle-click moves focused window there (`hl.dsp.window.move`)
- [x] Per-monitor instances: one bar window per connected screen via `Variants` over `Quickshell.screens` (`screen: modelData`); instances appear/disappear with monitor hot-plug
- [x] Optional media segment (MPRIS track ticker) between tray and stats: prefers the playing player, artist — title marquee (scrolls only while playing and overflowing; snaps home when paused), click play/pause, middle-click/wheel next & previous, hover tooltip with player identity, `barMedia` toggle persisted in state.json and exposed in the settings Modules tab

## Phase 2 — Theme engine & matugen ✅ DONE

Goal: wallpaper-driven palettes with user-selectable schemes, applied live across the whole shell by rewriting only token values.

How: matugen generates a palette JSON from the wallpaper; `Theme` loads it at startup and watches it with `FileView { watchChanges: true }` so regenerating a scheme repaints every open surface instantly. All modules consume only `Theme.*`, so no module code changes — ever.

- [x] Wallpaper engine picked: **awww** (`awww-daemon`, auto-started detached on first paint; swww rejected)
- [x] matugen wired through a generated registry config: `~/.local/state/yutashell/matugen.toml` written from the template registry; the shell's own template lives at `theme/matugen/yutashell.json` → emits `~/.local/state/yutashell/theme.json`
- [x] `Theme` dynamic token engine: `_applyTokens()` maps scheme/wallpaper JSON → tokens with hardcoded defaults as fallback; partial maps legal
- [x] Wallpaper set flow: settings grid / IPC picks image → matugen regenerates all enabled templates → awww paints → theme.json rewritten → shell recolors live
- [x] Scheme presets: acid, crimson, cyan, amber + catppuccin, cyberpunk, doom, gruvbox, mono (b/w), tokyonight, kanagawa, dracula (12 total) in `theme/schemes/`
- [x] Export templates: **full matugen-themes catalog** vendored into `theme/matugen/catalog/` via `TemplateCatalog.qml` (~63 templates incl. `cava-colors.ini`, hyprland, terminals, editors); all DISABLED by default, opt-in via settings or `templates` IPC; custom entries supported; persisted in state.json
- [x] Standalone wallpaper picker: own overlay panel + keybind (`picker toggle`); search-as-you-type, cursor/hover tile states, hand-drawn scroll indicator, OOM-safe thumbnails
- [x] Contrast self-check: ink/bg ≥ 4.5, acid/bg ≥ 3.0, alert/bg ≥ 2.5 asserted at load, warnings logged
- [x] Light-mode variant pass: `Theme.dark` flag; light palettes are **generated at runtime** by HSL-remapping any token map (preset or matugen wallpaper palette) — paper surfaces, ink text — while acid/alert are contrast-fitted against the live bg until they pass the same thresholds the self-check asserts. No per-scheme light files to maintain. Persisted via state.json; toggled live from settings or IPC (`theme dark on|off|toggle`)

## Phase 3 — Settings panel (control core) ✅ DONE

Current state: right-side drawer/popout built entirely from the shared kit. Tabs: Appearance / Templates / Modules / System(stub) / About — lazy Loaders off a declarative page registry. Width stepper (400–760 px), popout-card mode, persisted. IPC `panel toggle/open/close`.

> The big settings expansion is **PH.16** by design — don't build new tabs here; this phase is closed at "control core complete".

- [x] v3 rebuild: whole panel recomposed from the shared kit — one type ramp, one rhythm scale, acid reserved for semantics
- [x] Drawer scaffold: right-anchored overlay, slide-in 160 ms OutCubic, dim scrim, ESC/click-out closes; `layer.enabled` raster trick so slides animate at compositor cost
- [x] Tab framework: lazy Loaders off a declarative page registry
- [x] Appearance tab: scheme preset swatches (adaptive grid), current-wallpaper card + picker/random/rescan, follow-wallpaper toggle
- [x] Control-core presentation: drawer width stepper + popout-card mode, persisted, live-animated switch
- [x] Templates tab: full catalog browser — search, grouped rows, enable toggles, add-custom form, enabled/total counter
- [x] Modules tab: bar segment toggles (tray/stats/clock) persisted, consumed live by Bar layout bindings
- [x] About tab: version, stack info, live scheme source, IPC cheatsheet
- [x] IPC handlers for panel/picker/scheme/wallpaper/theme/templates; identity block opens the panel
- [x] Appearance leftovers delivered in-phase: light/dark segmented toggle + accent override swatch strip (curated candidates, slash tile = follow scheme, live-recolors, persists) in the Appearance tab's "Mode & accent" section
- [x] IPC extended: `theme dark on|off|toggle`, `theme accent <#hex|none>` — same implementation drives keybinds, CLI, and the settings toggle

> Everything beyond this point (the 13-tab customization suite, global search, per-module page registry) is **PH.16** by design. The System tab keeps its forward-reference stub rows until those phases land.

## Phase 4 — App launcher ✅ DONE

Goal: fast fuzzy launcher indexing every installed .desktop entry, brutal styling, grid + list modes. This is the daily-driver surface — it must feel instant.

How: enumerate via `DesktopEntries` (Quickshell's freedesktop parser), score with a small custom fuzzy matcher (subsequence + boundary bonuses), render in an overlay `PanelWindow` with `WlrLayershell.keyboardFocus: KeyboardFocus.Exclusive`. Launch via `entry.execute()` (verified API — no manual Process/Exec parsing needed). Placement/behavior/appearance knobs persist to ShellState so PH.16's launcher tab just edits values.

Shipped in `modules/launcher/` (`AppLauncher.qml` + `fuzzy.js`); UI builds lazily on first open then stays warm — reopen paints instantly, full app grid costs ~16 MB RSS.

- [x] Launcher scaffold: centered overlay (`launcherAnchor`: center/left/top, persisted), search field auto-focused, warm-open instant paint + one-time first build, ESC/scrim closes
- [x] DesktopEntries listing with icon resolution via `IconImage`; missing-icon fallback = acid square with initial letter
- [x] Fuzzy scoring + ranking (`fuzzy.js`: subsequence + boundary/streak bonuses, name>id>keywords weighting), pinned/recents ordering from state.json
- [x] Grid mode (icon tiles) + list mode (rows with genericName sub-labels), togglable in-session (TAB or header segment), remembered
- [x] Enter launches, arrows navigate (←→ jump by grid columns), TAB switches mode, shift-del removes from recents
- [x] Japanese micro-label accents in header (アプリ / APP.LAUNCHER) — romaji fallback while jpEnabled is false
- [x] IPC `launcher toggle/open/close` (bind line documented in README "Keybinds & IPC")
- [x] Optional: calculator row (charset-whitelisted expression eval, click/Enter copies via wl-copy) and `:` command mode (`:scheme/:wall/:dark/:accent/:panel/:picker` — calls the same singletons the IPC handlers use)
- [x] Optional: desktop-action rows (`DesktopEntry.actions`, ` ↩` suffix, parent-app recents credit) once query length ≥ 2

Extras beyond spec: right-click tile/row toggles pin (acid corner-notch indicator), footer count chip + keymap hints, unknown-command empty state, result cap (64) in query mode.

## Phase 4.5 — Experience overhaul ✅ DONE

User-directed pass: make the shell feel like one fluid organism. Bar on top, everything drops from behind it, no dimming anywhere, every surface customizable.

- [x] **Layer sandwich**: bar → `WlrLayer.Overlay` (topmost); all popups → `WlrLayer.Top` — surfaces slide out from BEHIND the bar (the shell's signature entrance)
- [x] **Scrim abolition**: no popup darkens the desktop; input confined to the card via `mask: Region { item }`, desktop stays visible and clickable around it; ESC/keybind/IPC close only
- [x] `Theme.movSlow: 260` added — reserved for surface entrances (`movFast`/`movMed` stay for indicators/exits)
- [x] **YSurface kit** (`modules/common/ui/YSurface.qml`): one component owns drop-from-behind-bar choreography + card chrome (bgAlt, lineStrong border, acid corner tick); settings/picker/launcher all compose it
- [x] **FastWheel kit**: WheelHandler drop-in for every Flickable/GridView/ListView (notchStep 132) — fixes "scrolling slow as fuck"
- [x] Settings: nav rail → bar-style horizontal TAB STRIP (numbered segments, sliding acid underline, JP accents); page memory (`panelLastPage`) restores last tab on reopen
- [x] Settings customization: PLACEMENT selector (center/left/right → `panelAnchor`), width stepper 640–1200 (`panelW`, default raised 464→880)
- [x] Picker rewrite: default **carousel deck** mode — Hearthstone-style horizontal snap ListView, hero card scaled/centered, neighbors dimmed+shrunk, wheel flips, click current applies; grid ("sheet") mode retained behind a DECK/SHEET segment (`pickerMode` persisted)
- [x] Launcher: real centered card (not fullscreen feel) via YSurface, `launcherW` 480–960 customization, icon rendering fixed (`IconImage.implicitSize` + status-driven initials fallback)

Verification notes: fresh-instance smoke clean; all three surfaces map Top-layer under Overlay bars via `qs ipc --pid <test-pid>` targeting; RSS 408 MB with panel open.

## Phase 5 — Notification daemon ⬜ OPEN

Goal: fully themed replacement for mako/dunst with history center. DND lives here and is consumed by the bar (PH.14) and control center HOME (PH.15).

How: implement an on-dbus notification server with `Quickshell.Services.Notifications` (`NotificationServer`: claim the interface, emit `Notification` objects). Cards are plain QML — urgency maps to border/accent rules from Theme.

- [ ] Claim org.freedesktop.Notifications; actions, icons, images, urgency supported
- [ ] Card design: flat black card, 1px urgency-colored border (normal=hairline, critical=alert), timeout progress as shrinking acid underline
- [ ] Stack manager below bar (corner configurable), max N visible, slide-in/out, hover pauses timeouts
- [ ] Inline actions row (buttons styled like workspace blocks; global "show action buttons" toggle for PH.16)
- [ ] History store (ring buffer + optional state.json dump), browsable notification center with clear-all/replay — reused by CC notifications tab (PH.15)
- [ ] DND toggle: IPC (`dnd toggle/on/off`) + bar indicator + CC quick toggle; suppressed-notifications counter chip while active
- [ ] Per-app overrides (block/quiet) editable in settings (PH.16 notifications tab)
- [ ] Configurable default timeout; critical persists until dismissed
- [ ] Display-fields toggles (app name / body / icon / timestamp) feeding PH.16

## Phase 6 — Connectivity suite ⬜ OPEN

Goal: WiFi, Bluetooth, VPN/DNS status — native panels, no nm-applet dependency for UI. Feeds the CC network/bluetooth tabs (PH.15) and bar segments (PH.14).

How: `Quickshell.Networking` wraps NetworkManager; `Quickshell.Bluetooth` wraps BlueZ. Both verified present in this install.

- [ ] Bar segments: wifi icon w/ signal tiers (click → network panel via PH.14 action binding), BT icon when adapter powered
- [ ] WiFi panel: network list w/ signal bars, join dialog w/ password field, saved-network connect/disconnect/forget
- [ ] Bluetooth panel: device list w/ battery % where exposed, pair/trust/connect/remove, adapter power toggle, **per-device autoconnect flags**
- [ ] VPN: list active VPN connections, connect/disconnect toggle (NetworkManager VPN service model)
- [ ] DNS view + quick-set (current resolvers shown; per-connection DNS override field)
- [ ] Airplane mode master toggle (rfkill-equivalent via NM/BlueZ radio states) — also surfaced in PH.16 security tab
- [ ] Ethernet/wired status indicator
- [ ] Connection-change toasts routed through the PH.05 notification system
- [ ] Shared connectivity data model so CC tabs and panels read one source (no duplicate scans)

## Phase 7 — Audio, media, displays & OSDs ⬜ OPEN

Goal: PipeWire volume control, MPRIS media widget, volume/brightness/mic OSDs, night light. Feeds CC media/audio/monitors tabs (PH.15).

How: `Quickshell.Services.Pipewire` (nodes, streams, default device, linear→cubic mapped volumes), `Quickshell.Services.Mpris` (players, metadata, position). Brightness: **this box has no `/sys/class/backlight`** — external monitors go through `ddcutil` (dep install required, detected at runtime per-output).

- [ ] Bar audio segment: output device icon + level, wheel steps volume, click → audio panel (PH.14 action binding)
- [ ] Audio panel: sinks/sources list, per-device sliders (cubic taper), per-app streams w/ mute, default-device star
- [ ] Input/mic section w/ mute indicator tied to bar icon state
- [ ] **Audio overdrive**: allow output volume beyond 100 % up to a configurable ceiling (default 130 %, clamp token in ShellState) — flagged visually past 100 %
- [ ] MPRIS mini-widget: expands the Phase 1 media ticker into a full widget — app icon, seekbar + album art placeholder block (no art = acid square)
- [ ] Volume OSD: horizontal brutal slider appearing on key events, auto-fade; mic-mute variant (red slash)
- [ ] Brightness OSD same pattern; per-output writes via `ddcutil` batched queries (cache current values; ddcutil is slow — never call synchronously on hover)
- [ ] Night light service: `hyprsunset` wrapper (spawn/detach, temperature slider 1000–6500 K, schedule optional), exposed as CC quick toggle + bar chip when active (dep: install hyprsunset; hide gracefully if absent)
- [ ] Media/brightness/volume keybinds registered through IPC actions (and/or `Hyprland._GlobalShortcuts`)
- [ ] OSD placement/behavior knobs (corner, size, fade ms) persisted for PH.16 OSD tab

## Phase 8 — Session, power & lock screen ⬜ OPEN

Goal: secure, themed end-of-session UX + power-plan control.

How: `Quickshell.Services.Pam` for lockscreen auth (pick/verify a `/etc/pam.d/` service name), `Quickshell.Services.UPower` + `powerprofilesctl` (power-profiles-daemon — **needs installing**) for plans, `Quickshell.Services.Polkit` for a themed privilege agent.

- [ ] Power menu overlay: lock/suspend/hibernate/reboot/poweroff/logout tiles, hold-to-confirm on destructive ones (hold duration configurable, can be disabled)
- [ ] Tile set + order persisted (PH.16 power tab)
- [ ] Lock screen: full-screen overlay on selected monitor(s), clock + date in house style, password field, Pam auth, wrong-attempt shake (instant offset snap), suspend-on-idle hook, **user avatar displayed if set** (PH.16 shell tab provides the asset)
- [ ] Lock screen monitor selection: primary / all / explicit list (persisted)
- [ ] Idle management: inhibit-aware timer using `Wayland._IdleNotify` + `_IdleInhibitor`; optional **lock / sleep / shutdown timers — OFF by default**, configured in PH.16 power tab
- [ ] Power plans: read/set via `powerprofilesctl` (performance/balanced/saver), exposed in bar chip (optional), CC power tab, and here
- [ ] Polkit agent dialog themed like the rest of the shell
- [ ] Session inhibit indicator in bar when apps block sleep/screenshots
- [ ] Logout kills quickshell cleanly (state flushed first — respect the flush-timer coalescing)

## Phase 9 — Dock ⬜ OPEN

Goal: bottom dock with pinned + running apps, previews, hide modes. Distinct from the bar taskbar (PH.14): dock is a separate, optional, macOS-style surface.

How: running windows from `Hyprland.toplevels` grouped by class; pin list in state.json; activation/minimize via Lua dispatch wrappers. Previews via native `_Screencopy` if practical, else `grim` captures cached per address (refreshed on hover only).

- [ ] Dock scaffold: bottom-centered PanelWindow, exclusive-zone option vs overlay float
- [ ] Pinned + running merge view, active-window indicator tick
- [ ] Click: launch/focus/minimize cycle; middle-click new instance; scroll cycles windows of that app; right-click context menu (pin/unpin/close)
- [ ] Drag reorder pins, drag-to-pin/unpin (custom drag layer)
- [ ] Hover preview cards: window thumbnail + title, click focuses
- [ ] Intellihide modes: always / dodge windows / never
- [ ] Multi-monitor: shows current monitor's windows in per-monitor mode; monitor assignment knob persisted (PH.16 dock tab)
- [ ] Enable/disable master switch — dock is OFF-by-default-optional, ON in PH.16 dock tab

## Phase 10 — Overview & window management extras ⬜ OPEN

Goal: compositor-level navigation superpowers surfaced in-shell.

How: overview grid renders per-workspace thumbnails (same capture pipeline as dock previews) laid out from `Hyprland.workspaces` + client geometry; clicks dispatch focus/move via the Lua wrapper family.

- [ ] Overview overlay: workspace grid w/ thumbnails, labels 01…N, click to jump
- [ ] Drag window thumbnail onto another workspace tile to move it
- [ ] Alt-tab style window switcher overlay (most-recent ordering from Hyprland events), brutal selection frame
- [ ] Scratchpad controller for `special:magic` (matching existing Helmsman bind), drop-to-scratchpad gesture
- [ ] Floating-layout helpers: quick-tile presets dispatched to Hyprland
- [ ] Optional scrolling-layout awareness (Helmsman's dwindle/scrolling toggle reflected in UI)

## Phase 11 — Widgets, utilities & capture suite ⬜ OPEN

Goal: the convenience layer. Each widget is a standalone module that later surfaces get embedded into (CC tabs reuse calendar/weather; bar click-actions reuse everything).

- [ ] Calendar popup from clock click: month grid, today boxed in acid, month/year nav, JP holiday coloring optional (gated), event stub API. **Shared component** — CC calendar tab embeds the same view
- [ ] Weather module: open-meteo fetch via `Process curl` → cache file in `~/.local/state/yutashell/weather.json`, manual location setting in state.json (lat/lon + label), refresh interval, units follow the locale formatter (PH.13). Bar temp chip optional + CC weather tab embeds conditions/forecast strip
- [ ] Update counter: `checkupdates` polled sparsely (pacman-contrib), click → list + terminal launch
- [ ] **Clipboard manager popup** (cliphist is installed): IPC/keybind opens centered overlay listing history — search-as-you-type, monospace previews elided, enter/wl-copy re-copies + toast, del deletes entry, pin favorites to top (state.json). Themed like the launcher: flat card, hairline rows, acid selection bar, micro-label header 履歴 / CLIPBOARD. Graceful empty state when cliphist store is empty; whole feature hideable (PH.16 shell tab)
- [ ] **Screenshot suite** (grim + slurp installed): IPC targets `shot region|full|window` —
  - slurp styled to match: `-b` black fill, `-c` acid border, mono font label for dimensions
  - flash frame + shutter tick animation on capture (brief white 1px border pulse — instant, no glow)
  - after-shot action bar (tiny overlay chip, auto-dismiss): save / copy (wl-copy) / annotate-later / discard
  - save dir + filename template configurable (`~/Pictures/Shots/%Y%m%d-%H%M%S.png` default), persisted
  - preview thumbnail toast routed through PH.05 notifications with click-to-open
  - window mode: focused-window geometry via `hyprctl -j activewindow` at=box
- [ ] Screen-recording state chip in bar when `gpu-screen-recorder` runs, click stops it (installed — detect via process probe / its session control)
- [ ] Color picker (`hyprpicker`) with hex copy toast (dep absent today — hide gracefully)
- [ ] Emoji/kaomoji picker (fuzzel-style grid, JP-first categories, recent strip)

## Phase 12 — Polish, performance & distribution ◐ CONTINUOUS

Goal: ship-quality. Items here get revisited after every big phase lands.

- [ ] Animation audit against the motion policy (snap vs eased inventory per surface)
- [ ] Perf pass: no per-frame property churn, layer-shell exclusivity correct, idle CPU ≈ 0 when static (profile with `perf`/the shell's own CPU meter)
- [ ] Multi-monitor parity tests (per-monitor bars/dock, focus correctness)
- [ ] Accessibility pass: contrast ratios enforced by Theme loader (done), font-scale factor token (feeds PH.16 UI-scale setting)
- [ ] Graceful degradation matrix: no tray apps, no battery, no network, no CJK font, no cava/grim/cliphist/ddcutil/hyprsunset — all verified non-crashing
- [ ] Error surface: failed module loads show a minimal in-bar warning chip instead of silence
- [ ] Install script: deps checklist (quickshell ≥ 0.3.1, JetBrainsMono NF, noto-fonts-cjk, matugen, awww, grim, slurp, wl-clipboard, cliphist; optional: cava, hyprsunset, ddcutil, power-profiles-daemon, hyprpicker, pacman-contrib; gpu-screen-recorder ships in the recording phase)
- [ ] Wiki: screenshots/GIFs per phase, keybind table, theming guide (token reference)
- [ ] Version tags aligned to completed phases; changelog discipline (`Theme.version` is the single source — bump it with every tagged release; the identity block renders it)

## Phase 13 — Unified system data layer ⬜ NEW

Goal: ONE sampling engine feeding bar, control center, thresholds, and future widgets. Kills the current pattern where StatsCluster privately polls /proc and every future surface would copy it.

How: new singleton `modules/common/SystemStats.qml`. Owns all Timers/FileViews/process probes. Consumers bind to properties; nothing else touches /proc.

- [ ] `SystemStats` singleton: CPU % (per-core + aggregate), memory %/used/total, network rates (per-iface + aggregate), disk IO rates (`/proc/diskstats` deltas), load avg, uptime
- [ ] Temps from `/sys/class/hwmon`: coretemp (CPU package), nvme ×2, RAM (`spd5118`), chipset (`asus`/`acpitz`) — auto-discovered by name, not hardcoded index
- [ ] GPU stats via batched `nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,power.draw --format=csv,noheader,nounits` on a slower interval (it's a heavyweight binary — one instance, 3–5 s, never per-frame)
- [ ] Battery: migrate sysfs BAT1→BAT0 fallback logic out of StatsCluster (or swap to `Quickshell.Services.UPower`)
- [ ] Two poll classes: FAST (cpu/mem/net, 2 s default) and SLOW (temps/gpu/disk/io, 5 s default); intervals configurable via ShellState (PH.16 system tab steppers)
- [ ] Threshold signals: `warnRaised(kind)`/`critRaised(kind)` for cpu%/temp/mem/bat with configurable limits (defaults: cpu warn 85 crit 95, temp warn 80 crit 90, mem warn 90, bat warn 20 crit 10) — drives bar alert colors, CC system highlighting, optional PH.05 notifications
- [ ] Units/locale formatter functions in the same singleton or a sibling: byte-rate formatting (exists — migrate `fmtRate`), 12h/24h time strings, metric/imperial temp+wind, weekday/date formats — consumed by clock, weather, stats everywhere (PH.16 shell tab sets the prefs)
- [ ] Hostname probe: read `/proc/sys/kernel/hostname` once via FileView (fallback `uname -n` Process) → `SystemStats.hostname`
- [ ] Migrate `StatsCluster.qml` to consume SystemStats; delete its private FileViews/Timer; re-run RSS smoke test
- [ ] Consumer-count awareness: SLOW-class polling may idle down when no panel is watching (perf guard, keep simple)

## Phase 14 — Bar v2: taskbar, extra stats & full customization ⬜ NEW

Goal: turn the bar from a fixed layout into a configurable organism. Taskbar with real interactions, new stat segments, reorderable/toggleable segments, and per-segment click-actions. Plus the identity-block rename.

### Identity block (quick win — can land any time)

- [ ] Line 1: `{HOSTNAME} // 因果` — hostname from SystemStats probe; 因果 gated behind `Theme.jpEnabled`, romaji `INGA` fallback (convention)
- [ ] Line 2: `YUTA.SHELL // v{Theme.version}` (replaces `SYS.BAR // v…`); keep blinking cursor block + hover inversion behavior
- [ ] Bump `Theme.version` to match actual release numbering when this lands

### Taskbar segment (new)

- [ ] Running windows grouped by app class from `Hyprland.toplevels.values`; merged with pinned-apps list (state.json)
- [ ] App identity: desktop-entry icon via `IconImage` (lookup through DesktopEntries), Nerd Font glyph fallback, acid underline tick on the focused app's button, running-but-unfocused = hollow tick
- [ ] Left-click: launch if not running → focus if not focused → minimize-cycle if focused
- [ ] Middle-click: new instance
- [ ] Right-click context menu (kit-composed popup): pin/unpin, new instance, close window / close all windows, app-specific desktop actions if declared
- [ ] Scroll over an app button cycles that app's windows
- [ ] Hover tooltip: window title(s)
- [ ] **Drawer mode** (setting: off / overflow-only / always): when taskbar exceeds its configured width or count, excess apps collapse into a chevron that expands an in-bar drawer row; remembered per session
- [ ] Optional per-monitor filtering (only this screen's windows) once multi-monitor bar instances exist

### Extra stat segments (new — all fed by SystemStats)

- [ ] `CPU.TEMP` (coretemp package °C), `GPU` (usage % + °C combined cell), optional `DISK.IO` — each individually toggleable, alert-colored past thresholds
- [ ] Existing NET/CPU/MEM/BAT cells refactored onto SystemStats (no format drift)

### Segment framework (the customization core)

- [ ] Declarative segment model persisted in state.json: ordered array `{id, zone: left|center|right, enabled}` — covers identity, workspaces, taskbar, active-window, tray, stats cells, clock, media, net/bt chips, recording chip
- [ ] PH.16 bar tab renders this model: toggles, up/down reordering (drag-reorder later), zone assignment
- [ ] Bar height/scale multiplier (0.8–1.4×) and top/bottom position, persisted; layout math derives from Theme metrics × scale
- [ ] **Click-action bindings:** map each segment id → action (`calendar` | `network` | `bluetooth` | `audio` | `power` | `notifications` | `controlcenter` | `launcher` | `none` | `ipc:<target>/<fn>`), persisted. Defaults: clock→calendar popup, net→network panel, bat→power menu, cpu/gpu/mem→CC system tab, tray→native menus (unchanged), identity→settings (unchanged), workspaces→native behavior (never remapped away)
- [ ] Wheel-up/down bindings optional per segment (e.g. audio wheel = volume — that one is default)

## Phase 15 — Control center ⬜ NEW

Goal: one themed popup falling from the bar that answers "what's going on / quick toggle / quick adjust" — nothing more. Deep config stays in settings (one-organism rule: read-mostly panels).

How: overlay `PanelWindow` dropping from beneath the bar (anchor: center by default, configurable left/center/right + per-monitor) via YSurface (`Theme.movSlow` OutCubic with the `layer.enabled` raster trick); NO scrim (mask-input pattern, PH.4.5); ESC/keybind closes; mask region while animating. Tab strip along the top: uppercase micro-labels + JP micro-labels (gated), sliding acid underline (same motif as settings tabs). Tabs are lazy Loaders — heavy lists only build when visited. Everything composes from the kit. IPC `cc toggle/open/close`.

Tabs (11):

- [ ] **HOME** — glance cards: current wallpaper thumb (sourceSize-gated), avatar (if set), mini now-playing, time + weather line; quick-toggle grid: wifi, bluetooth, power plan cycle, night light, DND (+ idle-inhibit later). Toggles reflect live state, tap flips, long-press/deep-click jumps to the full panel
- [ ] **MEDIA** — MPRIS player card: art block (acid square when none), scrolling title/artist, transport (prev/play/next), seekbar, volume; **cava visualizer strip** along the bottom — `Process` cava in ascii mode parsed into a Repeater of flat bars (acid fill, hairline empties); if cava is absent → static hairline baseline (graceful). Note: catalog already ships `cava-colors.ini` template so the visualizer inherits the palette
- [ ] **AUDIO** — output/input device pickers (rows, star = default), cubic-taper level sliders, mutes; collapsed per-app stream list (mute only — fader-level per-app mixing stays in the audio panel)
- [ ] **MONITORS** — one row per output: brightness slider (ddcutil-backed; hidden gracefully when unavailable) + scale select (quick edit only; full display config is a settings concern)
- [ ] **SYSTEM** — sparkline strips from SystemStats: CPU (aggregate + hottest core), GPU, MEM, IO, NET down/up; threshold breaches tint alert-red; poll interval respects the FAST/SLOW classes; graphs sample only while the tab is open
- [ ] **POWER** — power-plan segmented switch (perf/balanced/saver), battery detail (% , charging state, time-to-empty when UPower exposes it), link-chip to session menu
- [ ] **NETWORK** — wifi on/off, top networks by signal w/ connect (password dialog inline), current connection details, VPN toggle row, wired status
- [ ] **BLUETOOTH** — adapter toggle, paired devices w/ connect/disconnect/remove, autoconnect stars, scan button w/ spinner-as-progress-ticks
- [ ] **WEATHER** — conditions hero (big temp, condition line, location label), 5-day forecast strip, last-updated stamp; embeds the PH.11 weather module
- [ ] **CALENDAR** — embeds the PH.11 calendar popup component verbatim
- [ ] **NOTIFICATIONS** — history list from PH.05 store, clear-all, per-item replay/dismiss, DND switch mirrored
- [ ] Tab set/order itself configurable (PH.16 control-center tab): hide tabs you don't use, reorder the strip

## Phase 16 — Settings panel v4: full customization suite ⬜ NEW

Goal: the settings panel grows into the shell's constitution — every knob the shell has, findable in seconds. This absorbs Phase 3's leftovers and replaces the stub System tab.

Scaffold rework first:

- [ ] Two-level nav rail: groups LOOK / BEHAVIOR / SYSTEM containing the 13 tabs below (rail scrolls if needed); sliding acid tick retained
- [ ] **Global settings search:** field in the header filters rows across ALL tabs (each registered row carries `{tab, title, keywords}` metadata; search jumps + highlights)
- [ ] Page registry becomes true per-module registration: modules ship their settings page + metadata; SettingsPanel stops hardcoding foreign rows
- [ ] Pages stay lazy Loaders; search indexes metadata only (no page instantiation on type)
- [ ] Migration map — nothing lost: Templates tab → Appearance ▸ matugen templates section; Modules (bar toggles) → Bar tab; System stub → real System/Services/Security tabs; About → global footer entry + About page kept

The thirteen tabs:

- [ ] **APPEARANCE** — scheme preset swatches (existing), follow-wallpaper (existing), light/dark mode + accent override (engines shipped in PH.2/3 — PH.16 adds font override, scale, chrome/effects toggles alongside), system font family override + **UI scale factor** (fs-ramp multiplier), **animation master toggle** (off = durations collapse toward instant for perf), shell chrome toggles (brand tick, corner ticks, scrim strength, hairline emphasis), effects toggles (blur/transparency pass-throughs where the toolkit supports them), matugen template browser (moved)
- [ ] **DOCK** — enable/disable, monitor assignment, hide mode (always/dodge/never), size/spacing, click-behavior presets, preview thumbs on/off
- [ ] **PANELS** — per-panel presentation: settings (placement + width — shipped in PH.4.5), picker (mode/width), notifications stack corner, OSD corner, CC anchor/monitor; widths, open direction
- [ ] **LAUNCHER** — anchor position, default mode (grid/list), icon size, pins/recents management (edit + clear)
- [ ] **CONTROL CENTER** — anchor position (center/left/right), monitor, tab visibility + ordering, quick-toggle set selection for HOME
- [ ] **NOTIFICATIONS** — master enable/disable (daemon claim on/off), displayed fields, action buttons on/off, position, default timeout, critical-timeout, per-app overrides editor (block/quiet list)
- [ ] **OSD** — which OSDs active (volume/brightness/mic), corner, size, visible-duration, fade duration
- [ ] **SHELL** — avatar picker (file dialog + OOM-safe thumbnail pipeline — sourceSize mandatory), timezone override (affects clock/calendar formatting), 24h/12h, imperial/metric, weather location (search → lat/lon via open-meteo geocoding), clipboard manager on/off, screenshotter on/off + save directory + filename template
- [ ] **SECURITY** — offline mode (NM radios down + rfkill-style block, confirmation held, obvious restored-state indicator), lock screen enable + monitor selection, idle lock timer (off default), PAM service status row
- [ ] **SYSTEM** — system monitor enable, FAST/SLOW poll interval steppers, warning-threshold steppers (cpu/temp/mem/bat), reset-to-defaults per group
- [ ] **SERVICES** — calendar enable, autostart command editor (ordered list, persisted, spawned after shell start w/ delay), audio overdrive ceiling, brightness backend config (ddcutil device detect/status), night light schedule
- [ ] **POWER** — session-menu tile set + order, hold-to-confirm on/off + duration, lock/sleep/shutdown idle timers (ALL off by default), power-plan display
- [ ] **BAR** — segment framework UI (enable/reorder/zone per PH.14 model), click-action binding matrix, scale + position, taskbar drawer mode + overflow width, per-cell stat toggles, identity text overrides

## Phase 17 — One organism: cohesion, motion & look pass ⬜ NEW

Goal: the audit that keeps the shell feeling like one machined object after a dozen features land. Run it after PH.14–16, then after any future phase.

- [ ] Motion inventory per surface: open/close curve family identical (OutCubic; entrances movSlow via YSurface, indicators movFast/movMed), hover snaps EVERYWHERE (grep for stray Behavior-on-hover), focus indicators consistent
- [ ] Chrome inventory: hairline weight (1 px everywhere), corner ticks, brand notch, registration marks, empty states, loading states (progress = ticking blocks, never spinners-with-color), error states designed not defaulted
- [ ] Keyboard model uniform: ESC closes the topmost surface, TAB cycles forward within it, arrows navigate lists, Enter commits
- [ ] Tooltip language: promote the bar Tooltip into the shared kit and reuse for every hoverable (one style, one offset, one delay)
- [ ] Typography sweep: no text below fsMicro carrying information, no non-token colors, sentence case for body copy, uppercase reserved for chrome
- [ ] Screenshot review board: capture every surface side-by-side against the design-language paragraph at the top of this file; fix anything that reads "different family"
- [ ] Perf budget table per surface (RSS + idle CPU%), recorded in AGENTS.md; regression-test with the standard protocol after each pass

---

## Sequencing

Dependencies dictate order — build the foundation before the faces:

```
PH.04 launcher ──┐
PH.05 notify ────┤
PH.13 datalayer ─┼──► PH.06 conn ∥ PH.07 audio ──► PH.11 utilities ──► PH.14 bar v2 ──► PH.15 ctrl center ──► PH.16 settings v4
                 │                                                                                        │
                 └──► PH.08 session ──► PH.09 dock ──► PH.10 overview                                     ▼
                                                              PH.12 + PH.17 polish/cohesion (continuous)
```

Rationale:

1. **Launcher (4) and notifications (5)** first — daily-use essentials, independent, and DND/history feed everything downstream.
2. **Data layer (13)** before bar v2/control center — they all drink from it; building CC first would force a rewrite.
3. **Connectivity (6) and audio (7)** in parallel — unlock CC tabs and bar chips.
4. **Utilities (11)** next — calendar/weather/clipboard/screenshot are embeddable components the CC and bar click-actions consume.
5. **Bar v2 (14)** once its click-action targets exist, then **control center (15)** assembling those pieces, then **settings v4 (16)** wiring every knob they introduced.
6. **Session/lock (8), dock (9), overview (10)** after the core experience is complete.
7. **Polish (12) + cohesion (17)** continuously; a dedicated 17 pass after 14–16 is mandatory.

**Quick wins (do any time, zero dependencies):**

- [ ] Identity block rename: `{HOSTNAME} // 因果` + `YUTA.SHELL // v{Theme.version}` (spec'd in PH.14)
- [ ] `Theme.version` sync with release tags
