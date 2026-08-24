import QtQuick
import qs.modules.common

// Reference daemon plugin (PH.05): watches Wallpaper.current and persists a
// change counter + the last applied path through pluginService storage.
Item {
    id: watcher

    property string pluginId: ""

    readonly property bool announce: PluginService.loadPluginData(pluginId, "announce", true)

    Component.onCompleted: {
        changes = PluginService.loadPluginData(pluginId, "changes", 0);
        console.warn("[wallpaper-watcher] up — watching, known changes:", changes);
    }

    property int changes: 0

    Connections {
        target: Wallpaper

        function onCurrentChanged() {
            watcher.changes = watcher.changes + 1;
            PluginService.savePluginData(watcher.pluginId, "changes", watcher.changes);
            PluginService.savePluginData(watcher.pluginId, "lastWallpaper", Wallpaper.current);
            if (watcher.announce)
                console.warn("[wallpaper-watcher] change #" + watcher.changes + " → " + Wallpaper.current);
        }
    }
}
