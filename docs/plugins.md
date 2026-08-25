# Plugins

Drop a folder under `plugins/<your-plugin>/` with a `plugin.json` manifest and a QML entry component. Plugins can import the shell's own kit (`qs.theme`, `qs.modules.common.ui`).

## Manifest

```json
{
    "id": "my-plugin",
    "name": "My Plugin",
    "version": "1.0.0",
    "type": "widget",
    "component": "main.qml"
}
```

Optional fields: `description`, `author`, `icon`, `settings[]`, `permissions[]`.

## Types

### `widget`

A `Rectangle`-rooted QML component rendered inside the bar's PLUGIN WIDGETS segment. Keep it bar-height; the shell sizes the segment around natural content width.

```qml
import QtQuick
import qs.theme

Rectangle {
    implicitWidth: label.implicitWidth + 24
    implicitHeight: Theme.barH - 12
    radius: 2
    color: Theme.bg

    Text {
        id: label
        anchors.centerIn: parent
        text: "hello"
        color: Theme.acid
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsLabel
    }
}
```

### `daemon`

Instantiated invisibly at boot while enabled — timers, file watchers, IPC bridges, anything headless.

## Settings array

An optional `settings[]` in the manifest describes per-plugin options surfaced in Settings → PLUGINS:

```json
"settings": [
    { "key": "announce", "label": "Announce changes to stderr", "type": "bool", "default": true }
]
```

Read the current value from QML through the namespaced data store (the settings UI writes there):

```qml
readonly property bool announce: PluginService.loadPluginData(pluginId, "announce", true)
```

## State persistence

Widgets and daemons persist state across restarts through the same store:

```qml
Component.onCompleted: counter = PluginService.loadPluginData(pluginId, "count", 0)
onCounterChanged: PluginService.savePluginData(pluginId, "count", counter)
```

## Lifecycle

```sh
qs ipc -c yuta-qs call plugins list      # scan state as text
qs ipc -c yuta-qs call plugins rescan
qs ipc -c yuta-qs call plugins enable my-plugin
qs ipc -c yuta-qs call plugins disable my-plugin
```

Or via Settings → PLUGINS (live toggle, no restart needed).

## Reference implementations

- [`plugins/PulseDot/`](../plugins/PulseDot) — widget: pulsing dot keyed to audio output
- [`plugins/WallpaperWatcherDaemon/`](../plugins/WallpaperWatcherDaemon) — daemon: reacts to wallpaper changes

> Plugins execute with full shell privileges — only install ones you trust.
