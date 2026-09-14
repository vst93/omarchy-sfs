import QtQuick
import QtQuick.Shapes
import qs.Commons

// SFS mark — a single clean sync ring around a small "file" glyph, drawn
// natively with QtQuick.Shapes at a 24×24 viewBox, stroke-width 2, round
// caps/joins.
//
// The ring keeps the "sync" meaning; the little folded-corner document inside
// makes the "small files" side of SFS legible too. Both read cleanly from bar
// size (~13–15px) up. The stroke inherits `color` from the theme at the call
// site; nothing is hardcoded, so the icon stays native under any theme.
Item {
    id: root

    property real iconSize: Style.font.icon
    property color color: Color.foreground

    width: iconSize
    height: iconSize
    implicitWidth: iconSize
    implicitHeight: iconSize

    // Scale factor from the 24×24 Lucide viewBox to the requested size.
    readonly property real k: iconSize / 24

    Shape {
        anchors.fill: parent
        antialiasing: true
        layer.enabled: true
        layer.samples: 4
        visible: root.iconSize > 0

        // Ring — M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8
        ShapePath {
            strokeColor: root.color
            strokeWidth: 2 * root.k
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 21 * root.k
            startY: 12 * root.k
            PathArc {
                x: 17.7 * root.k; y: 5.7 * root.k
                radiusX: 9 * root.k; radiusY: 9 * root.k
                useLargeArc: true
                direction: PathArc.Clockwise
            }
        }

        // Arrowhead — M21 3v5h-5
        ShapePath {
            strokeColor: root.color
            strokeWidth: 2 * root.k
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 21 * root.k
            startY: 3 * root.k
            PathLine { x: 21 * root.k; y: 8 * root.k }
            PathLine { x: 16 * root.k; y: 8 * root.k }
        }

        // File — a small document with a folded top-right corner, centred in
        // the ring.
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.8 * root.k
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 9.6 * root.k
            startY: 8.4 * root.k
            PathLine { x: 12.9 * root.k; y: 8.4 * root.k }
            PathLine { x: 14.8 * root.k; y: 10.3 * root.k }
            PathLine { x: 14.8 * root.k; y: 16.8 * root.k }
            PathLine { x: 9.6 * root.k; y: 16.8 * root.k }
            PathLine { x: 9.6 * root.k; y: 8.4 * root.k }
            PathLine { x: 12.9 * root.k; y: 8.4 * root.k }
            PathLine { x: 12.9 * root.k; y: 10.3 * root.k }
            PathLine { x: 14.8 * root.k; y: 10.3 * root.k }
        }
    }
}
