import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

Kirigami.FormLayout {
    id: page

    property alias cfg_pollInterval: pollSpin.value
    property alias cfg_accentColor: accent.text
    property alias cfg_showCharts: charts.checked
    property alias cfg_showPerCore: perCore.checked
    property alias cfg_showTemps: temps.checked
    property alias cfg_showReboot: reboot.checked
    property alias cfg_showRestartWifi: restartWifi.checked
    property alias cfg_showWebUI: webui.checked

    RowLayout {
        Kirigami.FormData.label: i18n("Poll interval:")
        QQC2.SpinBox {
            id: pollSpin
            from: 1000; to: 30000; stepSize: 500
            textFromValue: function(v) { return (v / 1000).toFixed(1) + " s" }
            valueFromText: function(t) { return parseFloat(t) * 1000 }
        }
    }

    QQC2.CheckBox {
        id: charts
        Kirigami.FormData.label: i18n("Graphs:")
        text: i18n("Show history charts")
    }
    QQC2.CheckBox {
        id: perCore
        text: i18n("Show per-core CPU usage")
    }
    QQC2.CheckBox {
        id: temps
        text: i18n("Show temperatures")
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.CheckBox { id: reboot; Kirigami.FormData.label: i18n("Actions:"); text: i18n("Reboot router") }
    QQC2.CheckBox { id: restartWifi; text: i18n("Restart WiFi") }
    QQC2.CheckBox { id: webui; text: i18n("Open router web UI") }

    Item { Kirigami.FormData.isSection: true }

    RowLayout {
        Kirigami.FormData.label: i18n("Accent colour:")
        QQC2.CheckBox {
            id: useAccent
            text: i18n("Custom")
            checked: accent.text !== ""
            onToggled: if (!checked) accent.text = ""
        }
        KQuickControls.ColorButton {
            id: accentPicker
            enabled: useAccent.checked
            color: accent.text !== "" ? accent.text : Kirigami.Theme.highlightColor
            onColorChanged: if (useAccent.checked) accent.text = color
        }
        // hidden text store bound to the config value
        QQC2.Label { id: accent; visible: false; text: "" }
    }
}
