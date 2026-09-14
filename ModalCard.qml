import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Ui

// Shared modal shell for the SFS panel — scrim, centred card, a title header
// with a close button, and a body that scrolls when the screen is short.
//
// Callers drop their fields and buttons into the default `body` property; the
// shell owns every piece of chrome so all dialogs look identical. Colors come
// from the theme (Color.popups / Color.foreground), never hardcoded.
FocusScope {
    id: root

    property bool opened: false
    property string title: ""
    property string subtitle: ""
    property color foreground: Color.foreground
    property color dim: Qt.darker(Color.foreground, 1.5)
    property string fontFamily: Style.font.family
    property color scrimColor: Qt.alpha(Color.background, 0.6)
    property string closeTooltip: "Close"

    signal closed()

    // Everything a caller declares inside the modal lands here.
    default property alias body: bodyCol.children

    anchors.fill: parent
    visible: opened
    z: 10
    focus: opened

    // Escape closes the dialog. A focused field declines Escape, so it bubbles
    // up to this scope; every other key is left for the field to consume.
    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape) {
            root.closed();
            event.accepted = true;
        }
    }

    readonly property int pad: Style.space(14)
    readonly property real cardMaxWidth: Math.max(Style.space(180), width - Style.space(32))
    readonly property real cardMaxHeight: Math.max(Style.space(120), height - Style.space(24))
    readonly property real bodyMaxHeight: Math.max(Style.space(48), cardMaxHeight - pad * 2 - header.implicitHeight - Style.space(10))

    // Scrim — click anywhere outside the card to dismiss.
    Rectangle {
        anchors.fill: parent
        color: root.scrimColor

        MouseArea {
            anchors.fill: parent
            onClicked: root.closed()
        }
    }

    BorderSurface {
        id: card
        width: Math.min(root.cardMaxWidth, Style.space(380))
        height: Math.min(root.cardMaxHeight, root.pad * 2 + header.implicitHeight + Style.space(10) + bodyScroll.height)
        anchors.centerIn: parent
        color: Color.popups.background
        borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
        radius: Style.cornerRadius

        // Swallow clicks that land on the card itself.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        // ---- Header ---------------------------------------------------------
        Item {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: root.pad
            anchors.rightMargin: root.pad
            anchors.topMargin: root.pad
            implicitHeight: Math.max(titleCol.implicitHeight, closeBtn.implicitHeight)

            Column {
                id: titleCol
                anchors.left: parent.left
                anchors.right: closeBtn.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    text: root.title
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    visible: root.subtitle !== ""
                    text: root.subtitle
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            PanelActionButton {
                id: closeBtn
                anchors.right: parent.right
                anchors.top: parent.top
                iconText: "\u2715"
                tooltipText: root.closeTooltip
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.closed()
            }
        }

        // ---- Body (scrolls on short screens) --------------------------------
        Flickable {
            id: bodyScroll
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.topMargin: Style.space(10)
            anchors.leftMargin: root.pad
            anchors.rightMargin: root.pad
            height: Math.min(bodyCol.implicitHeight, root.bodyMaxHeight)
            contentWidth: width
            contentHeight: bodyCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            interactive: contentHeight > height
            Controls.ScrollBar.vertical: Controls.ScrollBar {
                policy: Controls.ScrollBar.AsNeeded
            }

            Column {
                id: bodyCol
                width: bodyScroll.width
                spacing: Style.space(8)
            }
        }
    }
}
