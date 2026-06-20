import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

Kirigami.FormLayout {
    property alias cfg_pollInterval: pollSpin.value
    property alias cfg_accentColor: accent.text
    property alias cfg_showProtection: protection.checked
    property alias cfg_showOpenUI: openui.checked
    property alias cfg_showChart: chart.checked
    property alias cfg_showTopLists: tops.checked

    RowLayout {
        Kirigami.FormData.label: i18n("Poll interval:")
        QQC2.SpinBox {
            id: pollSpin
            from: 1000; to: 30000; stepSize: 500
            textFromValue: function(v) { return (v / 1000).toFixed(1) + " s" }
            valueFromText: function(t) { return parseFloat(t) * 1000 }
        }
    }
    QQC2.CheckBox { id: protection; Kirigami.FormData.label: i18n("Show:"); text: i18n("Protection toggle") }
    QQC2.CheckBox { id: openui; text: i18n("Open AdGuard UI button") }
    QQC2.CheckBox { id: chart; text: i18n("Queries-per-second chart") }
    QQC2.CheckBox { id: tops; text: i18n("Top blocked domains & clients") }

    Item { Kirigami.FormData.isSection: true }

    RowLayout {
        Kirigami.FormData.label: i18n("Accent colour:")
        QQC2.CheckBox {
            id: useAccent; text: i18n("Custom")
            checked: accent.text !== ""
            onToggled: if (!checked) accent.text = ""
        }
        KQuickControls.ColorButton {
            enabled: useAccent.checked
            color: accent.text !== "" ? accent.text : Kirigami.Theme.highlightColor
            onColorChanged: if (useAccent.checked) accent.text = color
        }
        QQC2.Label { id: accent; visible: false; text: "" }
    }
}
