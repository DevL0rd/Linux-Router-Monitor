/*
 * Linux-Router-Monitor :: Clients widget
 * Compact device rows with pin-to-top, connected status, live traffic + a
 * per-client bandwidth-history sparkline and WiFi signal; every per-device
 * action lives in a right-click menu. Uses a ListModel reconciled in place so
 * rows (and their charts) persist and reorder smoothly instead of resetting.
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

    property var hist: ({})          // mac(lower) -> [recent traffic_bps]
    property string lastResult: ""
    readonly property color accent: Plasmoid.configuration.accentColor !== ""
        ? Plasmoid.configuration.accentColor : Kirigami.Theme.highlightColor
    readonly property string ctl: "$HOME/.local/bin/routermon-ctl"

    Plasmoid.title: i18n("Router · Clients")
    Plasmoid.icon: "network-server"
    toolTipMainText: i18n("Connected Clients")
    toolTipSubText: i18n("%1 devices", clientModel.count)
    preferredRepresentation: fullRepresentation

    ListModel { id: clientModel }

    RouterData {
        id: routerData
        section: "all"
        interval: Plasmoid.configuration.pollInterval
        onUpdated: root.sync()
    }

    // ---- router-side actions ----
    P5Support.DataSource {
        id: ctlRunner
        engine: "executable"
        onNewData: function(source, d) {
            try { root.lastResult = JSON.parse(d.stdout).msg } catch (e) { root.lastResult = "" }
            resultTimer.restart()
            disconnectSource(source)
        }
    }
    function ctlRun(args) { ctlRunner.connectSource(root.ctl + " " + args) }

    // ---- local app launches ----
    P5Support.DataSource {
        id: localRunner
        engine: "executable"
        onNewData: function(source, d) { disconnectSource(source) }
    }
    function launch(cmd) { localRunner.connectSource(cmd) }

    Timer { id: resultTimer; interval: 4000; onTriggered: root.lastResult = "" }

    TextEdit { id: clip; visible: false }
    function copy(text) { clip.text = text; clip.selectAll(); clip.copy(); root.lastResult = i18n("Copied %1", text); resultTimer.restart() }

    // ---- pinning ----
    function pinnedList() { return (Plasmoid.configuration.pinnedMacs || "").split(",").filter(function(x){ return x }) }
    function isPinned(mac) { return pinnedList().indexOf(mac) >= 0 }
    function togglePin(mac) {
        var arr = pinnedList(); var i = arr.indexOf(mac)
        if (i >= 0) arr.splice(i, 1); else arr.push(mac)
        Plasmoid.configuration.pinnedMacs = arr.join(",")
        root.sync()
    }

    function sshTarget(ip) {
        var u = Plasmoid.configuration.sshUser
        return u ? (u + "@" + ip) : ip
    }

    // ---- build sorted desired list + reconcile the model in place ----
    function sync() {
        var leases = (routerData.snapshot.clients || {}).leases || []
        var stations = (routerData.snapshot.wifi || {}).stations || []
        var stByMac = {}
        for (var i = 0; i < stations.length; i++)
            stByMac[(stations[i].mac || "").toLowerCase()] = stations[i]

        // append to per-mac history (new object so bindings update)
        var h = {}
        for (var j = 0; j < leases.length; j++) {
            var lm = (leases[j].mac || "").toLowerCase()
            var arr = (root.hist[lm] || []).slice()
            var t = leases[j].traffic_bps
            arr.push(t > 0 ? t : 0)
            if (arr.length > 40) arr.shift()
            h[lm] = arr
        }
        root.hist = h

        var desired = []
        for (j = 0; j < leases.length; j++) {
            var l = leases[j]
            var lm2 = (l.mac || "").toLowerCase()
            var st = stByMac[lm2]
            // average bandwidth over the kept history window -> stable sort order
            var ha = h[lm2] || []
            var avg = 0
            if (ha.length) { for (var z = 0; z < ha.length; z++) avg += ha[z]; avg /= ha.length }
            desired.push({
                mac: l.mac, name: l.name || l.ip, ip: l.ip,
                connected: l.connected === true, blocked: l.blocked === true,
                traffic: l.traffic_bps === undefined ? -1 : l.traffic_bps,
                avgTraffic: avg,
                wireless: st !== undefined, band: st ? st.band : "",
                rssi: st ? st.rssi : 0, pinned: isPinned(l.mac),
            })
        }
        var by = Plasmoid.configuration.sortBy
        desired.sort(function(a, b) {
            if (a.pinned !== b.pinned) return a.pinned ? -1 : 1
            if (by === "traffic") return (b.avgTraffic || 0) - (a.avgTraffic || 0)
            if (by === "signal") return (b.wireless ? b.rssi : -999) - (a.wireless ? a.rssi : -999)
            if (by === "ip") {
                var na = a.ip.split(".").map(Number), nb = b.ip.split(".").map(Number)
                for (var k = 0; k < 4; k++) if (na[k] !== nb[k]) return na[k] - nb[k]
                return 0
            }
            return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1
        })

        // remove rows no longer present
        var macs = desired.map(function(d){ return d.mac })
        for (i = clientModel.count - 1; i >= 0; i--)
            if (macs.indexOf(clientModel.get(i).mac) < 0) clientModel.remove(i)

        // insert / move / update to match desired order
        for (var pos = 0; pos < desired.length; pos++) {
            var d = desired[pos]
            var cur = -1
            for (var x = pos; x < clientModel.count; x++)
                if (clientModel.get(x).mac === d.mac) { cur = x; break }
            if (cur < 0) clientModel.insert(pos, d)
            else { if (cur !== pos) clientModel.move(cur, pos, 1); clientModel.set(pos, d) }
        }
    }

    // ---- rename / reserve prompt ----
    Kirigami.PromptDialog {
        id: prompt
        property string mac: ""
        property string mode: ""
        title: mode === "rename" ? i18n("Rename device") : i18n("Reserve IP")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        QQC2.TextField { id: promptField; implicitWidth: Kirigami.Units.gridUnit * 14 }
        onAccepted: {
            var v = promptField.text.trim()
            if (!v) return
            if (mode === "rename") root.ctlRun("rename " + mac + " '" + v.replace(/'/g, "") + "'")
            else root.ctlRun("reserve " + mac + " " + v)
        }
    }
    function openRename(mac, name) { prompt.mode = "rename"; prompt.mac = mac; promptField.text = name; prompt.open() }
    function openReserve(mac, ip) { prompt.mode = "reserve"; prompt.mac = mac; promptField.text = ip; prompt.open() }

    // ---- per-client right-click menu (all the old per-row actions) ----
    function openClientMenu(mac, ip, name, wireless, blocked, pinned) {
        clientMenu.mac = mac; clientMenu.ip = ip; clientMenu.cname = name
        clientMenu.wireless = wireless; clientMenu.blocked = blocked; clientMenu.pinned = pinned
        clientMenu.popup()
    }
    QQC2.Menu {
        id: clientMenu
        property string mac: ""
        property string ip: ""
        property string cname: ""
        property bool wireless: false
        property bool blocked: false
        property bool pinned: false
        QQC2.MenuItem {
            text: clientMenu.pinned ? i18n("Unpin") : i18n("Pin to top")
            icon.name: clientMenu.pinned ? "window-unpin" : "window-pin"
            onTriggered: root.togglePin(clientMenu.mac)
        }
        QQC2.MenuSeparator {}
        QQC2.MenuItem { text: i18n("SSH"); icon.name: "utilities-terminal"; onTriggered: root.launch("konsole -e ssh " + root.sshTarget(clientMenu.ip)) }
        QQC2.MenuItem { text: i18n("Browse files (SMB)"); icon.name: "folder-remote"; onTriggered: root.launch("xdg-open smb://" + clientMenu.ip + "/") }
        QQC2.MenuItem { text: i18n("Ping"); icon.name: "network-connect"; onTriggered: root.launch("konsole -e bash -c \"ping " + clientMenu.ip + "; read -n1 -p Done\"") }
        QQC2.MenuItem { text: i18n("Port scan (nmap)"); icon.name: "system-search"; onTriggered: root.launch("konsole -e bash -c \"nmap " + clientMenu.ip + " || echo nmap-not-installed; read -n1 -p Done\"") }
        QQC2.MenuSeparator {}
        QQC2.MenuItem { text: i18n("Copy IP"); icon.name: "edit-copy"; onTriggered: root.copy(clientMenu.ip) }
        QQC2.MenuItem { text: i18n("Copy MAC"); icon.name: "network-card"; onTriggered: root.copy(clientMenu.mac) }
        QQC2.MenuItem { text: i18n("Rename…"); icon.name: "edit-rename"; onTriggered: root.openRename(clientMenu.mac, clientMenu.cname) }
        QQC2.MenuItem { text: i18n("Reserve IP…"); icon.name: "bookmark-new"; onTriggered: root.openReserve(clientMenu.mac, clientMenu.ip) }
        QQC2.MenuSeparator {}
        QQC2.MenuItem {
            visible: clientMenu.wireless; height: visible ? implicitHeight : 0
            text: i18n("Disconnect (WiFi)"); icon.name: "network-disconnect"
            onTriggered: root.ctlRun("disconnect " + clientMenu.mac)
        }
        QQC2.MenuItem {
            text: clientMenu.blocked ? i18n("Unblock internet") : i18n("Block internet")
            icon.name: clientMenu.blocked ? "dialog-ok-apply" : "dialog-cancel"
            onTriggered: root.ctlRun((clientMenu.blocked ? "unblock " : "block ") + clientMenu.mac)
        }
    }

    fullRepresentation: Item {
        clip: true
        Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        Layout.minimumHeight: Kirigami.Units.gridUnit * 12
        implicitWidth: Kirigami.Units.gridUnit * 26
        implicitHeight: Kirigami.Units.gridUnit * 24

        StatusOverlay { anchors.fill: parent; online: routerData.online; paused: routerData.paused }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon { source: "network-server"; Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium; Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium }
                PlasmaComponents.Label { text: i18n("Clients"); font.weight: Font.Bold; Layout.fillWidth: true }
                PlasmaComponents.Label {
                    text: root.lastResult; visible: root.lastResult !== ""
                    color: root.accent; font: Kirigami.Theme.smallFont; elide: Text.ElideLeft
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 10
                }
                PlasmaComponents.Label { text: i18n("%1 devices", clientModel.count); opacity: 0.7; font: Kirigami.Theme.smallFont }
            }
            Kirigami.Separator { Layout.fillWidth: true }

            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    model: clientModel
                    spacing: Kirigami.Units.smallSpacing
                    move: Transition { NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic } }
                    displaced: Transition { NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic } }

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: card.implicitHeight + Kirigami.Units.smallSpacing * 2
                        radius: Kirigami.Units.smallSpacing
                        color: model.blocked ? Qt.alpha(Kirigami.Theme.negativeTextColor, 0.10)
                                              : Qt.alpha(Kirigami.Theme.textColor, 0.05)

                        ColumnLayout {
                            id: card
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Kirigami.Units.smallSpacing
                            spacing: 1

                            // line 1: pin, type, name, status, traffic, signal
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing
                                Kirigami.Icon {
                                    visible: model.pinned
                                    source: "window-pin"
                                    color: root.accent
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                }
                                Kirigami.Icon {
                                    source: model.wireless ? "network-wireless" : "network-wired"
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                    opacity: 0.8
                                }
                                PlasmaComponents.Label { text: model.name; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                Rectangle {
                                    width: Kirigami.Units.smallSpacing * 1.3; height: width; radius: width/2
                                    color: model.blocked ? Kirigami.Theme.negativeTextColor
                                          : model.connected ? Kirigami.Theme.positiveTextColor
                                          : Kirigami.Theme.disabledTextColor
                                }
                                PlasmaComponents.Label {
                                    text: Fmt.rate(model.traffic); font: Kirigami.Theme.smallFont
                                    color: (model.traffic > 0) ? root.accent : Kirigami.Theme.textColor
                                    opacity: (model.traffic > 0) ? 1 : 0.5
                                }
                                PlasmaComponents.Label {
                                    visible: model.wireless
                                    text: model.band; font: Kirigami.Theme.smallFont; opacity: 0.6
                                }
                                SignalBars {
                                    visible: model.wireless
                                    level: Fmt.rssiBars(model.rssi)
                                    activeColor: Fmt.rssiColor(model.rssi, Kirigami.Theme)
                                }
                            }

                            // line 2: bandwidth-history sparkline (actions are in the right-click menu)
                            Sparkline {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                                values: root.hist[(model.mac || "").toLowerCase()] || []
                                lineColor: root.accent
                                rangeFloor: 1000000
                                tipText: function(v) { return Fmt.rate(v) }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton    // hover passes to the sparkline below
                            onClicked: root.openClientMenu(model.mac, model.ip, model.name, model.wireless, model.blocked, model.pinned)
                        }
                    }
                }
            }
        }
    }

}
