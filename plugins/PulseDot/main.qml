import QtQuick
import qs.theme
import qs.modules.common
import qs.modules.common.ui

// Reference widget plugin (PH.05): a YPulse acid dot sized like a bar chip.
// The bar hosts it via a Loader when the "pluginwidgets" segment is on and
// this plugin is enabled.
Item {
    id: dot

    property string pluginId: ""

    implicitWidth: 14
    implicitHeight: Theme.scaledBarHeight

    YPulse {
        anchors.centerIn: parent
        width: 6
        height: 6
        color: Theme.acid
    }
}
