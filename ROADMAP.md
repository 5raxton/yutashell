# YUTASHELL // ROADMAP

A full desktop shell for Hyprland, built on Quickshell 0.3.1.
Design language: neo-brutalist Japanese cyber-minimalist — flat black surfaces, bone-white ink, one acid accent, hairline structure, registration-mark details, uppercase mono type, sparse Japanese micro-labels. No rounded corners. Motion is either instant or a short eased slide. Every pixel earns its place.

**The one-organism rule:** every surface — bar, launcher, control center, OSD, clipboard, screenshot chrome, lock screen — must read as the *same* object viewed from different angles. Same kit primitives, same hairline weight, same corner-tick motifs, same motion curves, same type ramp. If a new panel could be mistaken for another project's popup, it is wrong and gets rebuilt. We are not shipping a bag of tools; we are shipping one machine.

## STYLE — "techy, neo-brutalist, paper on ink minimalist." (binding for ALL future phases)

The shell is a living machine, a living organism, in an art exhibit, not just a toolbox. Everything below is LAW; new phases inherit it automatically and reviewers reject work that ignores it.

**1. Everything breathes.** Idle chrome has a pulse: the bar's acid strip breathes (`YPulse`, `movDrift`), clock colons swell instead of strobe, BT glyphs hunt while scanning, equalizer bars sway while music plays. Pulses run SLOW (`movDrift` 2600 ms class) and NEVER apply to text content — text is data, data doesn't throb.

**2. Arrival ritual + exit ceremony.** Every YSurface card drops from behind the bar with a soft OutBack overshoot into its flush socket, an acid scanline sweeps down the face, the border burns acid then cools to lineStrong, the power line draws left→right along the bottom edge, the family tick draws down the left edge, and content cascades in as staggered rising rows (`YSurface.cascade` + `reveal()`; YSection rules draw themselves via their `reveal()` hook). On close it all runs backwards — scanline returns up as the card lifts away. Consumers do NOTHING by hand: compose YSurface, set `cascade`, done.

**3. Mechanical easings only.** `movSnap`/`movFast`/`movMed` OutCubic for everything positional, plus exactly ONE allowed overshoot per gesture (OutBack 0.12–0.45): switch knobs, chip label pops, card landing. No bounces, no springs, no elastic — machines click into place.

**4. Acid is the living tissue.** It pulses, draws, sweeps, blinks, and underlines — but ONLY for semantics: active state, focus, progress, live activity, primary CTA. If acid appears without meaning, delete it. Alert red follows the same discipline for danger.

**5. Hover = interrogation.** Pointing at anything makes it answer instantly (snap inversions, hover fills wiping in from the left, status ticks growing to full height, sub-labels crossfading to detail notes). Nothing waits on a timer to respond to the cursor except tooltips (which rise out of the bar line).

**6. Data is alive.** Numbers that change should visibly react: net arrows flash acid past 2 KB/s, chips pop when counts tick, meters animate. Dead-static readouts are bugs.

**7. Chrome sleeps when unwatched.** Scroll rails fade away after idle (thumb dims to a whisper), toast stacks vanish entirely when empty, hidden modules collapse to zero width. The resting desktop shows only what is true right now.

**8. One current.** The power line, family ticks, registration marks, flare shoulders, hard-shadow button press — every surface carries the same motifs because they are literally the same kit components (`modules/common/ui`). New UI MUST compose kit primitives; hand-rolled buttons/rows/switches/sections are rejected in review.

Perf guardrails that keep the organism cheap: animations pause when `!visible`; transforms (Translate/Scale) instead of layout-affecting properties where possible; staggered reveals destroy their dynamic objects when done; pulses are opacity-only. RSS budget stays ~250–500 MB (measured ~455 MB with every surface warm).

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

All required + optional backends are now installed on this machine (verified 0.7.0):

| present | what it feeds |
|---|---|
| `matugen`, `awww` | theme pipeline (live recolor) |
| `grim`, `slurp`, `wl-copy`, `cliphist` | screenshot suite + clipboard |
| `nvidia-smi`, `gpu-screen-recorder` 6.x | GPU stats + recording chip |
| `cava` | media visualizer colors (template ships; ascii feed deferred) |
| `ddcutil` | external-monitor brightness (DDC/CI) |
| `hyprsunset` | night light |
| `powerprofilesctl` (power-profiles-daemon) | power plans |
| `hyprpicker` | color picker |
| `checkupdates` (pacman-contrib) | update counter |
| `curl` | weather fetch |

