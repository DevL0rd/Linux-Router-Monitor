import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

Kirigami.FormLayout {
    property alias cfg_pollInterval: pollSpin.value
    property alias cfg_accentColor: accent.text
    property alias cfg_showCharts: charts.checked
    property alias cfg_showPorts: ports.checked
    property alias cfg_maxMbps: maxSpin.value

    RowLayout {
        Kirigami.FormData.label: i18n("Poll interval:")
        QQC2.SpinBox {
            id: pollSpin
            from: 1000; to: 30000; stepSize: 500
            textFromValue: function(v) { return (v / 1000).toFixed(1) + " s" }
            valueFromText: function(t) { return parseFloat(t) * 1000 }
        }
    }
    RowLayout {
        Kirigami.FormData.label: i18n("Chart scale:")
        QQC2.SpinBox {
            id: maxSpin
            from: 0; to: 10000; stepSize: 50
            textFromValue: function(v) { return v === 0 ? i18n("Auto") : v + " Mb/s" }
            valueFromText: function(t) { return t === i18n("Auto") ? 0 : parseInt(t) }
        }
    }
    QQC2.CheckBox { id: charts; Kirigami.FormData.label: i18n("Graphs:"); text: i18n("Show throughput charts") }
    QQC2.CheckBox { id: ports; text: i18n("Show wired port link speeds") }

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
