# YUTASHELL // ROADMAP

A full desktop shell for Hyprland, built on Quickshell.
Design language: neo-brutalist Japanese cyber-minimalist — flat black surfaces, bone-white ink, one acid accent, hairline structure, registration-mark details, uppercase mono type, sparse Japanese micro-labels. No rounded corners. Motion is either instant or a short eased slide. Every pixel earns its place.

This file is the master checklist. Work top to bottom, check items off as they land. Nothing here is speculative filler — each phase lists the concrete APIs (verified present in this system's Quickshell 0.3.1 install) that will be used.

---

## Conventions (read before building anything)

These rules keep the shell coherent as it grows. Breaking them creates rework later.

- [x] Single source of truth for visuals: everything reads colors/fonts/metrics from the `Theme` singleton (`theme/Theme.qml`, imported as `qs.theme`). No hardcoded colors in modules — this contract is what makes matugen-driven recoloring possible without touching module code.
- [x] Imports use the quickshell scheme: `import qs.theme` for tokens, `import qs.modules.<name>` style relative imports within a module folder, `import "ui"` for a module's private components.
- [x] Module folders are self-contained under `modules/<feature>/` with an entry component named after the feature. Cross-module reuse goes into `modules/common/`.
- [ ] State persistence pattern: JSON config read/written with `Quickshell.Io.FileView` (`watchChanges` to hot-reload, `writeAdapter()` / `setText()` + `save()` to persist). One file: `~/.local/state/yutashell/state.json`. Modules never write their own dotfiles.
- [ ] IPC pattern: every user-facing action is exposed through `Quickshell.Io.IpcHandler` so keybinds, CLI, and the settings panel all drive the same functions instead of duplicating logic.
- [ ] Layer policy: bars/docks use `PanelWindow`; transient UI (launchers, notifications, menus) uses `PanelWindow` with `WlrLayershell.layer: WlrLayer.Overlay` + keyboard focus mode `OnDemand`/`Exclusive`.
- [ ] Animation policy: hover/focus states snap instantly (brutalist). Only positional indicators (active-workspace underline, drawer slides, popup reveals) animate, 120–180 ms, OutCubic.
- [ ] Japanese labels: always gate kanji/kana strings behind `Theme.jpEnabled` with a romaji fallback, so the shell never renders tofu boxes on a font-less machine.
- [ ] Compositor dispatches go through small wrapper functions (e.g. `Workspaces.switchTo(id)`), never raw inline calls — this system's Hyprland runs the Helmsman Lua dispatcher, which requires Lua-form dispatch strings (see README notes).

---

## Phase 0 — Foundations ✅ DONE

The skeleton the rest of the shell grows into.

- [x] Repository structure: `shell.qml` entry, `theme/` singleton module, `modules/bar/`
- [x] `Theme.qml` design-token singleton (palette, fonts, metrics, JP-font detection)
- [x] Verified import scheme works (`qs.theme` + qmldir singleton registration)
- [x] Verified runtime APIs against installed Quickshell 0.3.1 (Hyprland IPC, SystemTray, FileView, Io.Process, event stream shapes)
- [x] Discovered + documented environment quirks (Lua dispatcher, inactive `activeToplevel`, missing CJK font)

## Phase 1 — Taskbar v1 ✅ DONE (polished)

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
- [ ] Per-monitor instances once a second monitor exists (bar currently binds to all screens by default)
- [ ] Optional media segment (MPRIS track ticker) between tray and stats

## Phase 2 — Theme engine & matugen

Goal: wallpaper-driven palettes with user-selectable schemes, applied live across the whole shell by rewriting only token values.

How: matugen generates a palette JSON from the wallpaper; `Theme` loads it at startup and watches it with `FileView { watchChanges: true }` so regenerating a scheme repaints every open surface instantly. All modules already consume only `Theme.*`, so no module code changes — ever.

- [ ] Install matugen (`sudo pacman -S matugen`) and pick wallpaper engine (swww or hyprpaper)
- [ ] matugen config in `~/.config/matugen/`: template that emits `~/.local/state/yutashell/theme.json` mapping material tones → our token names (`bg`, `ink`, `acid`, `alert`, …)
- [ ] `Theme` gains dynamic token properties loaded from `theme.json` with hardcoded fallbacks equal to today's defaults
- [ ] Wallpaper set flow: settings panel / IPC picks image → matugen regenerates → swww transitions → theme.json rewritten → shell recolors
- [ ] Scheme presets: acid (default), plus 2–3 curated alternates (crimson, cyan, amber) stored as static JSONs selectable without a wallpaper
- [ ] Light-mode variant pass (paper background, ink text) gated behind a `Theme.dark` flag
- [ ] Export templates for external apps (Hyprland `colorentry`, foot/kitty, fuzzel) so the whole desktop matches
- [ ] Contrast self-check: assert ink/bg and accent/bg ratios at load, log warnings

## Phase 3 — Settings panel (control core)

Goal: one right-side drawer panel that controls appearance, toggles services/modules, and exposes shell actions — the hub the README calls for.

How: `PanelWindow` anchored right with `WlrLayershell` overlay layer, exclusive on demand. Tabs rendered from a declarative page registry so new modules register settings pages themselves. Persistence via the state.json pattern. Opened by keybind through IPC or clicking the identity block (which is already reserved as its trigger).

- [ ] Drawer scaffold: right-anchored overlay window, slide-in 160 ms OutCubic, dim scrim over desktop, ESC/click-out closes
- [ ] Tab framework: Appearance / Modules / Integrations / About
- [ ] Appearance tab: scheme picker (Phase 2 presets + wallpaper picker grid), accent override swatches, light/dark toggle
- [ ] Modules tab: toggles for each bar segment + future features, stored in state.json, consumed by Bar layout bindings
- [ ] Integrations tab: WiFi/BT quick status + "open full panel" links, notification DND switch, autostart entries editor
- [ ] About tab: version, commit, credits, keybind cheatsheet generated from a single keymap definition file
- [ ] `IpcHandler` exposing `settings toggle/show`, `scheme set <name>`, `panel toggle` etc.
- [ ] Identity block left-click opens the panel (replacing the reserved no-op)

## Phase 4 — App launcher

Goal: fast fuzzy launcher with brutal styling, grid + list modes.

How: enumerate apps via `DesktopEntries` (Quickshell's freedesktop .desktop parser), score with a small custom fuzzy matcher (subsequence + boundary bonuses), render results in an overlay `PanelWindow` with `WlrLayershell.keyboardFocus: KeyboardFocus.Exclusive`. Launch via `Process` on `Exec` keys with `hyprctl dispatch exec` passthrough where needed.

- [ ] Launcher window scaffold: centered overlay, search field auto-focused, instant-open (<16 ms first paint)
- [ ] DesktopEntries listing with icon resolution via `QuicksearchIconImage`/`IconImage` + theme icon paths
- [ ] Fuzzy scoring + ranking, pinned/recents weighting from state.json
- [ ] Grid mode (icon tiles) + list mode (rows), togglable, remembered
- [ ] Enter launches, arrows navigate, tab switches mode, ESC closes
- [ ] Japanese micro-label accents in headers (アプリ / APP)
- [ ] Keybind wired through IPC (`launcher toggle`) added to Helmsman binds
- [ ] Optional: calculator/math expressions and `:` command mode (`:w` → dispatches, etc.)

## Phase 5 — Notification daemon

Goal: fully themed replacement for mako/dunst with history center.

How: implement an on-dbus notification server with `Quickshell.Services.Notifications` (`NotificationServer` type: claim the interface, emit `Notification` objects). Cards are plain QML — urgency maps to border/accent rules from Theme.

- [ ] Claim org.freedesktop.Notifications; actions, icons, images, urgency supported
- [ ] Card design: flat black card, 1px urgency-colored border (normal=hairline, critical=alert), timeout progress as shrinking acid underline
- [ ] Stack manager top-right below bar, max N visible, slide-in/out
- [ ] Inline actions row (buttons styled like workspace blocks)
- [ ] History store (ring buffer in memory + optional state.json dump), browsable panel with clear-all/replay
- [ ] DND toggle (IPC + settings panel + optional bar indicator)
- [ ] Per-app overrides (block/quiet) editable in settings
- [ ] Configurable default timeout, critical persists until dismissed

## Phase 6 — Connectivity suite

Goal: WiFi, Bluetooth, network status — native panels, no nm-applet dependency for UI.

How: `Quickshell.Networking` wraps NetworkManager (devices, wireless networks, connection state); `Quickshell.Bluetooth` wraps BlueZ (adapters, devices, pairing). Both verified present in this install.

- [ ] Bar segment: wifi icon w/ strength tiers, BT icon when adapter powered, click → connectivity panel
- [ ] WiFi panel: network list w/ signal bars, join dialog w/ password field, saved-network connect/disconnect, forget
- [ ] Bluetooth panel: device list w/ battery % where exposed, pair/trust/connect/remove, adapter power toggle
- [ ] Airplane mode master toggle (rfkill via NM/BlueZ states)
- [ ] Ethernet/wired status indicator
- [ ] Connection-change toasts routed through the Phase 5 notification system
- [ ] Settings panel integrations tab reflects all of the above

## Phase 7 — Audio, media & OSDs

Goal: PipeWire volume control, MPRIS media widget, volume/brightness OSDs.

How: `Quickshell.Services.Pipewire` (nodes, streams, default device, volumes as linear→cubic-mapped values), `Quickshell.Services.Mpris` (players, metadata, position). Brightness via sysfs/backlight `FileView` polling or brightnessctl `Process` (ddcutil later for external monitors).

- [ ] Bar audio segment: output device icon + level, click → audio panel, wheel steps volume
- [ ] Audio panel: sinks/sources list, per-device sliders (cubic taper), per-app streams w/ mute, default-device star
- [ ] Input/mic section w/ mute indicator tied to bar icon state
- [ ] MPRIS mini-widget: app icon, scrolling title, play/pause/next/prev; expanded view with seekbar + album art placeholder block (no art = acid square)
- [ ] Volume OSD: horizontal brutal slider overlay appearing on key events, auto-fade
- [ ] Brightness OSD same pattern; internal panel via `/sys/class/backlight/*/brightness` writes, external via ddcutil
- [ ] Media/brightness/volume keybinds registered through IPC actions
- [ ] Mic-mute OSD variant (red slash state)

## Phase 8 — Session, power & lock screen

Goal: secure, themed end-of-session UX.

How: `Quickshell.Services.Pam` for on-lockscreen auth against system PAM (verify a `/etc/pam.d/` service name — usually `hyprlock`'s or create `yutashell`), `Quickshell.Services.Greetd` hooks if/when used as greeter, `Quickshell.Services.Polkit` for a themed privilege agent replacing lxpolkit.

- [ ] Power menu overlay: lock/suspend/hibernate/reboot/poweroff/logout tiles, confirmation hold-to-confirm on destructive ones
- [ ] Lock screen: full-screen overlay layer, clock + date in house style, password field, Pam auth, wrong-attempt shake (instant offset snap), suspend-on-idle hook
- [ ] Idle management: hypridle config shipped alongside, or inhibit-aware custom timer; screen off → lock chain
- [ ] Polkit agent dialog themed like the rest of the shell
- [ ] Session inhibit indicator in bar when apps block sleep/screenshots
- [ ] Logout kills quickshell cleanly (state flushed first)

## Phase 9 — Dock

Goal: bottom dock with pinned + running apps, previews, hide modes.

How: running windows from `Hyprland.toplevels` grouped by class; pin list in state.json; activation/minimize via Lua-form dispatch wrappers. Previews via `grim -t` window captures refreshed on demand (cheap, on hover).

- [ ] Dock scaffold: bottom-centered PanelWindow, exclusive zone option vs overlay float
- [ ] Pinned apps + running-only apps merge view, active-window indicator tick
- [ ] Click: launch/focus/minimize cycle; middle-click new instance; scroll cycles windows of that app
- [ ] Drag reorder pins, drag-to-pin/unpin (custom drag layer)
- [ ] Hover preview cards: window thumbnail (grim capture cached per address) + title, click focuses
- [ ] Intellihide modes: always / dodge windows (list Hyprland client geometry) / never
- [ ] Multi-monitor: dock shows current monitor's windows when per-monitor mode enabled

## Phase 10 — Overview & window management extras

Goal: compositor-level navigation superpowers surfaced in-shell.

How: overview grid renders per-workspace thumbnails (same grim capture pipeline as dock previews) laid out from `Hyprland.workspaces` + client geometry; clicks dispatch focus/move via the Lua wrapper family.

- [ ] Overview overlay: workspace grid w/ thumbnails, labels 01…N, click to jump
- [ ] Drag window thumbnail onto another workspace tile to move it
- [ ] Alt-tab style window switcher overlay (most-recent ordering from Hyprland events), brutal selection frame
- [ ] Scratchpad controller for `special:magic` (matching existing Helmsman bind), with drop-to-scratchpad gesture
- [ ] Floating-layout helpers: quick-tile presets dispatched to Hyprland
- [ ] Optional scrolling- layouts awareness (Helmsman's dwindle/scrolling toggle reflected in UI)

## Phase 11 — Widgets & utilities

Goal: the convenience layer.

- [ ] Calendar popup from clock click: month grid, JP holiday coloring optional, event stub API
- [ ] Weather module: open-meteo fetch via `Process curl`/`FileView` on cache file, geolocation manual setting in state.json, bar temp + panel forecast strip
- [ ] Update counter: `checkupdates` count polled sparsely (pacman-contrib), click → list + terminal launch
- [ ] Clipboard manager UI backed by cliphist (list/paste/delete), bound to a keybind
- [ ] Screenshot suite: region/full/window via grim+slurp wrapped in IPC actions, flash + shutter indicator, save path configurable
- [ ] Screen-recording state chip in bar when wf-recorder runs, click stops it
- [ ] Color picker (hyprpicker) with hex copy toast
- [ ] Emoji/kaomoji picker (fuzzel-style grid, JP-first categories)

## Phase 12 — Polish, performance & distribution

Goal: ship-quality.

- [ ] Animation audit against the motion policy (snap vs eased inventory)
- [ ] Perf pass: no per-frame property churn, `layer-shell` exclusivity correct, idle CPU ≈ 0 when static (profile with `perf`/CPU meter itself)
- [ ] Multi-monitor parity tests (per-monitor bars/dock, focus correctness)
- [ ] Accessibility pass: contrast ratios enforced by Theme loader, font-scale factor token
- [ ] Graceful degradation matrix: no tray apps, no battery, no network, no CJK font — all verified non-crashing (partially done already)
- [ ] Error surface: failed module loads show a minimal in-bar warning chip instead of silence
- [ ] Install script (deps checklist incl. quickshell ≥0.3.1, fonts, matugen, grim, slurp, wl-clipboard, cliphist, brightnessctl)
- [ ] Wiki: screenshots/GIFs per phase, keybind table, theming guide (token reference)
- [ ] Version tags v0.x aligned to completed phases; changelog discipline

---

## Sequencing note

Recommended order after Phase 1 polish: **2 → 3** (theming + settings unlock everything else cleanly), then **4 → 5** (daily-use essentials), then 6–7 in parallel tracks, 8–9 next, 10–11 opportunistically, 12 continuously.
