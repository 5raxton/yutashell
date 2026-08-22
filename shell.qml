import Quickshell
import qs.theme
import "modules/bar"
import "modules/bar/ui"

ShellRoot {
    Tooltip {
        id: tooltip
    }

    Bar {
        tip: tooltip
    }
}
