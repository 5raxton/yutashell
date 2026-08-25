# Configuration

Day-to-day configuration happens in the settings panel (`qs ipc call panel toggle`) — 15 pages behind a searchable nav rail. Nothing needs hand-editing. Everything below is what the panel manages under the hood.

## State files

All user preferences persist to `~/.local/state/yutashell/`:

| file | purpose |
|---|---|
| `state.json` | every pref: scheme, wallpaper, bar segments, launcher pins/recents, notification rules, session/idle config, dock layout, plugin data, per-panel spawn origins |
| `geo.json` | cached IP-geolocation fix (lat/lon/city/timezone) for auto location |
| `weather.json` | last open-meteo payload (boot-time conditions before first refresh) |
| `theme.json` | current matugen-generated palette (watched; edits hot-reload) |
| `matugen.toml` | generated matugen config assembled from the enabled templates |

## Theming contract

Modules read colors exclusively from the `Theme` singleton — no hardcoded values anywhere in module code. That's what makes live recoloring free: changing scheme, applying a wallpaper, toggling light mode or setting an accent only rewrites token values, and every open surface repaints in place.

- 12 preset schemes: `acid`, `crimson`, `cyan`, `amber`, `catppuccin`, `cyberpunk`, `doom`, `gruvbox`, `mono`, `tokyonight`, `kanagawa`, `dracula`
- **Wallpaper palettes** — matugen derives a palette from the current wallpaper; `qs ipc call scheme wallpaper` re-follows it after a manual override
- **Light mode** — generated at runtime from any palette with WCAG contrast fitting
- **Accent override** — any hex can take the accent slot: `qs ipc call theme accent "#c8ff3d"`
- Japanese micro-labels fall back to romaji automatically when no CJK font is installed

Baseline tokens of the `acid` scheme: bg `#0a0a0c`, ink `#eae8e0`, acid `#c8ff3d`, alert `#ff3b52`.

## App templates

The theming pipeline also recolors external apps through [matugen](https://github.com/InioX/matugen) templates (89 vendored across 10 groups: terminals, editors, shells, browsers, launchers, notifications, compositor, desktop, media, system). For include-style configs the shell writes and strips its own managed block inside the target app's config, so toggling a template is zero-friction and fully reversible.

Manage via Settings → APPEARANCE → Matugen templates, or:

```sh
qs ipc -c yuta-qs call templates list
qs ipc -c yuta-qs call templates on alacritty
```

Custom templates are two paths away — see the settings page for the format.
