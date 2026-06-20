/*
 * Linux-Router-Monitor :: shared polling data source.
 *
 * Wraps the `routermon-collect` helper behind the Plasma executable engine.
 * Every widget instantiates one of these with its `section`; the helper's
 * flock+cache layer ensures the router is queried at most once per interval
 * across ALL running widgets, so this stays cheap no matter how many you add.
 */
import QtQuick
import org.kde.plasma.plasma5support as P5Support

Item {
    id: root

    // which slice of the snapshot to pull: system|network|wifi|dns|clients|info|all
    property string section: "all"
    property int interval: 2000
    property string tool: "$HOME/.local/bin/routermon-collect"

    property var data: ({})
    property bool online: false
    property bool ready: false
    property string error: ""
    signal updated()

    P5Support.DataSource {
        id: src
        engine: "executable"
        interval: root.interval

        onNewData: function(source, d) {
            // The executable engine can fire transient events with empty stdout
            // (process start/partial). Ignore those and keep the last good state;
            // a genuine offline still arrives as parseable JSON with online:false.
            var stdout = d.stdout || ""
            if (stdout.trim().length === 0)
                return
            try {
                var parsed = JSON.parse(stdout)
                root.data = parsed
                root.online = parsed.online !== false
                root.error = parsed.error || ""
                root.ready = true
                root.updated()
            } catch (e) {
                root.error = "parse error"
            }
        }
    }

    function start() {
        src.connectSource(root.tool + " " + root.section)
    }
    Component.onCompleted: start()
}