No absent deps remain — every widget backend is live. Features still keep their graceful-degradation paths as insurance (never crash on a missing binary).

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
- [x] Layer policy (the signature sandwich): the bar sits on `WlrLayer.Overlay` (topmost); every popup lands on `WlrLayer.Top` so it slides out from BEHIND the bar; the OSD + Polkit + lock overlay use `Overlay`. `keyboardFocus` is `Exclusive` while open, `None` closed.
- [x] Animation policy: hover/focus snap instantly (brutalist). Only positional indicators animate — 120–180 ms OutCubic (`Theme.movFast`/`movMed`); surface entrances use `Theme.movSlow` 260 via YSurface. YButton's hard-shadow press collapse is the one physical flourish.
- [x] Japanese labels: kanji/kana always gated behind `Theme.jpEnabled` with a romaji fallback, so nothing ever renders tofu.
- [x] Compositor dispatches go through small wrapper functions (e.g. `Workspaces.switchTo(id)` sending `hl.dsp.focus({ workspace = "N" })`), never inline strings.
- [x] **One poller per datum:** periodic sampling (/proc, hwmon, nvidia-smi) lives ONLY in the PH.13 `SystemStats` singleton. Bar, control center, thresholds and future widgets consume it — no module spins up a second Timer over the same file.
- [x] **Optional-dep graceful degradation:** any feature backed by an absent CLI hides itself or renders a flat fallback. Never crash, never show a dead button.
- [x] **Live identity tokens:** hostname and version render from probed sources (`/proc/sys/kernel/hostname`, `Theme.version`) — never hardcoded strings.
- [x] **Panels are read-mostly:** popups (control center, OSD, calendar) expose glanceable state + quick actions only. All deep configuration belongs to the settings panel. If a popup starts growing steppers and path pickers, move them.
- [x] **Kit-only composition:** every new surface composes from `modules/common/ui` (YButton/YSwitch/YRow/YSection/YField/YChip/YSlider/YSurface/YPulse/YClickAway/YSpark) plus Theme tokens. Hand-rolled buttons/rows inside a feature are a bug.

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
- [x] **Hotfix — Hyprland borders actually themed**: the `hyprland-lua` template now writes `colors.lua` as a palette table that ALSO calls `hl.config` at require time (boot, via Helmsman), and a catalog post hook re-applies `general:col.active/inactive_border`, `group:col.border_active/inactive` + groupbar text colors through `hyprctl eval 'hl.config({…})'` after every matugen run (live). Verified 0.56.2: `rgba()` = RRGGBBAA, bare `0xAARRGGBB` accepted; nothing consumed colors.lua before this fix, which is why hyprland looked unthemed while every other template worked.

## Phase 3 — Settings panel (control core) ✅ DONE

Current state: right-side drawer/popout built entirely from the shared kit. Originally 5 tabs (Appearance / Templates / Modules / System-stub / About) off a declarative page registry — width stepper (400–760 px), popout-card mode, persisted. IPC `panel toggle/open/close`. **Superseded by the PH.16 v4 rebuild** (grouped nav rail + 14 tabs + global search); this phase closed the "control core".

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

## Phase 4.6 — Feedback pass ✅ DONE

Second user-directed pass on the same surfaces — fixes where 4.5 fell short, plus a real template engine.

- [x] **Launcher**: compact card (max 46% of screen width/height, never fullscreen feel); caret vertically centered in the search field (was baseline-stuck); type ramp bumped globally for readability (`fsDisplay` 20 / `fsTitle` 14 / `fsBody` 12 / `fsLabel` 10 / `fsMicro` 8); **real app icons** via `Quickshell.iconPath()` with acid-initials fallback
- [x] **Picker → ARCHIVE rewrite**: carousel deck deleted (`pickerMode` gone from state). Now: numbered index spine left (pure type, always-focused filter field driving nav), huge framed preview stage right with corner ticks + caption + APPLY; keyboard-first (type/arrows/enter/esc)
- [x] **Settings scroll root-caused**: `contentHeight` binding latched onto dying Loader items during tab switches and went permanently stale — replaced with imperative sync + retargeted Connections on the live page item
- [x] **Flush-to-bar**: YSurface `restGap` defaults to 0 (cards rest against the bar, no floating gap)
- [x] **Flare shoulders**: concave fillet curves sweep outward from card top into the bar line (`Shape`+`ShapePath`, bgAlt fill) so popups read as growing out of the bar
- [x] **YRow switch fix**: row-level MouseArea was covering trailing slots — every embedded switch in every panel had been silently unclickable
- [x] **Template engine**: startup binary probe maps catalog ids → installed apps; absent apps show ABSENT chips, refuse to enable, and get auto-pruned from stale enabled state; toggles now actually flip state
- [x] **Auto-snippet injection**: toggling an include-style template writes the include line itself into the app's config inside managed `# >>> yutashell-matugen` blocks (kitty/tmux/fuzzel/rofi/wofi/mako/swaync/hyprland/hyprlock/css apps); alacritty gets TOML-aware import-array merging instead (duplicate keys are invalid TOML); disabling strips everything back out

Verification notes: E2E via IPC on a test instance — alacritty ON merges `colors.toml` into the import array (or appends a managed `[general]` block when none exists), OFF restores the file byte-exact; kitty refused while absent; launcher binding loop (`results` ↔ `clampSel`) removed. Fresh-instance smoke clean.

## Phase 4.7 — Polish pass ✅ DONE

Final pre-Phase-5 pass: sizing honesty, mutual exclusion, and a signature entrance.

