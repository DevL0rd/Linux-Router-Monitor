/*
 * Linux-Router-Monitor :: DNS / AdGuard widget
 * AdGuard Home query volume, blocked %, latency and top lists.
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

    readonly property var dns: routerData.data.dns || null
    readonly property bool hasDns: dns !== null
    readonly property color accent: Plasmoid.configuration.accentColor !== ""
        ? Plasmoid.configuration.accentColor : Kirigami.Theme.highlightColor
    readonly property string ctl: "$HOME/.local/bin/routermon-ctl"

    Plasmoid.title: i18n("Router · DNS")
    Plasmoid.icon: "security-high"
    toolTipMainText: i18n("AdGuard Home")
    toolTipSubText: hasDns
        ? i18n("%1% blocked · %2 queries", dns.blocked_pct, dns.queries_total)
        : i18n("AdGuard unavailable")
    preferredRepresentation: fullRepresentation

    RouterData {
        id: routerData
        section: "all"
        interval: Plasmoid.configuration.pollInterval
    }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: function(source, d) { disconnectSource(source) }
    }
    function setProtection(on) { runner.connectSource(root.ctl + " protection " + (on ? "on" : "off")) }
    function openUrl(url) { runner.connectSource("xdg-open " + url) }
    readonly property string aghUrl: (routerData.data.info || {}).agh_url || ""

    component MiniStat: ColumnLayout {
        property string label: ""
        property string value: ""
        property color valueColor: Kirigami.Theme.textColor
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: 0
        PlasmaComponents.Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: label; font: Kirigami.Theme.smallFont; opacity: 0.55 }
        PlasmaComponents.Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: value; font.pointSize: Kirigami.Theme.smallFont.pointSize; font.weight: Font.DemiBold; color: valueColor }
    }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: Kirigami.Units.gridUnit * 12
        implicitWidth: Kirigami.Units.gridUnit * 18
        implicitHeight: Kirigami.Units.gridUnit * 20

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            // header
            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon { source: "security-high"; Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium; Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium }
                PlasmaComponents.Label { text: i18n("AdGuard Home"); font.weight: Font.Bold; Layout.fillWidth: true }
                QQC2.ToolButton {
                    visible: Plasmoid.configuration.showOpenUI && root.aghUrl !== ""
                    flat: true
                    icon.name: "internet-web-browser"
                    implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: Kirigami.Units.iconSizes.medium
                    onClicked: root.openUrl(root.aghUrl)
                    QQC2.ToolTip.text: i18n("Open AdGuard Home"); QQC2.ToolTip.visible: hovered
                }
                Rectangle {
                    width: Kirigami.Units.smallSpacing * 1.4; height: width; radius: width/2
                    color: (root.hasDns && root.dns.protection) ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                }
            }
            Kirigami.Separator { Layout.fillWidth: true }

            // protection toggle (pinned to the top)
            RowLayout {
                Layout.fillWidth: true
                visible: Plasmoid.configuration.showProtection
                Kirigami.Icon { source: "security-high"; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Kirigami.Units.iconSizes.small }
                PlasmaComponents.Label { text: i18n("Protection"); Layout.fillWidth: true }
                QQC2.Switch {
                    enabled: root.hasDns
                    checked: root.hasDns && root.dns.protection
                    onClicked: root.setProtection(checked)
                }
            }

            // unavailable state
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                visible: !root.hasDns
                PlasmaComponents.Label {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignCenter
                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    opacity: 0.7
                    text: i18n("AdGuard Home is unreachable.\nCheck the URL and credentials in\n~/.config/Linux-Router-Monitor/config.json")
                }
            }

            // ---- main stats ----
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.hasDns
                spacing: Kirigami.Units.smallSpacing

                // big blocked %, centered
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: (root.hasDns ? root.dns.blocked_pct : 0) + "%"
                        color: root.accent
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.6
                        font.weight: Font.Bold
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: i18n("of %1 queries blocked", root.hasDns ? root.dns.queries_total.toLocaleString() : "0")
                        font: Kirigami.Theme.smallFont; opacity: 0.7
                    }
                }

                // even, centered mini-stats (static instances, no array-model churn)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    spacing: 0
                    MiniStat { label: i18n("Blocked"); value: root.hasDns ? root.dns.blocked_total.toLocaleString() : "—"; valueColor: root.accent }
                    MiniStat { label: i18n("Rate"); value: (root.hasDns ? root.dns.qps : 0) + " q/s" }
                    MiniStat { label: i18n("Avg"); value: (root.hasDns ? root.dns.avg_ms : 0) + " ms"; valueColor: Fmt.heat(root.hasDns ? root.dns.avg_ms : 0, 50, 100, Kirigami.Theme) }
                }

                HistoryChart {
                    Layout.fillWidth: true; Layout.preferredHeight: Kirigami.Units.gridUnit * 2.5
                    visible: Plasmoid.configuration.showChart
                    value: root.hasDns ? root.dns.qps : 0
                    lineColor: root.accent
                    sampleInterval: Plasmoid.configuration.pollInterval
                }

                // top blocked
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: Plasmoid.configuration.showTopLists
                    spacing: 1
                    PlasmaComponents.Label { text: i18n("Top blocked"); font.weight: Font.DemiBold; Layout.topMargin: Kirigami.Units.smallSpacing }
                    Repeater {
                        model: root.hasDns ? root.dns.top_blocked : []
                        RowLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label { text: modelData.name; font: Kirigami.Theme.smallFont; elide: Text.ElideRight; Layout.fillWidth: true; opacity: 0.85 }
                            PlasmaComponents.Label { text: modelData.count; font: Kirigami.Theme.smallFont; color: root.accent }
                        }
                    }
                    PlasmaComponents.Label { text: i18n("Top clients"); font.weight: Font.DemiBold; Layout.topMargin: Kirigami.Units.smallSpacing }
                    Repeater {
                        model: root.hasDns ? root.dns.top_clients : []
                        RowLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label { text: modelData.name; font: Kirigami.Theme.smallFont; elide: Text.ElideRight; Layout.fillWidth: true; opacity: 0.85 }
                            PlasmaComponents.Label { text: modelData.count; font: Kirigami.Theme.smallFont; opacity: 0.7 }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
