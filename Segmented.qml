import QtQuick
import qs.Ui
import qs.Commons

// The shell's ButtonGroup drawn as one block: same `options` / `value` /
// `changed` API, but the chips share their edges instead of standing apart —
// negative spacing folds the two 1px borders into a single seam, and only the
// outer corners keep the theme's radius.
//
// Worth the copy because the two say different things. A row of separate
// buttons reads as several actions; a segmented control reads as one question
// with N answers, which is what a scope and a three-state setting both are.
//
// Keyboard behaviour is ButtonGroup's, kept so the group stays a single Tab
// stop that h / l walks inside.
Row {
  id: root

  property var options: []
  property string value: ""
  property color foreground: Color.foreground
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  property real fontSize: Style.font.body
  property bool focusable: true

  signal changed(string value)

  readonly property real _radius: Style.cornerRadius
  // One border width, so the seam between two chips is a line rather than two.
  readonly property real _seam: Math.max(1, Style.normalBorderWidth)
  property int _focusedIndex: -1

  spacing: -_seam
  activeFocusOnTab: focusable

  function optionValue(o) { return (o && typeof o === "object") ? String(o.value) : String(o) }
  function optionLabel(o) { return (o && typeof o === "object" && o.label !== undefined) ? String(o.label) : String(o) }
  function optionTooltip(o) { return (o && typeof o === "object" && o.tooltip) ? String(o.tooltip) : "" }
  // A second, orthogonal state: `marked` says "this one is current" about the
  // world, while `value` says "this one is chosen" about the control. Painted
  // as an underline so it never competes with the selected chip's fill.
  function optionMarked(o) { return !!(o && typeof o === "object" && o.marked) }

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

  Repeater {
    model: root.options

    delegate: Button {
      required property var modelData
      required property int index

      readonly property bool isFirst: index === 0
      readonly property bool isLast: index === root.options.length - 1

      text: root.optionLabel(modelData)
      tooltipText: root.optionTooltip(modelData)
      selected: root.optionValue(modelData) === root.value
      hasCursor: root.activeFocus && root._focusedIndex === index
      bordered: true

      // Square where chips meet, rounded where the group ends.
      radius: 0
      topLeftRadius: isFirst ? root._radius : 0
      bottomLeftRadius: isFirst ? root._radius : 0
      topRightRadius: isLast ? root._radius : 0
      bottomRightRadius: isLast ? root._radius : 0
      // The chip that is filled owns the seam on both its sides, or its fill
      // would be cut by whichever neighbour happens to paint last.
      z: selected || hasCursor ? 1 : 0

      foreground: root.foreground
      accent: root.accent
      fontFamily: root.fontFamily
      fontSize: root.fontSize
      onClicked: root.changed(root.optionValue(modelData))

      Rectangle {
        visible: root.optionMarked(parent.modelData)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(2, Style.space(3))
        width: Math.max(Style.space(12), parent.width * 0.4)
        height: Math.max(1, Style.space(2))
        radius: height / 2
        color: root.accent
      }
    }
  }
}
