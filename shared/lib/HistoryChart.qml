/*
 * A line chart that keeps a rolling history of a single value, styled to match
 * the Plasma System Monitor graphs (filled area under a coloured line).
 */
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.quickcharts as Charts

Item {
    id: root

    property real value: 0
    property color lineColor: Kirigami.Theme.highlightColor
    property int maxHistory: 80
    property int sampleInterval: 2000
    property real rangeMax: 0          // 0 = auto-scale
    property bool filled: true

    Charts.LineChart {
        id: chart
        anchors.fill: parent
        smooth: true
        lineWidth: 1.5

        Charts.SingleValueSource { id: liveValue; value: root.value }
        Charts.SingleValueSource { id: lineColorSrc; value: root.lineColor }
        Charts.SingleValueSource { id: fillColorSrc; value: Qt.alpha(root.lineColor, 0.18) }

        Charts.HistoryProxySource {
            id: history
            source: liveValue
            maximumHistory: root.maxHistory
            interval: root.sampleInterval
        }

        valueSources: [ history ]
        colorSource: lineColorSrc
        fillColorSource: root.filled ? fillColorSrc : null

        yRange {
            from: 0
            to: root.rangeMax
            automatic: root.rangeMax <= 0
        }
    }
}
