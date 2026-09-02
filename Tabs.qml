import QtQuick
import QtQuick.Layouts
import qs.Ui
import qs.Commons

// Underline tab strip: the panel's sections one keystroke apart instead of one
// scroll apart. Same `options` / `value` / `changed` API as Segmented, and the
// same keyboard grammar — one Tab stop, h / l and arrows walk inside, Enter or
// Space activates — because a panel with two ways to move between chips would
// be a panel with two things to learn.
//
// Underlined rather than segmented on purpose: the scope picker right above is
// a Segmented, and tabs are navigation, not an answer to a question.
Item {
  id: root

  property var options: []
  property string value: ""
  property color foreground: Color.foreground
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  property real fontSize: Style.font.body
  property bool focusable: true

  signal changed(string value)

  implicitWidth: strip.implicitWidth
  implicitHeight: strip.implicitHeight
  activeFocusOnTab: focusable

  property int _focusedIndex: -1

  function optionValue(o) { return (o && typeof o === "object") ? String(o.value) : String(o) }
  function optionLabel(o) { return (o && typeof o === "object" && o.label !== undefined) ? String(o.label) : String(o) }
  function optionTooltip(o) { return (o && typeof o === "object" && o.tooltip) ? String(o.tooltip) : "" }

  function selectedOptionIndex() {
    for (var i = 0; i < options.length; i++)
      if (optionValue(options[i]) === value) return i
    return -1
  }

  onActiveFocusChanged: {
    if (!activeFocus) { _focusedIndex = -1; return }
    var idx = selectedOptionIndex()
    _focusedIndex = idx < 0 ? 0 : idx
  }

  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.text === "h") {
      _focusedIndex = Math.max(0, (_focusedIndex < 0 ? 0 : _focusedIndex) - 1)
      event.accepted = true
    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.text === "l") {
      _focusedIndex = Math.min(options.length - 1, (_focusedIndex < 0 ? 0 : _focusedIndex) + 1)
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
      if (_focusedIndex >= 0 && _focusedIndex < options.length)
        root.changed(optionValue(options[_focusedIndex]))
      event.accepted = true
    }
  }

  Column {
    id: strip
    width: parent.width
    spacing: 0

    Row {
      spacing: Style.spacing.huge

      Repeater {
        model: root.options

        delegate: Item {
          id: tab

          required property var modelData
          required property int index

          readonly property bool selected: root.optionValue(modelData) === root.value
          readonly property bool hot: mouse.containsMouse || (root.activeFocus && root._focusedIndex === index)

          width: label.implicitWidth
          height: label.implicitHeight + Style.spacing.lg + underline.height

          Text {
            id: label
            text: root.optionLabel(tab.modelData)
            color: tab.selected || tab.hot ? root.foreground : Qt.darker(root.foreground, 1.6)
            font.family: root.fontFamily
            font.pixelSize: root.fontSize
            font.bold: tab.selected
          }

          // Sits on the rule below, so the selected tab owns that slice of the
          // line rather than being underlined twice.
          Rectangle {
            id: underline
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.max(2, Style.space(2))
            visible: tab.selected || tab.hot
            color: tab.selected ? root.accent : Qt.darker(root.foreground, 1.8)
          }

          MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.changed(root.optionValue(tab.modelData))
          }

          PanelToolTip {
            text: root.optionTooltip(tab.modelData)
            visible: text !== "" && mouse.containsMouse
          }
        }
      }
    }

    PanelSeparator { width: strip.width; foreground: root.foreground }
  }
}
