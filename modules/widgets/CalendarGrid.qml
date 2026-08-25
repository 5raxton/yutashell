import QtQuick
import qs.theme

// CalendarGrid — reusable month grid (PH.11, reworked). The control center's
// CALENDAR tab embeds this exact component, so the calendar looks the same
// everywhere. Set `year`/`month` (0-11) to pick the month; today is a solid
// acid square with a corner notch; adjacent-month days render as clickable
// ghosts (they fire dayPicked AND monthShifted so hosts can follow along).
// `dayPicked(date)` fires on any click.
Item {
    id: root

    property int year: 2026
    property int month: 0

    signal dayPicked(date d)
    signal monthShifted(int delta)

    readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()
    readonly property int daysInPrev: new Date(year, month, 0).getDate()
    // Monday-first layout to match the MO..SU header (Qt getDay(): Sun = 0)
    readonly property int lead: (new Date(year, month, 1).getDay() + 6) % 7
    readonly property int rows: 6

    // re-checked every minute: a grid left open across midnight would
    // otherwise keep marking yesterday forever
    property date today: new Date()
    Timer {
        interval: 60000
        running: root.visible
        repeat: true
        onTriggered: {
            const n = new Date();
            if (n.getDate() !== root.today.getDate() || n.getMonth() !== root.today.getMonth())
                root.today = n;
        }
    }

    readonly property int cellW: Math.floor(width / 7)
    readonly property int cellH: Math.max(30, Math.min(38, Math.round(cellW * 1.05)))

    implicitHeight: headRow.height + Theme.sp1 + cellsGrid.height

    function isToday(d) {
        return year === root.today.getFullYear() && month === root.today.getMonth() && d === root.today.getDate();
    }

    function _buildModel() {
        const out = [];
        for (let i = 0; i < root.lead; i++)
            out.push({
                "d": root.daysInPrev - root.lead + 1 + i,
                "off": -1
            });
        for (let d = 1; d <= root.daysInMonth; d++)
            out.push({
                "d": d,
                "off": 0
            });
        let n = 1;
        while (out.length < root.rows * 7)
            out.push({
                "d": n++,
                "off": 1
            });
        return out;
    }

    // weekday header
    Row {
        id: headRow

        width: parent.width
        height: 18

        Repeater {
            model: Theme.jpEnabled ? ["日", "月", "火", "水", "木", "金", "土"] : ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]

            delegate: Text {
                required property int index
                required property var modelData

                width: root.cellW
                height: headRow.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData
                color: index === 0 ? Theme.alert : index === 6 ? Theme.acidDeep : Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsMicro
                font.weight: Font.Bold
                font.letterSpacing: 1
            }
        }
    }

    // day cells
    Grid {
        id: cellsGrid

        anchors.top: headRow.bottom
        anchors.topMargin: Theme.sp1
        width: parent.width
        columns: 7
        rows: root.rows

        Repeater {
            model: root._buildModel()

            delegate: Rectangle {
                id: cell

                required property int index
                required property var modelData

                readonly property bool inMonth: modelData.off === 0
                readonly property bool today: root.isToday(modelData.d)
                readonly property bool weekend: index % 7 >= 5

                width: root.cellW
                height: root.cellH
                color: cell.today ? Theme.acid : cellArea.containsMouse ? Theme.surface : "transparent"
                radius: 2
                scale: cell.today ? 1.08 : cellArea.containsMouse ? 1.04 : 1.0

                Behavior on scale {
                    NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                }

                // corner notch marks today beyond the fill alone
                Rectangle {
                    visible: cell.today
                    x: 2
                    y: 2
                    width: 5
                    height: 5
                    rotation: 45
                    color: Theme.bg
                }

                Text {
                    anchors.centerIn: parent
                    text: String(cell.modelData.d)
                    color: cell.today ? Theme.bg : !cell.inMonth ? Theme.faint : cell.weekend ? Theme.muted : Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    // ExtraBold marks TODAY only — a bare date match would
                    // embolden the same day number in every viewed month
                    font.weight: cell.today ? Font.ExtraBold : Font.Normal
                    opacity: cell.inMonth ? 1 : 0.45
                }

                MouseArea {
                    id: cellArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const off = cell.modelData.off;
                        root.dayPicked(new Date(root.year, root.month + off, cell.modelData.d));
                        if (off !== 0)
                            root.monthShifted(off);
                    }
                }
            }
        }
    }
}