- [x] **Fullscreen-card bug root-caused**: anchored `Loader`s stretch their loaded root item regardless of explicit size — launcher and picker cards were silently rendering fullscreen. Fixed with filler Items inside both cardComponents (settings never used a Loader, which is why it always looked right)
- [x] **Launcher** = small center box (640×460, clamped by `launcherW` and screen); **picker** = slightly larger rectangle (1000×600); verified via QML-side geometry probes
- [x] **Flare shoulders rebuilt symmetric by construction**: one FlareShape geometry mirrored for the far side — no more left-side bulge
- [x] **Exclusive popups**: opening any of panel/launcher/picker closes the others (`ShellState._exclusive`)
- [x] **House entrance ritual** in YSurface, free for every surface: drop from behind the bar with slight OutBack socket landing, acid scanline sweep down the face, border burns acid then cools to hairline, family tick draws down the left edge
- [x] Launcher boot TypeError fixed — this Qt build's JS engine lacks `String.trimStart`; replaced with regex lstrip

Verification notes: fresh instance boots zero errors/warnings; geometry probed at 640×460@(960,44) and 1000×600@(780,44); layer list shows exactly ONE popup surface under any open/close spam. Note: the user's wallpaper is animated — screenshot pixel-diffs are useless for shell verification here (~2M px churn between arbitrary frames); verify via QML logging.

## Phase 4.8 — "The machine is alive" aesthetic overhaul ✅ DONE

Pre-Phase-7 organism pass. Codified the VIBE CHARTER (top of this file) and wired the life into every layer. The shell should now read as one breathing machine.

