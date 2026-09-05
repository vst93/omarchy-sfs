import QtQuick
import QtQuick.Shapes
import qs.Commons

// SFS mark — Lucide "folder-sync" drawn natively with QtQuick.Shapes.
// 24×24 viewBox, stroke-width 2, round caps/joins: the same flat geometry as
// every other Omarchy bar icon (see the built-in DropboxIcon for the pattern).
// Strokes inherit `color` from the theme at every call site; nothing is
// hardcoded, so the icon stays native under any theme.
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

    // 1 — folder body: M9 20H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h3.9a2 2 0 0 1
    //     1.69.9l.81 1.2a2 2 0 0 0 1.67.9H20a2 2 0 0 1 2 2v.5
    ShapePath {
      strokeColor: root.color
      strokeWidth: 2 * root.k
      fillColor: "transparent"
      capStyle: ShapePath.Round
      joinStyle: ShapePath.Round
      startX: 9 * root.k
      startY: 20 * root.k
      PathLine { x: 4 * root.k;  y: 20 * root.k }
      PathCubic { control1X: 2 * root.k; control1Y: 20 * root.k
                  control2X: 2 * root.k; control2Y: 20 * root.k
                  x: 2 * root.k;         y: 18 * root.k }
      PathCubic { control1X: 2 * root.k; control1Y: 18 * root.k
                  control2X: 2 * root.k; control2Y: 18 * root.k
                  x: 2 * root.k;         y: 5 * root.k }
      PathCubic { control1X: 2 * root.k; control1Y: 3.9 * root.k
                  control2X: 2.9 * root.k; control2Y: 3 * root.k
                  x: 4 * root.k;           y: 3 * root.k }
      PathCubic { control1X: 5.9 * root.k; control1Y: 3 * root.k
                  control2X: 7.9 * root.k; control2Y: 3.4 * root.k
                  x: 7.9 * root.k;         y: 3.4 * root.k }
      PathCubic { control1X: 8.59 * root.k; control1Y: 3.5 * root.k
                  control2X: 9.28 * root.k; control2Y: 3.9 * root.k
                  x: 9.59 * root.k;         y: 4.6 * root.k }
      PathCubic { control1X: 10.1 * root.k; control1Y: 5.6 * root.k
                  control2X: 11.26 * root.k; control2Y: 6 * root.k
                  x: 11.26 * root.k;         y: 6 * root.k }
      PathCubic { control1X: 20 * root.k; control1Y: 6 * root.k
                  control2X: 22 * root.k; control2Y: 6 * root.k
                  x: 22 * root.k;         y: 8 * root.k }
      PathCubic { control1X: 22 * root.k; control1Y: 8 * root.k
                  control2X: 22 * root.k; control2Y: 8 * root.k
                  x: 22 * root.k;         y: 8.5 * root.k }
    }

    // 2 — small arrow shaft: M12 10v4h4
    ShapePath {
      strokeColor: root.color
      strokeWidth: 2 * root.k
      fillColor: "transparent"
      capStyle: ShapePath.Round
      joinStyle: ShapePath.Round
      startX: 12 * root.k
      startY: 10 * root.k
      PathLine { x: 12 * root.k; y: 14 * root.k }
      PathLine { x: 16 * root.k; y: 14 * root.k }
    }

    // 3 — lower arc: m12 14 1.535-1.605a5 5 0 0 1 8 1.5
    ShapePath {
      strokeColor: root.color
      strokeWidth: 2 * root.k
      fillColor: "transparent"
      capStyle: ShapePath.Round
      joinStyle: ShapePath.Round
      startX: 12 * root.k
      startY: 14 * root.k
      PathCubic { control1X: 12.5 * root.k;  control1Y: 13.46 * root.k
                  control2X: 13.5 * root.k;  control2Y: 12.4 * root.k
                  x: 15.5 * root.k;          y: 12.4 * root.k }
      PathCubic { control1X: 18.26 * root.k; control1Y: 12.4 * root.k
                  control2X: 20.5 * root.k;  control2Y: 14.5 * root.k
                  x: 20.5 * root.k;          y: 17.5 * root.k }
    }

    // 4 — upper arc tail: M22 22v-4h-4
    ShapePath {
      strokeColor: root.color
      strokeWidth: 2 * root.k
      fillColor: "transparent"
      capStyle: ShapePath.Round
      joinStyle: ShapePath.Round
      startX: 22 * root.k
      startY: 22 * root.k
      PathLine { x: 22 * root.k; y: 18 * root.k }
      PathLine { x: 18 * root.k; y: 18 * root.k }
    }

    // 5 — upper arc: m22 18-1.535 1.605a5 5 0 0 1-8-1.5
    ShapePath {
      strokeColor: root.color
      strokeWidth: 2 * root.k
      fillColor: "transparent"
      capStyle: ShapePath.Round
      joinStyle: ShapePath.Round
      startX: 22 * root.k
      startY: 18 * root.k
      PathCubic { control1X: 21.5 * root.k;  control1Y: 18.53 * root.k
                  control2X: 20.5 * root.k;  control2Y: 19.6 * root.k
                  x: 18.5 * root.k;          y: 19.6 * root.k }
      PathCubic { control1X: 15.7 * root.k;  control1Y: 19.6 * root.k
                  control2X: 13.5 * root.k;  control2Y: 17.5 * root.k
                  x: 13.5 * root.k;          y: 14.5 * root.k }
    }
  }
}
