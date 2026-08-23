import QtQuick
import qs.theme

// CalendarGrid — reusable month grid (PH.11). The control center's CALENDAR
// tab embeds this exact component, so the calendar looks the same everywhere.
// Set `year`/`month` (0-11) to pick the month; today is boxed in acid; days
// outside the month render as faint ghosts. `dayPicked(date)` fires on click.
Item {
    id: root

    property int year: 2026
    property int month: 0

    signal dayPicked(date d)

    readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()
    readonly property int firstWeekday: new Date(year, month, 1).getDay() // 0 = Sun
    readonly property date today: new Date()

    readonly property int cellW: Math.floor(width / 7)
    readonly property int cellH: 26

    implicitHeight: headRow.height + cellsGrid.height

    function isToday(d) {
        return d > 0 && year === root.today.getFullYear() && month === root.today.getMonth() && d === root.today.getDate();
    }

    // weekday header
    Row {
        id: headRow

        width: parent.width
        height: 16

        Repeater {
            model: Theme.jpEnabled ? ["日", "月", "火", "水", "木", "金", "土"] : ["S", "M", "T", "W", "T", "F", "S"]

            delegate: Text {
                required property int index
                required property var modelData

                width: root.cellW
                height: headRow.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData
                color: index === 0 ? Theme.alert : Theme.faint
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
        width: parent.width
        columns: 7
        rows: 6

        Repeater {
            model: {
                const out = [];
                for (let i = 0; i < root.firstWeekday; i++)
                    out.push(0);
                for (let d = 1; d <= root.daysInMonth; d++)
                    out.push(d);
                while (out.length % 7 !== 0)
                    out.push(0);
                return out;
            }

            delegate: Rectangle {
                id: cell

                required property int index
                required property int modelData

                readonly property bool inMonth: modelData > 0
                readonly property bool today: root.isToday(modelData)

                width: root.cellW
                height: root.cellH
                color: cell.today ? Theme.acid : cellArea.containsMouse && cell.inMonth ? Theme.surface : "transparent"
                border.width: cell.today ? 1 : 0
                border.color: Theme.acid

                Text {
                    anchors.centerIn: parent
                    text: cell.inMonth ? String(cell.modelData) : "·"
                    color: cell.today ? Theme.bg : cell.inMonth ? (cellArea.containsMouse ? Theme.ink : Theme.ink) : Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    font.weight: cell.today || (cell.modelData === root.today.getDate() && cell.inMonth) ? Font.ExtraBold : Font.Normal
                }

                MouseArea {
                    id: cellArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: cell.inMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (cell.inMonth)
                            root.dayPicked(new Date(root.year, root.month, cell.modelData));
                    }
                }
            }
        }
    }
}
