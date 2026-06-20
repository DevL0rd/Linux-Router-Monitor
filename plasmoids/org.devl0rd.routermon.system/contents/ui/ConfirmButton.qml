/*
 * A button that requires a second tap within a few seconds to fire, used for
 * destructive router actions (reboot, restart WiFi). No modal dialogs needed.
 */
import QtQuick
import QtQuick.Controls as QQC2

QQC2.Button {
    id: btn

    property string baseIcon: ""
    property string baseText: ""
    property string confirmText: i18n("Tap again to confirm")
    property bool confirming: false
    signal confirmed()

    text: confirming ? confirmText : baseText
    icon.name: confirming ? "dialog-warning" : baseIcon

    onClicked: {
        if (confirming) {
            confirming = false
            resetTimer.stop()
            confirmed()
        } else {
            confirming = true
            resetTimer.restart()
        }
    }

    Timer { id: resetTimer; interval: 4000; onTriggered: btn.confirming = false }
}