- [x] **Motion tokens extended**: `Theme.movSnap` (80 ms, chrome snaps) + `movDrift` (2600 ms, life runs slow). Machine fast, organism slow.
- [x] **YPulse kit primitive** (`modules/common/ui/YPulse.qml`): opacity-only breathing loop for idle chrome. Applied to the bar's 132 px acid strip — the bar itself has a pulse.
- [x] **YSurface exit ceremony**: closing reverses the arrival — scanline sweeps back up as the card lifts away (~190 ms window kept alive by panels' hideDelay). Every surface got it free.
- [x] **YSurface power line**: permanent 2 px acid line along every card's bottom edge; draws left→right on open, retracts on close. All cards wired to the same current.
- [x] **Content cascade**: `YSurface.cascade` + `reveal()` stagger children rising in (26 ms/row, Translate-based, transforms destroyed after landing). Wired into settings pages (re-runs per tab switch via `onItemChanged`), network + bluetooth + notification center bodies. YSection rules draw themselves during cascade via a `reveal()` hook (Scale-x from left). Launcher/picker deliberately skip content cascade — transient tools open ready-to-type; they still carry the full card ritual.
- [x] **Kit interrogation language**: YSwitch track-fill wipe + OutBack knob snap (overshoot 0.45); YButton acid underline draws on hover for default tone; YRow hover wipe + status tick grows to full height + sub/note crossfade; YField focus underline draws in (brackets with its left tick); YChip pops on label change; YScroll rails sleep after 700 ms idle (thumb dims to 0.35).
- [x] **Bar life**: media equalizer — three acid bars sway at offset periods while playing, settle flat when paused; stats net arrows + values flash acid past 2 KB/s and cool back; BT glyph hunts (InOutSine blink) while discovering; clock colon breathes instead of strobing.
- [x] **Toasts**: entrance staggers 70 ms/card; exit send-off — `Notify.retire()` flags `leaving`, card slides up + fades over 240 ms, hard close fires after the 280 ms queue flush. All exit paths (timeout, × button, action invoke, clear-all) route through retire; overflow eviction stays hard-close (cards were never visible).
- [x] **Tooltip rises** out of the bar line (6 px translate + movSnap fade).
- [x] **Dead code / UX fixes**: ToastCard dead `entry` alias removed; NotificationCenter REPLAY no longer hides the history row (visible=false hack); center timestamps honor `fields.time`; Bar divider chain refactored into named `seg*` predicates.

Verification notes: fresh instance boots clean (only the known benign theme.json atomic-write race warning); all six surfaces cycled open/close via IPC with zero errors; YUTA_DEBUG_CYCLE tab walk clean through cascading pages; toast self-expiry + manual dismiss clean through the retire path (no close-race errors); RSS ~252–260 MB across all checks.

## Phase 5 — Notification daemon ✅ DONE

Goal: fully themed replacement for mako/dunst with history center. DND lives here and is consumed by the bar (PH.14) and control center HOME (PH.15).

How: implement an on-dbus notification server with `Quickshell.Services.Notifications` (`NotificationServer`: claim the interface, emit `Notification` objects). Cards are plain QML — urgency maps to border/accent rules from Theme.

- [x] Claim org.freedesktop.Notifications; actions, icons, images, urgency supported
- [x] Card design: flat black card, 1px urgency-colored border (normal=hairline, critical=alert), timeout progress as shrinking acid underline
- [x] Stack manager below bar (corner configurable), max N visible, slide-in/out, hover pauses timeouts
- [x] Inline actions row (buttons styled like workspace blocks; global "show action buttons" toggle for PH.16)
- [x] History store (ring buffer + optional state.json dump), browsable notification center with clear-all/replay — reused by CC notifications tab (PH.15)
- [x] DND toggle: IPC (`dnd toggle/on/off`) + bar indicator + CC quick toggle; suppressed-notifications counter chip while active
- [x] Per-app overrides (block/quiet) editable in settings (PH.16 notifications tab)
- [x] Configurable default timeout; critical persists until dismissed
- [x] Display-fields toggles (app name / body / icon / timestamp) feeding PH.16

Verification notes: E2E against a fresh instance owning the bus — `notify-send` normal/critical/low all recorded with correct urgency; actions captured and replayable; DND suppressed normals (counter chip) while criticals broke through and persisted until `clear`; per-app QUIET rule silenced matching sends; timeout self-expiry clean (zero close-race errors after the 300 ms margin + dead-flag fixes). Settings → NOTIFY tab builds under YUTA_DEBUG_CYCLE. Bar indicator lands with PH.14 (CC quick toggle with PH.15); both consume `Notify.dnd`/`suppressedCount`.

## Phase 6 — Connectivity suite ✅ DONE

Goal: WiFi, Bluetooth, VPN/DNS status — native panels, no nm-applet dependency for UI. Feeds the CC network/bluetooth tabs (PH.15) and bar segments (PH.14).

How: `Quickshell.Networking` wraps NetworkManager; `Quickshell.Bluetooth` wraps BlueZ. Both verified present in this install.

- [x] Bar segments: wifi icon w/ signal tiers (click → network panel via PH.14 action binding), BT icon when adapter powered
- [x] WiFi panel: network list w/ signal bars, join dialog w/ password field, saved-network connect/disconnect/forget
- [x] Bluetooth panel: device list w/ battery % where exposed, pair/trust/connect/remove, adapter power toggle, **per-device autoconnect flags** (BlueZ trust = autoconnect; NM-level per-device autoconnect arrives with CC if ever needed)
- [x] VPN: list active VPN connections, connect/disconnect toggle (nmcli-backed — NetworkManager's own CLI; wg0-mullvad shows up alongside native VPN types)
- [x] DNS view + quick-set (current resolvers shown; override applies ipv4.dns to the active managed profile, REVERT restores DHCP)
- [x] Airplane mode master toggle (wifi + BT radios down together via Networking.wifiEnabled / adapter.enabled) — also surfaced in PH.16 security tab later

Verification notes: live machine has wired primary + soft-blocked wlan0 + active wg0-mullvad — panel reflects exactly that (WIRED chip, radio-off state, VPN row UP). Panels open/close via IPC exclusively with every other popup; zero errors across open/close cycles; RSS ~256 MB.
- [x] Ethernet/wired status indicator (bar NET chip shows wired bars; the panel's Wired section shows link speed + address)
- [x] Connection-change toasts routed through the PH.05 notification system (`NetWatch` singleton)
- [x] Shared connectivity data model — `Connectivity` is the one source for bar segments, panels and CC tabs (no duplicate scans)

## Phase 7 — Audio, media, displays & OSDs ✅ DONE

Goal: PipeWire volume control, MPRIS media widget, volume/brightness/mic OSDs, night light. Feeds CC media/audio/monitors tabs (PH.15).

How: `Quickshell.Services.Pipewire` (nodes, streams, default device, linear→cubic mapped volumes), `Quickshell.Services.Mpris` (players, metadata, position). Brightness: **this box has no `/sys/class/backlight`** — external monitors go through `ddcutil` (now installed; detected at runtime per-output).

> Landed as the `modules/audio` module: AudioService (Pipewire), DisplayService (ddcutil), NightLight (hyprsunset). Settings grew an AUDIO tab (master vol, overdrive ceiling, OSD corner/fade, night-light temp, brightness) — later redistributed across OSD/SERVICES in PH.16. Bar segment: icon + level bars + mic slash, wheel = volume ±5, click = audio panel, middle-click = mute. IPC: `audio status/volup/voldown/mute/micmute/nl/nltemp`, `display bright`. Verified live: volume/mute/status/panel/OSD; night light + DDC brightness now both functional (hyprsunset + ddcutil installed).

- [x] Bar audio segment: output device icon + level, wheel steps volume, click → audio panel (PH.14 action binding)
- [x] Audio panel: sinks/sources list, per-device sliders (cubic taper), per-app streams w/ mute, default-device star
- [x] Input/mic section w/ mute indicator tied to bar icon state
- [x] **Audio overdrive**: allow output volume beyond 100 % up to a configurable ceiling (default 130 %, clamp token in ShellState) — flagged visually past 100 %
- [x] MPRIS mini-widget: expands the Phase 1 media ticker into a full widget — app icon, seekbar + album art placeholder block (no art = acid square)
- [x] Volume OSD: horizontal brutal slider appearing on key events, auto-fade; mic-mute variant (red slash)
- [x] Brightness OSD same pattern; per-output writes via `ddcutil` batched queries (cache current values; ddcutil is slow — never call synchronously on hover)
- [x] Night light service: `hyprsunset` wrapper (spawn/detach, temperature slider 1000–6500 K, schedule optional — schedule NOT built), exposed as CC quick toggle + bar chip when active (dep: install hyprsunset; hide gracefully if absent — verified absent-dep path)
- [x] Media/brightness/volume keybinds registered through IPC actions (and/or `Hyprland._GlobalShortcuts`)
- [x] OSD placement/behavior knobs (corner, size, fade ms) persisted for PH.16 OSD tab

## Phase 8 — Session, power & lock screen ✅ DONE

Goal: secure, themed end-of-session UX + power-plan control.

How: `Quickshell.Services.Pam` for lockscreen auth (`system-auth`), `Quickshell.Services.UPower`'s `PowerProfiles` singleton for plans (DBus-activates power-profiles-daemon, probed at boot via `busctl introspect`), `Quickshell.Services.Polkit` for a themed privilege agent.

- [x] Power menu overlay: lock/suspend/hibernate/reboot/poweroff/logout tiles, hold-to-confirm on destructive ones (hold duration configurable, can be disabled)
- [x] Tile set + order persisted (`sessionTiles` JSON pref)
- [x] Lock screen: full-screen overlay on selected monitor(s), clock + date in house style, password field, Pam auth, wrong-attempt shake (instant offset snap), suspend-on-idle hook, user avatar (`~/.face` or `lockAvatar` pref — PH.16 shell tab provides the asset)
- [x] Lock screen monitor selection: primary / all / explicit list (`lockMonitors` pref)
- [x] Idle management: inhibit-aware timer using `IdleMonitor` (`respectInhibitors: true`); optional lock / sleep / shutdown — OFF by default (`idleAction: none`), configured in PH.16 power tab
- [x] Power plans: read/set via `PowerProfiles` (saver/balanced/performance), exposed in the power menu chip + IPC; bar chip + CC tab land in PH.15/16
- [x] Polkit agent dialog themed like the rest of the shell
- [x] Session inhibit indicator in bar when apps block sleep (`loginctl` poll, 20 s)
- [x] Logout kills quickshell cleanly (state flushed via `ShellState.flushNow()` first)

## Phase 9 — Dock ✅ CORE DONE

Goal: bottom dock with pinned + running apps, previews, hide modes. Distinct from the bar taskbar (PH.14): dock is a separate, optional, macOS-style surface.

How: running windows from `Hyprland.toplevels` grouped by class; pin list in state.json; activation/minimize via Lua dispatch wrappers. Previews via native `_Screencopy` if practical, else `grim` captures cached per address (refreshed on hover only).

- [x] Dock scaffold: bottom-centered PanelWindow, exclusive-zone option vs overlay float (`dockMode`), centered via full-width window + input mask
- [x] Pinned + running merge view, active-window indicator tick (`Dock.apps` model in `modules/dock/Dock.qml`)
- [x] Click: launch/focus/minimize cycle (minimize = send to `special:magic`); middle-click new instance; scroll cycles windows of that app; right-click context menu (pin/unpin/close)
- [ ] Drag reorder pins, drag-to-pin/unpin (custom drag layer — deferred, low value without previews)
- [~] Hover preview cards: title card live; **window thumbnail deferred** (`grim` capture on hover needs per-window geometry + latency tuning — revisit with PH.10's capture pipeline)
- [x] Intellihide modes: always / dodge windows / never (`dockHide`)
- [x] Multi-monitor: one dock per screen via `Variants`; monitor scope knob persisted (`dockMonitors`: all|primary)
- [x] Enable/disable master switch — OFF-by-default-optional (`dockEnabled`), ON in PH.16 dock tab

## Phase 10 — Overview & window management extras ✅ CORE DONE

Goal: compositor-level navigation superpowers surfaced in-shell.

How: overview grid renders per-workspace tiles (window lists — live thumbnails of hidden workspaces are impossible without compositor cooperation) laid out from `Hyprland.workspaces`; clicks dispatch focus/move via the Lua wrapper family.

- [x] Overview overlay: workspace grid, labels 01…N, click to jump (`OverviewGrid.qml`)
- [ ] Drag window thumbnail onto another workspace tile to move it (deferred — needs the drag layer + thumbnails)
- [x] Alt-tab style window switcher overlay — most-recent ordering tracked from `activewindow` events, brutal acid selection frame (`AltTab.qml`)
- [x] Scratchpad controller for `special:magic` (matching existing Helmsman bind) + send-focused-window-to-scratchpad (IPC `overview scratchpad` / `scratchsend`)
- [x] Floating-layout helpers: quick-tile presets dispatched to Hyprland (`overview tile float|fullscreen|pseudo|center|left|right|top|bottom`)
- [ ] Scrolling-layout awareness (Helmsman's dwindle/scrolling toggle — deferred: per-workspace scrolling layout isn't readable from QML; still togglable via SUPER+A)

## Phase 10.5 — Click-away, settings expansion & bug sweep ✅ DONE

Cross-cutting cohesion pass: every floating surface now closes on outside-click, the settings panel grew two real tabs, and a handful of live bugs were swept.

- [x] **Click-outside-to-close** everywhere: new `YClickAway` kit primitive (fullscreen transparent click-catcher) wired into all eleven popups — settings, picker, launcher, notification center, network, bluetooth, audio, media, power menu, overview grid, alt-tab. Each panel's `mask` now targets the fullscreen catcher while open (the card's own swallow area keeps in-card clicks from reaching it). Polkit + lock screen intentionally stay modal.
- [x] **Settings → DOCK tab**: enable/disable, reserve-edge vs overlay, auto-hide (never/dodge/always), per-monitor scope — previously IPC-only, now in the panel.
- [x] **Settings → SYSTEM tab** replaced the stub: power plan (cycle saver/balanced/performance), idle action + timeout, hold-to-confirm toggle + duration, lock-screen monitor scope, bar inhibit-indicator toggle, lock avatar path. No more "planned" placeholder rows.
- [x] **Bug fixes**: `LockScreen` null-`screen` TypeError (guard before dereferencing `screen.name`); `YField` Keys handlers now declare `event` (killed the deprecation warnings); `Theme` no longer calls `applyWallpaperTokens()` synchronously after an async `reload()` (killed the spurious "theme.json unreadable" warning on every load); the `ansi-sequences` template post hook is fish-safe (`sh -c` wrapper — it previously hard-failed under the fish `$SHELL`).
- [x] **Identity block rename** (PH.14 quick win): `{HOSTNAME} // 因果` + `YUTA.SHELL // v{version}`; `Theme.version` bumped to 0.4.0.

Verification notes: fresh load is clean (only benign FileView-coalescing + missing-icon fallback warnings remain); all 8 settings tabs build; every panel composes the click-away behind its YSurface. The live shell on this machine runs as `qs -c yuta-qs` and hot-reloads edits — note that `quickshell -p . log` attaches to that instance's buffered log rather than spawning a clean one, so transient mid-edit reload failures must not be read as current-state errors.

## Phase 11 — Widgets, utilities & capture suite ✅ DONE

Goal: the convenience layer. Each widget is a standalone module (`modules/widgets/`) that later surfaces get embedded into (CC tabs reuse calendar/weather; bar click-actions reuse everything).

- [x] Calendar popup from clock click: month grid, today boxed in acid, month/year nav, JP weekday glyphs (gated). **Shared component** — `CalendarGrid.qml` so the CC calendar tab embeds the same view. No event API yet (future)
- [x] Weather module: open-meteo fetch via `Process curl` → cache `~/.local/state/yutashell/weather.json`, manual location in state.json (lat/lon + label), 30-min refresh, units follow `weatherUnit`. Conditions hero + 5-day strip in `WeatherPanel.qml` + the CC WEATHER tab
- [x] Update counter: `checkupdates` polled sparsely (6 h + manual `updates check`), `updates list` + `updates open` (terminal launch)
- [x] **Clipboard manager popup** (cliphist): search-as-you-type, monospace previews, click/enter re-copies via wl-copy + toast, DEL deletes, right-click pins to top (state.json), WIPE all, graceful empty + absent states. Themed like the launcher
- [x] **Screenshot suite** (grim + slurp + wl-copy): IPC `shot region|full|window` —
  - [x] slurp styled with the live acid accent (`-b` fill, `-c` border, mono font label)
  - [x] flash frame + shutter tick (`ShotFlash.qml` — 1px border pulse, instant)
  - [~] after-shot action: shot saves to the configurable dir + toasts the path; `shot copy` re-copies. A full save/copy/annotate/discard action bar is deferred (no annotator installed)
  - [x] save dir + strftime filename template persisted (`~/Pictures/Shots/%Y%m%d-%H%M%S.png`)
  - [~] preview toast is a text toast (path); thumbnail-with-click-to-open deferred to the PH.11 capture pipeline revisit
  - [x] window mode: focused-window geometry via `hyprctl -j activewindow` at=box
- [x] Screen-recording chip in bar when `gpu-screen-recorder` runs, click stops it (SIGINT); process probed every 5 s
- [x] Color picker (`hyprpicker`) with hex copy toast — binary now installed, picks a screen color and copies it (`ColorPicker.qml`); still degrades to a toast if absent
- [x] Emoji/kaomoji picker: JP-first categories (faces / kaomoji / symbols / hearts), click copies + dismisses (`Emoji.qml`)

## Phase 12 — Polish, performance & distribution ◐ CONTINUOUS

Goal: ship-quality. Items here get revisited after every big phase lands.

- [x] Animation audit against the motion policy (snap vs eased inventory per surface) — reviewed; hover snaps, positional OutCubic, entrances movSlow via YSurface; no stray Behavior-on-hover found
- [x] Perf pass: no per-frame property churn — SystemStats runs two coarse Timers (2 s / 5 s), pulses are opacity-only and gate on `visible`; idle CPU ≈ 0. RSS ~440 MB with the panel open
- [~] Multi-monitor parity tests (per-monitor bars/dock, focus correctness) — bars/dock already per-screen via `Variants`; full parity re-test deferred to a multi-monitor machine
- [~] Accessibility pass: contrast ratios enforced by Theme loader (done); font-scale factor token feeds PH.16
- [x] Graceful degradation matrix: no battery, no CJK font, no cava/cliphist/ddcutil/hyprsunset/hyprpicker — every surface hides or degrades to a flat message, verified non-crashing
- [x] Error surface: `Health` singleton + in-bar warning chip — optional-backend absences report a notice and the bar shows a `!` chip with a tooltip instead of failing silently
- [x] Install script: `install.sh` deps checklist (required + optional) with `--install` / `--link`
- [~] Wiki: README showcase + keybind table + theming contract; per-phase GIFs deferred
- [x] Version tags: `Theme.version` bumped to 0.5.0 (single source, rendered by the identity block)

## Phase 13 — Unified system data layer ✅ DONE

Goal: ONE sampling engine feeding bar, control center, thresholds, and future widgets. Kills the pattern where StatsCluster privately polls /proc and every future surface would copy it.

How: new singleton `modules/common/SystemStats.qml`. Owns all Timers/FileViews/process probes. Consumers bind to properties; nothing else touches /proc.

- [x] `SystemStats` singleton: CPU % (per-core + aggregate), memory %/used/total, network rates, disk IO rates (`/proc/diskstats` deltas), load avg, uptime
- [x] Temps from `/sys/class/hwmon`: coretemp (CPU package), nvme ×2, RAM (`spd5118`), chipset (`acpitz`) — auto-discovered by name, not hardcoded index
- [x] GPU stats via batched `nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,power.draw --format=csv,noheader,nounits` on the SLOW class (5 s)
- [x] Battery: migrated the sysfs BAT1→BAT0 fallback into SystemStats (absent on this desktop — reported honestly)
- [x] Two poll classes: FAST (cpu/mem/net/load/uptime, 2 s) and SLOW (temps/gpu/disk/battery, 5 s)
- [x] Threshold signals: `warnRaised(kind)`/`critRaised(kind)` for cpu/temp/gpu/mem/bat with configurable limits (cpu warn 85 crit 95, temp warn 80 crit 90, mem warn 90, bat warn 20 crit 10) — the bar CPU/mem cells already tint alert past thresholds
- [x] Units/locale formatter functions: `fmtRate`, `fmtBytes`, `fmtTime` (12h/24h from `clock24h`), `fmtTemp` — consumed by the bar, weather, and future CC
- [x] Hostname probe: `/proc/sys/kernel/hostname` via FileView → `SystemStats.hostname`
- [x] Migrated `StatsCluster.qml` to consume SystemStats — deleted its private FileViews/Timer
- [~] Consumer-count awareness: SLOW-class polling could idle down when unwatched (perf guard) — deferred, keep simple for now

## Phase 14 — Bar v2: taskbar, extra stats & full customization ✅ DONE

Goal: turn the bar from a fixed layout into a configurable organism. Taskbar with real interactions, new stat segments, reorderable/toggleable segments, and per-segment click-actions.

### Identity block (shipped — see PH.10.5)

- [x] Line 1: `{HOSTNAME} // 因果` — hostname probed from env; 因果 gated behind `Theme.jpEnabled`, romaji `INGA` fallback
- [x] Line 2: `YUTA.SHELL // v{Theme.version}` (replaces `SYS.BAR // v…`); blinking cursor block + hover inversion kept
- [x] Bump `Theme.version` to match actual release numbering (0.6.0 at PH.14-16, 0.7.0 at PH.17)

### Taskbar segment (new)

- [x] Running windows grouped by app class from `Hyprland.toplevels.values`; merged with pinned-apps list (reuses `Dock.apps` — bar and dock stay in sync)
- [x] App identity: desktop-entry icon via `IconImage`, acid initial fallback, acid underline on the focused app, running-but-unfocused = hollow tick
- [x] Left-click launch/focus/minimize-cycle · middle-click new instance · right-click pin/unpin · scroll cycles windows · hover tooltip
- [~] Drawer mode (off/overflow-only/always) — deferred; taskbar is capped at 10 apps
- [~] Per-monitor filtering — deferred to a multi-monitor machine

### Extra stat segments (new — all fed by SystemStats)

- [x] `CPU.TEMP` (coretemp package °C), `GPU` (usage % + °C combined cell), `DISK.IO` — each individually toggleable, alert-colored past thresholds (`StatCell.qml`)
- [x] Existing NET/CPU/MEM/BAT cells already refactored onto SystemStats (PH.13)

### Segment framework (the customization core)

- [x] Declarative segment model persisted in state.json: ordered `[{id, zone, enabled}]` (17 segments) resolved by the `BarSegments` singleton
- [x] BAR settings tab renders the model: toggles, L/C/R zone chips, up/down reorder
- [x] Bar scale (0.8–1.4×) + top/bottom position, persisted; content Y-scales via `Scale { yScale }`
- [x] **Click-action bindings** (`BarSegments.clickFor` → `BarActions.dispatch`): calendar/network/bluetooth/audio/power/notifications/controlcenter/launcher/settings/none + `ipc:<target>/<fn>`; defaults ship
- [x] The bar renders left/center/right zones from the model via `Repeater` + `Loader`, with auto-dividers

## Phase 15 — Control center ✅ DONE

Goal: one themed popup falling from the bar that answers "what's going on / quick toggle / quick adjust". Read-mostly; deep config stays in settings.

- [x] Scaffold: YSurface card + click-away, configurable anchor (center/left/right), tab strip with sliding acid underline, lazy Loaders, IPC `cc toggle/open/close`
- [x] **HOME** — quick-toggle grid (wifi / bluetooth / night light / DND) + now-playing + weather + power-plan glance rows
- [x] **MEDIA** — MPRIS player card (art block, title/artist, transport, seekbar source) · [~] cava visualizer is a static hairline baseline (cava ascii parsing deferred)
- [x] **AUDIO** — output/input device rows (default star) with cubic sliders, per-app streams (mute)
- [x] **MONITORS** — ddcutil brightness slider (hides when absent) · [~] scale select deferred to a full display-config surface
- [x] **SYSTEM** — sparkline strips from SystemStats (CPU/GPU/MEM/NET) sampling only while open + sensor list
- [x] **POWER** — power-plan segmented switch, battery detail, link to the session menu
- [x] **NETWORK** — wifi on/off, top networks by signal, VPN toggles, wired status
- [x] **BLUETOOTH** — adapter toggle, scan, devices with connect/disconnect
- [x] **WEATHER** — conditions hero + 5-day strip (embeds the PH.11 module)
- [x] **CALENDAR** — embeds the PH.11 `CalendarGrid` verbatim
- [x] **NOTIFICATIONS** — history list, replay/dismiss, clear-all, DND switch
- [x] Tab set/order configurable via `ShellState.ccTabs` (CONTROL CENTER settings tab)

## Phase 16 — Settings panel v4: full customization suite ✅ DONE

Goal: the settings panel grows into the shell's constitution — every knob, findable in seconds.

- [x] **Two-level nav rail**: groups LOOK / BEHAVIOR / SYSTEM containing 14 tabs; sliding acid tick on the active row
- [x] **Global search**: header field filters the rail by label/JP/keywords; enter jumps to the first match
- [~] Page registry per-module registration — still a declarative registry in SettingsPanel (true per-module registration deferred)
- [x] Pages stay lazy Loaders; search indexes metadata only

The fourteen tabs (Migration map honored: templates → Appearance; bar toggles → BAR; About kept):

- [x] **APPEARANCE** — scheme swatches, follow-wallpaper, light/dark + accent override, control-core placement/width, matugen template browser (moved in)
- [x] **DOCK** — enable/mode/hide/monitors
- [x] **PANELS** — settings placement, notification corner, CC anchor
- [x] **LAUNCHER** — view mode, placement, width, pins/recents clear
- [x] **CONTROL CENTER** — anchor + per-tab visibility
- [x] **NOTIFICATIONS** — DND, action buttons, corner, timeouts, card fields, per-app overrides
- [x] **OSD** — corner, width, fade
- [x] **BAR** — segment toggles + zone + reorder, scale, position
- [x] **SHELL** — 24h/12h, weather location, screenshot dir
- [x] **SECURITY** — offline (airplane) mode, lock monitor scope, bar inhibit indicator
- [x] **SYSTEM** — SystemStats monitor (uptime, GPU, sensors) + power plan + idle/hold/lock
- [x] **SERVICES** — audio overdrive ceiling, monitor brightness, night light
- [x] **POWER** — power plan, idle action+timeout, hold-to-confirm, battery
- [x] **ABOUT** — version, state, IPC cheatsheet

Deferred (thin today): timezone override + imperial/metric units, avatar file-dialog picker, autostart command editor, critical-notification timeout, drag-reorder (up/down arrows ship instead), UI scale factor + animation master toggle (Theme token).

## Phase 17 — One organism: cohesion, motion & look pass ✅ DONE

Goal: the audit that keeps the shell feeling like one machined object after a dozen features land. Run it after PH.14–16, then after any future phase.

- [x] Motion inventory: open/close curves identical across surfaces (OutCubic; entrances movSlow via YSurface, indicators movFast/movMed, hover snaps everywhere) — no stray Behavior-on-hover found
- [x] Chrome inventory: 1 px hairlines, corner ticks, brand notch, registration marks, empty states (search "NO MATCH", clipboard "EMPTY", weather "NO LOCATION", CC "NOTHING PLAYING") — designed, not defaulted
- [x] Keyboard model: ESC closes the topmost surface, TAB cycles settings tabs / advances alt-tab, arrows navigate lists, Enter commits
- [~] Tooltip language: bar Tooltip promoted to the shared kit + reused for every hoverable — deferred (the bar tooltip remains bar-only; a shared tooltip risks mispositioning across monitors)
- [x] Typography sweep: no info below fsMicro, no non-token colors, sentence case body, uppercase chrome
- [~] Screenshot review board — deferred (the wallpaper is animated; pixel-diffs are useless here, see AGENTS.md)
- [x] Perf budget: RSS ~455 MB across all checks; idle CPU ≈ 0 (SystemStats polls at 2 s / 5 s; pulses are opacity-only)

Also shipped this pass: **fixed the settings nav-rail click bug** (the rail was wrapped in a Flickable whose gesture handling swallowed the row clicks — replaced with a plain Column + `findIndex`-by-id click handler; TAB still cycles), plus a HOME glance card in the control center (wallpaper thumb + ticking clock + weather line + avatar).

Version: 0.7.0.

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

- [x] Identity block rename: `{HOSTNAME} // 因果` + `YUTA.SHELL // v{Theme.version}` (shipped in PH.10.5)
- [x] `Theme.version` sync with release tags (0.4.0 at PH.10.5)
