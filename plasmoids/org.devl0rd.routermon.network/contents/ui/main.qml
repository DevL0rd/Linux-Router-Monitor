/*
 * Linux-Router-Monitor :: Network widget
 * WAN throughput, latency and packet loss.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import "lib"
import "lib/Format.js" as Fmt

PlasmoidItem {
    id: root

    readonly property var net: routerData.snapshot.network || ({})
    readonly property var info: routerData.snapshot.info || ({})
    readonly property color accent: Plasmoid.configuration.accentColor !== ""
        ? Plasmoid.configuration.accentColor : Kirigami.Theme.highlightColor
    readonly property color upColor: Kirigami.Theme.neutralTextColor

    Plasmoid.title: i18n("Router · Network")
    Plasmoid.icon: "network-wired"
    toolTipMainText: i18n("Router Network")
    toolTipSubText: routerData.online
        ? i18n("↓ %1   ↑ %2   ·   %3 ms", Fmt.mbps(net.down_mbps), Fmt.mbps(net.up_mbps), net.ping_rtt||0)
        : i18n("Router offline")
    preferredRepresentation: fullRepresentation

    RouterData {
        id: routerData
        section: "all"
        interval: Plasmoid.configuration.pollInterval
    }

    fullRepresentation: Item {
        clip: true
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: Kirigami.Units.gridUnit * 13
        implicitWidth: Kirigami.Units.gridUnit * 18
        implicitHeight: Kirigami.Units.gridUnit * 19

        StatusOverlay { anchors.fill: parent; online: routerData.online; paused: routerData.paused }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            // header
            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon { source: "network-wired"; Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium; Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium }
                ColumnLayout {
                    spacing: 0; Layout.fillWidth: true
                    PlasmaComponents.Label { text: (net.wan_proto || "WAN").toUpperCase(); font.weight: Font.Bold }
                    PlasmaComponents.Label { text: net.wan_ip || "—"; font: Kirigami.Theme.smallFont; opacity: 0.6 }
                }
                Rectangle {
                    width: Kirigami.Units.smallSpacing * 1.4; height: width; radius: width/2
                    color: net.wan_up ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                }
            }
            Kirigami.Separator { Layout.fillWidth: true }

            // download
            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon { source: "go-down"; color: root.accent; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Kirigami.Units.iconSizes.small }
                PlasmaComponents.Label { text: i18n("Download"); Layout.fillWidth: true; opacity: 0.8 }
                PlasmaComponents.Label { text: Fmt.mbps(net.down_mbps); color: root.accent; font.weight: Font.Bold }
            }
            HistoryChart {
                Layout.fillWidth: true; Layout.preferredHeight: Kirigami.Units.gridUnit * 2.5
                visible: Plasmoid.configuration.showCharts
                value: net.down_mbps || 0
                rangeMax: Plasmoid.configuration.maxMbps
                rangeFloor: 8
                lineColor: root.accent
                sampleInterval: Plasmoid.configuration.pollInterval
                paused: routerData.paused
                tipText: function(v) { return "↓ " + Fmt.mbps(v) }
            }

            // upload
            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon { source: "go-up"; color: root.upColor; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Kirigami.Units.iconSizes.small }
                PlasmaComponents.Label { text: i18n("Upload"); Layout.fillWidth: true; opacity: 0.8 }
                PlasmaComponents.Label { text: Fmt.mbps(net.up_mbps); color: root.upColor; font.weight: Font.Bold }
            }
            HistoryChart {
                Layout.fillWidth: true; Layout.preferredHeight: Kirigami.Units.gridUnit * 2.5
                visible: Plasmoid.configuration.showCharts
                value: net.up_mbps || 0
                rangeMax: Plasmoid.configuration.maxMbps
                rangeFloor: 8
                lineColor: root.upColor
                sampleInterval: Plasmoid.configuration.pollInterval
                paused: routerData.paused
                tipText: function(v) { return "↑ " + Fmt.mbps(v) }
            }

            // latency / loss
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.largeSpacing
                ColumnLayout {
                    spacing: 0; Layout.fillWidth: true
                    PlasmaComponents.Label { text: i18n("Latency (WAN)"); font: Kirigami.Theme.smallFont; opacity: 0.7 }
                    PlasmaComponents.Label {
                        text: (net.ping_rtt||0).toFixed(1) + " ms"
                        color: Fmt.heat(net.ping_rtt||0, 40, 100, Kirigami.Theme)
                        font.weight: Font.DemiBold
                    }
                }
                ColumnLayout {
                    spacing: 0; Layout.fillWidth: true
                    PlasmaComponents.Label { text: i18n("Packet loss"); font: Kirigami.Theme.smallFont; opacity: 0.7 }
                    PlasmaComponents.Label {
                        text: (net.ping_loss||0) + "%"
                        color: Fmt.heat(net.ping_loss||0, 1, 5, Kirigami.Theme)
                        font.weight: Font.DemiBold
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
