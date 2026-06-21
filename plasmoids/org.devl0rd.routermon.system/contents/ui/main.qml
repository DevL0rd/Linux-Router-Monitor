/*
 * Linux-Router-Monitor :: System widget
 * Router CPU, RAM, swap, temperatures, uptime, sessions and router actions
 * (reboot, restart WiFi, view log).
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import "lib"
import "lib/Format.js" as Fmt

PlasmoidItem {
    id: root

    readonly property var sys: routerData.snapshot.system || ({})
    readonly property var info: routerData.snapshot.info || ({})
    readonly property var radios: (routerData.snapshot.wifi || {}).radios || []
    readonly property color accent: Plasmoid.configuration.accentColor !== ""
        ? Plasmoid.configuration.accentColor : Kirigami.Theme.highlightColor

    property string lastResult: ""
    readonly property string ctl: "$HOME/.local/bin/routermon-ctl"

    Plasmoid.title: i18n("Router · System")
    Plasmoid.icon: "cpu"
    toolTipMainText: i18n("Router System")
    toolTipSubText: routerData.online
        ? i18n("CPU %1%  ·  RAM %2%  ·  %3", Math.round((sys.cpu||{}).total||0),
               Math.round(sys.mem_used_pct||0), Fmt.temp(sys.cpu_temp))
        : i18n("Router offline")
    preferredRepresentation: fullRepresentation

    RouterData {
        id: routerData
        section: "all"
        interval: Plasmoid.configuration.pollInterval
    }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: function(source, d) {
            var msg = ""
            try { msg = JSON.parse(d.stdout).msg } catch (e) { msg = (d.stderr || "").trim() || i18n("failed") }
            root.lastResult = msg
            resultTimer.restart()
            disconnectSource(source)
        }
    }
    function run(args) { runner.connectSource(root.ctl + " " + args) }

    P5Support.DataSource {
        id: localRunner
        engine: "executable"
        onNewData: function(source, d) { disconnectSource(source) }
    }
    function openUrl(url) { localRunner.connectSource("xdg-open " + url) }

    Timer { id: resultTimer; interval: 5000; onTriggered: root.lastResult = "" }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: Kirigami.Units.gridUnit * 14
        implicitWidth: Kirigami.Units.gridUnit * 17
        implicitHeight: Kirigami.Units.gridUnit * 23

        StatusOverlay { anchors.fill: parent; online: routerData.online; paused: routerData.paused }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            // ---------- header ----------
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Kirigami.Icon { source: "cpu"; Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium; Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    PlasmaComponents.Label { text: info.model || i18n("Router"); font.weight: Font.Bold; elide: Text.ElideRight; Layout.fillWidth: true }
                    PlasmaComponents.Label { text: i18n("up %1", Fmt.duration(info.uptime)); font: Kirigami.Theme.smallFont; opacity: 0.6 }
                }
                QQC2.ToolButton {
                    visible: Plasmoid.configuration.showWebUI && (info.admin_url || "") !== ""
                    flat: true
                    icon.name: "internet-web-browser"
                    implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: Kirigami.Units.iconSizes.medium
                    onClicked: root.openUrl(info.admin_url)
                    QQC2.ToolTip.text: i18n("Open router web UI"); QQC2.ToolTip.visible: hovered
                }
                Rectangle {
                    width: Kirigami.Units.smallSpacing * 1.4; height: width; radius: width/2
                    color: routerData.online ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            // ---------- CPU ----------
            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label { text: i18n("CPU"); font.weight: Font.DemiBold; Layout.fillWidth: true }
                PlasmaComponents.Label {
                    text: Math.round((sys.cpu||{}).total||0) + "%"
                    color: Fmt.heat((sys.cpu||{}).total||0, 60, 85, Kirigami.Theme)
                    font.weight: Font.Bold
                }
            }
            HistoryChart {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                visible: Plasmoid.configuration.showCharts
                value: (sys.cpu||{}).total||0
                rangeMax: 100
                lineColor: root.accent
                sampleInterval: Plasmoid.configuration.pollInterval
                paused: routerData.paused
                tipText: function(v) { return Math.round(v) + "% CPU" }
            }
            GridLayout {
                Layout.fillWidth: true
                visible: Plasmoid.configuration.showPerCore
                columns: 2
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: 2
                Repeater {
                    // count-based model so the bars persist (animate value->value,
                    // not 0->value) across polls
                    model: ((sys.cpu||{}).cores || []).length
                    Gauge {
                        Layout.fillWidth: true
                        label: i18n("Core %1", index)
                        value: ((sys.cpu||{}).cores || [])[index] || 0
                        barColor: root.accent
                    }
                }
            }

            // ---------- memory ----------
            Gauge {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                label: i18n("RAM")
                value: sys.mem_used_pct || 0
                valueText: Fmt.bytes((sys.mem_total||0) - (sys.mem_avail||0)) + " / " + Fmt.bytes(sys.mem_total||0)
                barColor: Fmt.heat(sys.mem_used_pct||0, 75, 90, Kirigami.Theme)
            }
            Gauge {
                Layout.fillWidth: true
                label: i18n("Swap")
                value: sys.swap_used_pct || 0
                valueText: Fmt.bytes(sys.swap_used||0) + " / " + Fmt.bytes(sys.swap_total||0)
                barColor: root.accent
            }

            // ---------- temps ----------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                visible: Plasmoid.configuration.showTemps
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label { text: i18n("Temperatures"); font.weight: Font.DemiBold; Layout.fillWidth: true }
                    PlasmaComponents.Label {
                        text: i18n("CPU %1", Fmt.temp(sys.cpu_temp))
                        color: Fmt.heat(sys.cpu_temp||0, 80, 95, Kirigami.Theme)
                        font.weight: Font.DemiBold
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Repeater {
                        model: root.radios
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.band.replace("GHz", "G").replace("-", "·")
                                font: Kirigami.Theme.smallFont; opacity: 0.55
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: Fmt.temp(modelData.temp)
                                font: Kirigami.Theme.smallFont
                                color: Fmt.heat(modelData.temp || 0, 75, 90, Kirigami.Theme)
                            }
                        }
                    }
                }
            }

            // ---------- actions ----------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Separator { Layout.fillWidth: true }

                ConfirmButton {
                    Layout.fillWidth: true
                    visible: Plasmoid.configuration.showReboot
                    baseIcon: "system-reboot"
                    baseText: i18n("Reboot router")
                    onConfirmed: root.run("reboot")
                }
                ConfirmButton {
                    Layout.fillWidth: true
                    visible: Plasmoid.configuration.showRestartWifi
                    baseIcon: "network-wireless"
                    baseText: i18n("Restart WiFi")
                    onConfirmed: root.run("restart-wifi")
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    visible: root.lastResult !== ""
                    text: root.lastResult
                    color: root.accent
                    font: Kirigami.Theme.smallFont
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                QQC2.Button {
                    Layout.fillWidth: true
                    visible: Plasmoid.configuration.showWebUI && (info.admin_url || "") !== ""
                    icon.name: "internet-web-browser"
                    text: i18n("Open router web UI")
                    onClicked: root.openUrl(info.admin_url)
                }
                QQC2.Button {
                    Layout.fillWidth: true
                    icon.name: routerData.paused ? "media-playback-start" : "media-playback-pause"
                    text: routerData.paused ? i18n("Resume monitoring") : i18n("Pause monitoring")
                    onClicked: root.run("pause toggle")
                }
            }

            Item { Layout.fillHeight: true }

            // ---------- footer ----------
            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label { text: i18n("Load %1", (sys.load||[0])[0]); font: Kirigami.Theme.smallFont; opacity: 0.7; Layout.fillWidth: true }
                PlasmaComponents.Label { text: i18n("%1 sessions", sys.conntrack||0); font: Kirigami.Theme.smallFont; opacity: 0.7 }
            }
        }
    }
}
