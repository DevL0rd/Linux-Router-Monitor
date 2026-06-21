/*
 * Linux-Router-Monitor :: WiFi widget
 * Per-band channel/width/noise/airtime/temperature/DFS and connected clients.
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

    readonly property var radios: (routerData.snapshot.wifi || {}).radios || []
    readonly property var stations: (routerData.snapshot.wifi || {}).stations || []
    readonly property color accent: Plasmoid.configuration.accentColor !== ""
        ? Plasmoid.configuration.accentColor : Kirigami.Theme.highlightColor

    Plasmoid.title: i18n("Router · WiFi")
    Plasmoid.icon: "network-wireless"
    toolTipMainText: i18n("Router WiFi")
    toolTipSubText: i18n("%1 clients across %2 bands", stations.length, radios.length)
    preferredRepresentation: fullRepresentation

    RouterData {
        id: routerData
        section: "all"
        interval: Plasmoid.configuration.pollInterval
    }

    function dfsLabel(r) {
        if (r.band === undefined || r.band.indexOf("5GHz") < 0) return ""
        return r.dfs === "IDLE" ? i18n("no DFS") : i18n("DFS: %1", r.dfs)
    }
    function dfsColor(r) {
        return r.dfs === "IDLE" ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.neutralTextColor
    }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 15
        Layout.minimumHeight: Kirigami.Units.gridUnit * 14
        implicitWidth: Kirigami.Units.gridUnit * 19
        implicitHeight: Kirigami.Units.gridUnit * 16

        StatusOverlay { anchors.fill: parent; online: routerData.online; paused: routerData.paused }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon { source: "network-wireless"; Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium; Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium }
                PlasmaComponents.Label { text: i18n("WiFi"); font.weight: Font.Bold; Layout.fillWidth: true }
                PlasmaComponents.Label { text: i18n("%1 clients", stations.length); opacity: 0.7; font: Kirigami.Theme.smallFont }
            }
            Kirigami.Separator { Layout.fillWidth: true }

            // ---- per-band cards ----
            Repeater {
                // count-based model so band cards persist (airtime bar animates
                // value->value, not 0->value) across polls
                model: root.radios.length
                Rectangle {
                    id: bandCard
                    property var r: root.radios[index] || ({})
                    Layout.fillWidth: true
                    Layout.preferredHeight: bandCol.implicitHeight + Kirigami.Units.smallSpacing * 2
                    radius: Kirigami.Units.smallSpacing
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.05)
                    opacity: bandCard.r.on ? 1 : 0.5

                    ColumnLayout {
                        id: bandCol
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        spacing: 3

                        // header: band · DFS · clients
                        RowLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label { text: bandCard.r.band; font.weight: Font.DemiBold; color: root.accent }
                            Rectangle {
                                visible: root.dfsLabel(bandCard.r) !== ""
                                radius: 3; color: Qt.alpha(root.dfsColor(bandCard.r), 0.18)
                                Layout.preferredHeight: dfsTxt.implicitHeight + 2
                                Layout.preferredWidth: dfsTxt.implicitWidth + Kirigami.Units.smallSpacing
                                PlasmaComponents.Label {
                                    id: dfsTxt; anchors.centerIn: parent
                                    text: root.dfsLabel(bandCard.r); font: Kirigami.Theme.smallFont
                                    color: root.dfsColor(bandCard.r)
                                }
                            }
                            Item { Layout.fillWidth: true }
                            PlasmaComponents.Label { text: i18n("%1 clients", bandCard.r.clients); font: Kirigami.Theme.smallFont; opacity: 0.8 }
                        }

                        // evenly spaced, centered stats
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Repeater {
                                model: [
                                    { l: i18n("Channel"), v: bandCard.r.chan + " / " + bandCard.r.width },
                                    { l: i18n("Noise"), v: Fmt.dbm(bandCard.r.noise) },
                                    { l: i18n("Temp"), v: Fmt.temp(bandCard.r.temp) }
                                ]
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    spacing: 0
                                    PlasmaComponents.Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: modelData.l; font: Kirigami.Theme.smallFont; opacity: 0.55 }
                                    PlasmaComponents.Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: modelData.v; font: Kirigami.Theme.smallFont }
                                }
                            }
                        }

                        Gauge {
                            Layout.fillWidth: true
                            visible: Plasmoid.configuration.showInterference
                            label: i18n("Airtime")
                            value: bandCard.r.busy
                            valueText: bandCard.r.busy + "%" + (bandCard.r.glitch > 100 ? i18n(" · %1 glitches", bandCard.r.glitch) : "")
                            barColor: Fmt.heat(bandCard.r.busy, 40, 70, Kirigami.Theme)
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
