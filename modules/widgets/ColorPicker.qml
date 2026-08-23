pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common
import qs.modules.notify

// Color picker (PH.11) over hyprpicker. The binary is ABSENT on this machine,
// so `available` is false and every consumer hides; `pick()` degrades to a
// toast rather than a dead button. When installed, pick() runs hyprpicker,
// copies the hex and toasts it.
Singleton {
    id: root

    readonly property bool available: _probed && _binOk
    property bool _binOk: false
    property bool _probed: false

    property string lastColor: ""

    function pick() {
        if (!root.available) {
            Notify.announce("COLOR PICKER", "install hyprpicker to enable", 1);
            return;
        }
        pickProc.command = ["sh", "-c", "c=$(hyprpicker -a); [ -n \"$c\" ] && printf '%s' \"$c\" | wl-copy && echo \"$c\""];
        pickProc.running = true;
    }

    Component.onCompleted: {
        binProbe.command = ["sh", "-c", "command -v hyprpicker >/dev/null 2>&1 && echo yes || echo no"];
        binProbe.running = true;
    }

    Process {
        id: binProbe

        stdout: StdioCollector {
            onStreamFinished: {
                root._probed = true;
                root._binOk = text.trim() === "yes";
                if (!root._binOk)
                    Health.report("hyprpicker", "color picker unavailable (install hyprpicker)");
                else
                    Health.clear("hyprpicker");
            }
        }
    }

    Process {
        id: pickProc

        stdout: StdioCollector {
            onStreamFinished: {
                const c = text.trim();
                if (c.length > 0) {
                    root.lastColor = c;
                    Notify.announce("COLOR", c + " copied to selection", 1);
                }
            }
        }
        stderr: StdioCollector {}
    }
}
