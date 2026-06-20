/*
 * A minimal filled line chart driven by a plain array of values, for compact
 * per-item history (e.g. a client's recent bandwidth). Auto-scales to its data.
 */
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.quickcharts as Charts

Item {
    id: s

    property var values: []
    property color lineColor: Kirigami.Theme.highlightColor
    property bool filled: true

    Charts.LineChart {
        anchors.fill: parent
        smooth: true
        lineWidth: 1.25

        Charts.SingleValueSource { id: lineSrc; value: s.lineColor }
        Charts.SingleValueSource { id: fillSrc; value: Qt.alpha(s.lineColor, 0.16) }
        Charts.ArraySource { id: arr; array: s.values }

        valueSources: [ arr ]
        colorSource: lineSrc
        fillColorSource: s.filled ? fillSrc : null

        yRange { from: 0; automatic: true }
    }
}
