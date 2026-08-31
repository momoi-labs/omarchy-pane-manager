import QtQuick
import QtQuick.Layouts
import qs.Ui
import qs.Commons

// One setting that can be answered per workspace: title, a badge saying where
// the current value comes from, the description, and a ButtonGroup carrying the
// states. Same surface as the shell's Toggle — this is that row with the switch
// swapped for a segmented control, because a switch has no way to say "no
// answer of my own, follow the global one".
//
// The group is the only interactive part: unlike Toggle, the row does not take
// the click, since a three-state control has no obvious "next" for a stray
// click on the description.
BorderSurface {
  id: root

  property string label: ""
  property string description: ""
  // Empty hides it. Short and upper-cased by the caller: "DEFAULT · ON", "WS 4".
  property string badge: ""
  property var options: []
  property string value: ""
  property bool interactive: true

  property color foreground: Color.foreground
  property color accent: Color.accent
  property string fontFamily: Style.font.family

  signal changed(string value)

  implicitHeight: content.implicitHeight + Style.spacing.huge
  implicitWidth: Style.space(240)
  radius: Style.cornerRadius

  color: Style.controlFill(false, false, foreground, accent)
  borderSpec: Border.controlSpec("normal", foreground, accent)

  ColumnLayout {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: root.borderLeft + Style.spacing.rowPaddingX
    anchors.rightMargin: root.borderRight + Style.spacing.rowPaddingX
    spacing: Style.spacing.xs

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.spacing.md

      Text {
        text: root.label
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
        elide: Text.ElideRight
        Layout.fillWidth: true
      }

      Text {
        visible: root.badge !== ""
        text: root.badge
        color: Qt.darker(root.foreground, 1.6)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1.1
      }
    }

    Text {
      visible: root.description !== ""
      text: root.description
      color: Qt.darker(root.foreground, 1.5)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    Segmented {
      Layout.topMargin: Style.spacing.xs
      enabled: root.interactive
      options: root.options
      value: root.value
      foreground: root.foreground
      accent: root.accent
      fontFamily: root.fontFamily
      onChanged: function(v) { root.changed(v) }
    }
  }
}
