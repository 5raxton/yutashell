Here are some other well made quickshell configs you can take inspiration from, likw what features they have, how they make them work. etc (you may have to dig in their repos a bit to find the actual quickshell part, but its there).

Noctalia (Quickshell, depricated, but a good one): https://github.com/noctalia-dev/noctalia-qs
Caelestia: https://github.com/caelestia-dots/shell
Ryoku: https://github.com/neur0map/ryoku-arch

Do NOT steal from these. I want ours to still be distinctively our own, but these are examples of fully fledged, fully functional desktop shells, its exmaples of what shells should have, ours SHOULD stand amongst these eventually, not be a knockoff, shitty clone of them.


You are free to update this file with other USEFUL information that will improve the project.

---

# YUTASHELL // ENGINEERING NOTES

Quickshell config for Hyprland. Entry: `shell.qml`. Design tokens in `theme/Theme.qml` (import as `qs.theme`). ROADMAP.md is the master checklist — work top to bottom, keep checkboxes honest.

## Verified environment facts (this machine)

- Quickshell 0.3.1. `Hyprland.activeToplevel` never populates — track focused windows via `activewindow`/`activewindowv2` raw events + one-shot `hyprctl -j activewindow` probe.
- Per-monitor surfaces: `Variants { model: Quickshell.screens; Bar { required property var modelData; screen: modelData } }` — verified working for the bar; instances follow hot-plug. Known limitation: the shared Tooltip window sits on one screen, so tooltips triggered from another monitor's bar can misposition (fine single-monitor; fix when multi-monitor matters).
- `Quickshell.Services.Mpris` verified: `Mpris.players.values`; player has `identity`, `isPlaying`, `trackArtist`/`trackTitle`, `canTogglePlaying`/`togglePlaying()`, `canGoNext/Previous`/`next()`/`previous()`, `volume`+`volumeSupported`. Used by the bar media segment (`modules/bar/MediaBlock.qml`).
- `DesktopEntries` singleton verified: `applications.values` (filter `noDisplay`), `byId(id)`, `heuristicLookup(name)`. `DesktopEntry` has `id/name/genericName/startupClass/noDisplay/comment/icon/execString/command/workingDirectory/runInTerminal/categories/keywords` + **`execute()`** (launches properly — no manual Exec parsing) and **`actions`** (`QList<DesktopAction*>`, each with `id/name/icon` + `execute()`). Used by the launcher (`modules/launcher/`).
- Light mode is **generated, not stored**: `Theme._toLight()` HSL-remaps any token map (preset or wallpaper palette) to paper/ink; `_fitOnLight()` darkens acid/alert against the live bg until they pass the same ratios the contrast self-check asserts (3.0 / 2.5). Zero warnings across full preset cycles in light mode = acceptance signal.
- Hyprland runs the **Helmsman Lua dispatcher**: raw dispatch strings (`workspace 3`) fail; wrapper functions send Lua-form dispatches like `hl.dsp.focus({ workspace = "N" })`.
- Wallpaper engine is **awww** (`awww-daemon`, not swww/hyprpaper). matugen installed.
- No CJK font → `Theme.jpEnabled` false → romaji fallbacks everywhere.
- `~/.local/state/yutashell/` holds all runtime files: state.json, theme.json, matugen.toml. Nothing else writes dotfiles.
- Deps present: grim, slurp, wl-copy, cliphist, nvidia-smi (RTX 5080 — GPU stats via batched `nvidia-smi --query-gpu=...`), gpu-screen-recorder 6.x. Absent: cava, hyprsunset, ddcutil (**no `/sys/class/backlight` — desktop box**), powerprofilesctl, hyprpicker. Features needing absent deps must hide gracefully (ROADMAP tracks which phase gates each).

## Hard-won lessons (do not regress these)

### 1. NEVER decode full-res images for thumbnails — OOM incident
The settings panel's wallpaper grid decoded every image in `~/Pictures/Wallpapers` (194 files) at full resolution: quickshell hit **7–13 GB RSS**, swap thrashed the system to a freeze, and the kernel OOM-killed the session back to the greeter. Kernel log proof: `Out of memory: Killed process ... (quickshell) anon-rss:6977652kB`.

Rules:
- Any preview/thumbnail `Image` MUST set `sourceSize` (see `modules/picker/ui/PickerTile.qml`: 256×160).
- Gate `source` on visibility (`root.visible ? url : ""`) so off-screen delegates never decode.
- Remember: components inside always-instantiated singletons/panels run at startup even when "closed" — a Repeater there creates ALL delegates immediately once its model populates.

