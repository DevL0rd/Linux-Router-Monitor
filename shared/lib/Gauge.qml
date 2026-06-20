/*
 * A thin horizontal bar gauge with a label and value, colour-coded by health.
 * Used for CPU/RAM/% style metrics.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    id: root

    property string label: ""
    property real value: 0          // 0..100
    property string valueText: Math.round(value) + "%"
    property color barColor: Kirigami.Theme.highlightColor

    spacing: 2

    RowLayout {
        Layout.fillWidth: true
        PlasmaComponents.Label {
            text: root.label
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        PlasmaComponents.Label {
            text: root.valueText
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            font.weight: Font.DemiBold
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: Kirigami.Units.smallSpacing
        radius: height / 2
        color: Qt.alpha(Kirigami.Theme.textColor, 0.12)

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.value / 100))
            height: parent.height
            radius: height / 2
            color: root.barColor
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }
    }
}
