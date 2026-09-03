pragma Singleton
import Quickshell
import QtQuick

// Health — a minimal error surface (PH.12). Optional-backend modules report
// degradations here when their binary probe fails; the bar shows a subtle
// warning chip while anything is reported, so graceful degradation is never
// silent. `report` dedupes by module; `clear` lifts a module's notice.
Singleton {
    id: root

    property var notices: []   // [{ module, message }]

    readonly property int count: notices.length

    readonly property string summary: notices.map(n => n.message).join("  ·  ")

    function report(module_, message) {
        const m = String(module_);
        const idx = root.notices.findIndex(n => n.module === m);
        if (idx >= 0) {
            if (root.notices[idx].message === message)
                return;
            root.notices = root.notices.map((n, i) => i === idx ? {
                        module: m,
                        message: message
                    } : n);
        } else {
            root.notices = root.notices.concat([{
                        module: m,
                        message: message
                    }]);
        }
    }

    function clear(module_) {
        const m = String(module_);
        if (!root.notices.some(n => n.module === m))
            return;
        root.notices = root.notices.filter(n => n.module !== m);
    }
}
