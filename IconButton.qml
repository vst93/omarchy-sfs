import QtQuick
import qs.Commons
import qs.Ui

// Compact square icon button for panel toolbars and row actions. Mirrors the
// kit's PanelActionButton look (theme hover/selected fills, tooltip) but adds
// the two things this panel needs: a `selected` state (the filter toggle) and
// a `rightClicked` signal (Export config vs. list).
//
// `enabled` gates clicks and dims the glyph; hover and selected states come
// from Style tokens so it stays native under any theme.
BorderSurface {
    id: root

    property string iconText: ""
    property string tooltipText: ""
    property color foreground: Color.foreground
    property color hoverColor: foreground
    property color accent: Color.accent
    property string fontFamily: Style.font.family
    property real fontSize: Style.font.icon
    property real size: Math.max(Style.space(24), fontSize + Style.spacing.lg)
    property bool selected: false
    property bool bordered: false

    signal clicked()
    signal rightClicked()
    signal hovered(bool isHovered)

    implicitWidth: size
    implicitHeight: size
    radius: Style.cornerRadius

    readonly property bool hot: mouse.containsMouse && root.enabled

    color: !root.enabled ? "transparent"
        : mouse.pressed ? Style.pressedFillFor(hoverColor, accent)
        : hot          ? Style.hoverFillFor(hoverColor, accent)
        : selected     ? Style.selectedFillFor(foreground, accent)
        : "transparent"
    borderSpec: selected
        ? Border.controlSpec("selected", foreground, accent)
        : (bordered ? Border.controlSpec("normal", foreground, accent) : Border.none())

    Behavior on color {
        ColorAnimation { duration: 60 }
    }

    Text {
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: root.iconText
        color: !root.enabled
            ? Qt.darker(root.foreground, 2.0)
            : (root.selected ? root.accent : (root.hot ? root.hoverColor : root.foreground))
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onContainsMouseChanged: root.hovered(containsMouse)
        onClicked: function (m) {
            if (m.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
    }

    PanelToolTip {
        visible: root.tooltipText !== "" && mouse.containsMouse
        text: root.tooltipText
        fontFamily: root.fontFamily
    }
}
