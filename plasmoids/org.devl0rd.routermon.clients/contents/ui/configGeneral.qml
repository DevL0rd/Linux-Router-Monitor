import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

Kirigami.FormLayout {
    property alias cfg_pollInterval: pollSpin.value
    property alias cfg_accentColor: accent.text
    property alias cfg_sshUser: sshUser.text
    property string cfg_sortBy: "traffic"

    RowLayout {
        Kirigami.FormData.label: i18n("Poll interval:")
        QQC2.SpinBox {
            id: pollSpin
            from: 1000; to: 30000; stepSize: 500
            textFromValue: function(v) { return (v / 1000).toFixed(1) + " s" }
            valueFromText: function(t) { return parseFloat(t) * 1000 }
        }
    }
    QQC2.ComboBox {
        Kirigami.FormData.label: i18n("Sort by:")
        model: [ { t: i18n("Traffic"), v: "traffic" }, { t: i18n("Name"), v: "name" }, { t: i18n("IP address"), v: "ip" }, { t: i18n("Signal"), v: "signal" } ]
        textRole: "t"; valueRole: "v"
        currentIndex: Math.max(0, indexOfValue(cfg_sortBy))
        onActivated: cfg_sortBy = currentValue
    }
    QQC2.TextField {
        id: sshUser
        Kirigami.FormData.label: i18n("SSH user:")
        placeholderText: i18n("(none — ssh <ip>)")
    }

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
