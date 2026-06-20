/*
 * Linux-Router-Monitor :: Speed Test widget
 * Manual, click-to-run internet speed test with an arc-gauge readout.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import "lib"

PlasmoidItem {
    id: root

    property bool running: false
    readonly property var result: {
        var s = Plasmoid.configuration.lastResult
        if (!s) return null
        try { return JSON.parse(s) } catch (e) { return null }
    }
    readonly property color accent: Plasmoid.configuration.accentColor !== ""
        ? Plasmoid.configuration.accentColor : Kirigami.Theme.highlightColor
    readonly property color upColor: Kirigami.Theme.neutralTextColor
    readonly property int plan: Plasmoid.configuration.planDownMbps
    readonly property real gaugeMax: plan > 0 ? plan : 1000

    Plasmoid.title: i18n("Router · Speed Test")
    Plasmoid.icon: "network-card"
    toolTipMainText: i18n("Internet Speed Test")
    toolTipSubText: result ? i18n("↓ %1  ↑ %2 Mb/s", result.down_mbps, result.up_mbps)
                           : i18n("Click to run a test")
    preferredRepresentation: fullRepresentation

    property var live: null
    readonly property real liveMbps: live ? (live.mbps || 0) : 0
    readonly property string livePhase: live ? (live.phase || "") : ""
    function phaseText(p) {
        return p === "upload" ? i18n("↑ Upload") : p === "ping" ? i18n("Ping…") : i18n("↓ Download")
    }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: function(source, d) {
            var s = (d.stdout || "").trim()
            if (s) Plasmoid.configuration.lastResult = s
            root.running = false
            root.live = null
            disconnectSource(source)
        }
    }
    // poll the live progress file while a test is running
    P5Support.DataSource {
        id: liveSrc
        engine: "executable"
        onNewData: function(source, d) {
            try { root.live = JSON.parse(d.stdout) } catch (e) {}
            disconnectSource(source)
        }
    }
    Timer {
        interval: 350; repeat: true; running: root.running
        onTriggered: liveSrc.connectSource("cat \"$XDG_RUNTIME_DIR/Linux-Router-Monitor/speedtest_live.json\" 2>/dev/null")
    }
    function runTest() {
        if (root.running) return
        root.live = null
        root.running = true
        runner.connectSource("$HOME/.local/bin/routermon-speedtest")
    }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 13
        Layout.minimumHeight: Kirigami.Units.gridUnit * 15
        implicitWidth: Kirigami.Units.gridUnit * 16
        implicitHeight: Kirigami.Units.gridUnit * 20

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            // header
            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon { source: "network-card"; Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium; Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium }
                PlasmaComponents.Label { text: i18n("Speed Test"); font.weight: Font.Bold; Layout.fillWidth: true }
                PlasmaComponents.Label { text: root.result ? root.result.server : ""; font: Kirigami.Theme.smallFont; opacity: 0.6 }
            }
            Kirigami.Separator { Layout.fillWidth: true }

            // gauge with centered readout
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * 7

                ArcGauge {
                    id: gauge
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height)
                    height: width
                    // show the speed being measured live; fall back to last result
                    value: root.running ? root.liveMbps : (root.result ? root.result.down_mbps : 0)
                    maxValue: root.gaugeMax
                    // only spin briefly during ping, before any measurement arrives
                    running: root.running && root.liveMbps <= 0
                    color: root.accent
                }
                ColumnLayout {
                    anchors.centerIn: gauge
                    spacing: 0
                    PlasmaComponents.Label {
                        text: root.running ? root.phaseText(root.livePhase) : i18n("↓ Download")
                        font: Kirigami.Theme.smallFont; opacity: 0.7
                        Layout.alignment: Qt.AlignHCenter
                    }
                    PlasmaComponents.Label {
                        text: root.running ? (root.liveMbps > 0 ? root.liveMbps : "…")
                                           : (root.result ? root.result.down_mbps : "—")
                        color: root.accent
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.8
                        font.weight: Font.Bold
                        Layout.alignment: Qt.AlignHCenter
                    }
                    PlasmaComponents.Label {
                        text: i18n("Mb/s"); opacity: 0.6; font: Kirigami.Theme.smallFont
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // upload line
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.smallSpacing
                Kirigami.Icon { source: "go-up"; color: root.upColor; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Kirigami.Units.iconSizes.small }
                PlasmaComponents.Label { text: i18n("Upload"); opacity: 0.75 }
                PlasmaComponents.Label {
                    text: (root.result ? root.result.up_mbps : "—") + " Mb/s"
                    color: root.upColor; font.weight: Font.DemiBold
                }
            }

            // ping / jitter / loss — centered
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.gridUnit * 1.5
                Repeater {
                    model: [
                        { l: i18n("Ping"), v: root.result ? root.result.ping_ms + " ms" : "—" },
                        { l: i18n("Jitter"), v: root.result ? root.result.jitter_ms + " ms" : "—" },
                        { l: i18n("Loss"), v: root.result ? root.result.loss + "%" : "—" }
                    ]
                    ColumnLayout {
                        spacing: 0
                        PlasmaComponents.Label { text: modelData.l; font: Kirigami.Theme.smallFont; opacity: 0.7; Layout.alignment: Qt.AlignHCenter }
                        PlasmaComponents.Label { text: modelData.v; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignHCenter }
                    }
                }
            }

            // run button
            QQC2.Button {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                enabled: !root.running
                icon.name: root.running ? "" : "view-refresh"
                text: root.running ? i18n("Testing…") : i18n("Run Speed Test")
                onClicked: root.runTest()
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                font: Kirigami.Theme.smallFont
                opacity: 0.55
                text: root.running ? i18n("Testing… (~20s)")
                      : root.result ? i18n("Last tested %1 · %2", root.result.time, root.result.server)
                                    : i18n("Not tested yet")
            }
        }
    }
}