After fix: same panel + 194 tiles = ~365 MB RSS total shell footprint.

### 2. awww-daemon socket race
A fixed `sleep 0.4` after spawning the daemon raced daemon startup and dropped paints silently. Pattern that works (Wallpaper.qml): spawn detached via `setsid`, then retry `awww img` up to 8× with 0.25 s gaps.

### 3. Quickshell FileView semantics (confirmed working)
- `JsonAdapter` + `writeAdapter()` persists structured prefs (ShellState pattern).
- `setText()` on a plain FileView stages AND writes (genConfigFile writes matugen.toml this way).
- `watchChanges: true` + reload-on-callback = live theme recolor without touching module code.

### 4. QML gotchas hit so far
- Binding to a JS function call (`readonly property var x: Singleton.fn()`) DOES re-evaluate when properties read inside fn change — used for the template list, but it recreates every delegate on any persist. Fine for small lists; don't use for big ones.
- Offscreen platform (`QT_QPA_PLATFORM=offscreen`) cannot create PanelWindows — validation must run against the live Wayland session with `timeout`.
- **Flickable/GridView/ListView reparent declared children into `contentItem`** — anything declared inside scrolls away with the content. Scroll indicators, edge fades, overlays MUST be siblings positioned over the scroll area, not children of it. (Bit us in both picker grid and settings pages.)
- Binding `Flickable.contentHeight` to `loader.item.childrenRect.height` is a binding loop; use `loader.item.height` (Column/implicitHeight) instead.
- A `Loader` per tab (lazy pages) keeps heavy lists from building at startup and stops scroll offsets leaking between tabs.
- **Declare `required property var modelData` exactly ONCE.** Having it both in the delegate component's root (TemplateRow.qml) and again in the inline delegate wrapper produces `Cannot create delegate / Required property modelData was not initialized` for every row — silently, at runtime only.
- Host items whose default property aliases children elsewhere (YRow's `trailingHost`) must NEVER size themselves from `childrenRect` while children anchor to them — instant binding loop. Give the host an explicit consumer-set width (`YRow.trailingW`).
- **`IconImage` needs `implicitSize`, not width/height** — it wraps an inner Image and only sizes via `implicitSize`; width/height alone renders blank. `status` is aliased, so `status === Image.Error || Image.Null` drives the acid-initials fallback for apps with no theme icon. Missing icons still WARN in the log (`Cannot open: qrc:/.../<app-id>`) — that noise is expected fallback behavior, not a bug.
- Quickshell single-window components (no explicit `screen`) map on the primary monitor; a second instance's bars get exclusive-zone-pushed to y=44 under the first instance's bar — don't misread stacked test-instance layers as a bug.

### 4b. Surface architecture (layer sandwich + YSurface)
- **Bar → `WlrLayershell.layer: WlrLayer.Overlay`** (topmost); ALL popup windows (settings/picker/launcher) → `WlrLayer.Top`. Anything sliding from negative-y emerges from behind the bar — this is the shell's signature entrance.
- **No scrims anywhere by default**: popups are fullscreen transparent PanelWindows; input is confined to the card via `mask: Region { item: open ? <cardItem> : null }`. Desktop around the card stays visible AND clickable. Closing is ESC / keybind / IPC only.
- **YSurface kit component owns the choreography** (`modules/common/ui/YSurface.qml`): restY = barHeight + outerPad + 6, hiddenY = −height−12, enter movSlow(260)/exit movMed OutCubic + movFast fade, bgAlt card + lineStrong border + acid corner tick + swallow MouseArea. Every new floating surface composes YSurface instead of re-animating by hand.
- **FastWheel** (`modules/common/ui/FastWheel.qml`) is the standard wheel handler for every Flickable/GridView/ListView — drop-in child, notchStep 132, clamped. Plain Flickables scroll too slowly without it.

### 5. Quickshell FileView drops overlapping operations
Back-to-back `writeAdapter()` / `setText()` / `reload()` calls within a few hundred ms overlap internally and get **silently dropped** (warning: `got operation finished from dropped operation`). Symptoms seen: IPC bursts losing writes, template toggles never landing. Fixes shipped:
- `ShellState.set()` coalesces through an 80 ms flush Timer; `Wallpaper.writeGenConfig()` same with 100 ms.
- Startup seeding only writes adapter when the state file is absent AND empty — a transient read race must never clobber user prefs with defaults.
- When scripting e2e tests, keep ≥0.5 s between mutating IPC calls even with coalescing.

### 6. matugen 4.x + TOML config generation
- matugen **hard-fails without a TTY** when several source colors are candidates ("Multiple source colors found..."). Always pass `--source-color-index 0` when invoking non-interactively.
- TOML **literal strings (`'…'`) do not support `''` escaping** — that's basic-string syntax only; `'a '' b'` fails to parse. Generate values as multiline literals `'''…'''` instead (no escape processing, tolerates quotes/newlines; just never emit a literal `'''`).
- Post-hooks with embedded quotes (gsettings, sudoers) only parse via the above.

### 7. Test harness
- Background quickshell between bash-tool calls needs `setsid nohup … < /dev/null & disown`; plain nohup gets reaped when the tool session ends (looks like a mysterious crash — it isn't). The spawn command may still hold the tool session's pipe open past its timeout even with redirects — outputs arrive anyway; run spawns in their own short-timeout call.
- `console.log` from QML does NOT reliably reach nohup-captured stderr — stream logs with `qs -p <path> log > file &` and read that file.
- Bare `qs ipc call …` fails when the instance was launched with an explicit `-p` path — always pass the same `-p`.
- Template ids are catalog ids (`kitty`, not `kitty.conf`).
- **`qs ipc` without `--pid`/`--id` targets exactly ONE instance per config path (the first found — usually the user's live shell), it does NOT broadcast.** Discovered when a spawned test instance never reacted to path-targeted calls while the live instance did all the work. To drive a specific instance: `qs ipc --pid <pid> call <target> <fn>` (or `-i <id-substring>`). Consequence: mutating verification calls via bare `-p` targeting DO hit the user's live session — note their prefs from logs first and restore after, or target the test PID directly.
- **NEVER `pkill -f "quickshell -p <path>"`** — that pattern matches the user's live instance too (it runs the same `-p`). Record the test instance's PID at spawn time (`$!` from the setsid call) and kill that exact PID. This actually bit once: a pattern-kill took down the live session's shell mid-test; it was restarted manually.
- Editing QML while an instance runs triggers hot-reload mid-edit-sequence: saving a caller before its callee produces transient `ReferenceError`s in the running shell's log. Don't chase those in log captures — they're edit-order artifacts, not code bugs. Verify against a freshly spawned instance instead.

## Conventions (enforced)

- Colors/fonts/metrics ONLY from `Theme.*`. No hardcoded colors in modules — this is what makes live recoloring free.
- **UI primitives ONLY from the kit** (`modules/common/ui`): YButton / YSwitch / YRow / YSection / YField / YChip / YScroll. Never hand-roll a button, row, switch, or section header inside a panel — compose the kit. This is what makes both panels feel like one object.
- Type ramp from Theme only: `fsDisplay > fsTitle > fsBody > fsLabel > fsMicro`. Body copy is **sentence case** at fsBody; UPPERCASE + wide tracking is reserved for micro-chrome (nav rail, chips, section labels). If text at fsMicro carries information the user needs, it's at the wrong size.
- Acid is semantic: active state, focus, primary CTA, status ticks. Never decoration.
- Motion: hover/focus snap instantly; positional indicators animate `Theme.movFast`/`movMed` OutCubic. YButton's hard-shadow press collapse is the one allowed "physical" flourish.
- Scroll indicators are SIBLINGS over their Flickable via `YScroll { target }` — never children (contentItem reparenting).
- User-facing actions go through IpcHandlers (keybinds + CLI + settings panel share one implementation). IPC surface documented in README "Keybinds & IPC".
- Persistence only through `ShellState.set(key, value)` → state.json.
- Compositor dispatches through wrapper functions (Helmsman Lua form), never inline strings.
- Japanese labels gated behind `Theme.jpEnabled` with romaji fallback.

## Testing protocol

```
timeout 10 quickshell -p . 2>&1 | grep -iE "error|binding loop"   # live-session smoke test
ps -o rss -C quickshell                                            # RSS sanity (~350-400 MB expected)
qs ipc call panel toggle                                           # exercise the panel via IPC
```

Watch RSS after model-heavy panels open. If it climbs into GBs, something is decoding full-res again or leaking delegates.
