import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

Kirigami.FormLayout {
    property alias cfg_accentColor: accent.text
    property alias cfg_planDownMbps: planSpin.value

    QQC2.SpinBox {
        id: planSpin
        Kirigami.FormData.label: i18n("Plan download speed:")
        from: 0; to: 10000; stepSize: 50
        textFromValue: function(v) { return v === 0 ? i18n("Off") : v + " Mb/s" }
        valueFromText: function(t) { return t === i18n("Off") ? 0 : parseInt(t) }
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
