import QtQuick
import QtQuick.Layouts
import qs.Ui
import qs.Commons

// A titled section drawn as a rail down its left edge: the line runs the full
// height of what it holds, so where a section starts and ends is drawn rather
// than inferred from a caption floating above it.
//
// Replaces the PanelSectionHeader + PanelSeparator pair for this panel's
// sections, and the box around a single setting: a rail groups without adding
// another border inside the ones the controls already draw.
RowLayout {
  id: root

  // The caller's children land in the body column, under the header. The rail
  // and the header itself are assigned through `data` below, or this alias
  // would swallow them too.
  default property alias content: body.data

  // Empty hides it. `prominent` picks which of the two things a group can be:
  // a section of the panel, whose label is a tracked-caps caption, or one
  // setting, whose label is its own name and reads as a control's title.
  property string label: ""
  property bool prominent: false
  // Short and upper-cased by the caller: "WS 4", "EVERY WORKSPACE".
  property string badge: ""
  property string description: ""

  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  spacing: Style.spacing.xxl

  data: [
    Rectangle {
      Layout.fillHeight: true
      Layout.preferredWidth: Math.max(2, Style.space(2))
      radius: width / 2
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
    },

    ColumnLayout {
      id: body
      Layout.fillWidth: true
      spacing: Style.spacing.md

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.md
        // Nothing to say and nothing to badge: a group can be just the rail.
        visible: root.label !== "" || root.badge !== "" || root.description !== ""

        Text {
          // A group with no label is one whose tab already titles it. Its
          // description takes the header line rather than sitting under an
          // empty one, so the badge stays beside the text it qualifies.
          text: root.label !== "" ? root.label : root.description
          color: root.label === ""
            ? Qt.darker(root.foreground, 1.5)
            : (root.prominent ? root.foreground : Qt.darker(root.foreground, 1.4))
          font.family: root.fontFamily
          font.pixelSize: root.label !== "" && root.prominent
            ? Style.font.subtitle
            : Style.font.caption
          font.bold: root.label !== ""
          font.letterSpacing: (root.label !== "" && !root.prominent) ? 1.1 : 0
          wrapMode: Text.WordWrap
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
          Layout.alignment: Qt.AlignTop
        }
      }

      Text {
        visible: root.label !== "" && root.description !== ""
        text: root.description
        color: Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }
    }
  ]
}
