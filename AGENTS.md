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
- Hyprland runs the **Helmsman Lua dispatcher**: raw dispatch strings (`workspace 3`) fail; wrapper functions send Lua-form dispatches like `hl.dsp.focus({ workspace = "N" })`.
- Wallpaper engine is **awww** (`awww-daemon`, not swww/hyprpaper). matugen installed.
- No CJK font → `Theme.jpEnabled` false → romaji fallbacks everywhere.
- `~/.local/state/yutashell/` holds all runtime files: state.json, theme.json, matugen.toml. Nothing else writes dotfiles.

## Hard-won lessons (do not regress these)

### 1. NEVER decode full-res images for thumbnails — OOM incident
The settings panel's wallpaper grid decoded every image in `~/Pictures/Wallpapers` (194 files) at full resolution: quickshell hit **7–13 GB RSS**, swap thrashed the system to a freeze, and the kernel OOM-killed the session back to the greeter. Kernel log proof: `Out of memory: Killed process ... (quickshell) anon-rss:6977652kB`.

Rules:
- Any preview/thumbnail `Image` MUST set `sourceSize` (see `WallTile.qml`: 256×160).
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

## Conventions (enforced)

- Colors/fonts/metrics ONLY from `Theme.*`. No hardcoded colors in modules — this is what makes live recoloring free.
- User-facing actions go through IpcHandlers (keybinds + CLI + settings panel share one implementation). IPC surface documented in README "Keybinds & IPC".
- Persistence only through `ShellState.set(key, value)` → state.json.
- Compositor dispatches through wrapper functions (Helmsman Lua form), never inline strings.
- Motion policy: hover/focus snap instantly; positional indicators animate 120–180 ms OutCubic.
- Japanese labels gated behind `Theme.jpEnabled` with romaji fallback.

## Testing protocol

```
timeout 10 quickshell -p . 2>&1 | grep -iE "error|binding loop"   # live-session smoke test
ps -o rss -C quickshell                                            # RSS sanity (~350-400 MB expected)
qs ipc call panel toggle                                           # exercise the panel via IPC
```

Watch RSS after model-heavy panels open. If it climbs into GBs, something is decoding full-res again or leaking delegates.
