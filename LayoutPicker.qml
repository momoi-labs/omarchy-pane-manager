import QtQuick
import qs.Ui
import qs.Commons

// The layout row's control: one tile per layout, each a drawing of a screen in
// that layout, sharing edges the way Segmented's chips do. Same `options` /
// `value` / `changed` API as Segmented, plus:
//
//   `inherited` — the value the scope falls back to when it has no answer of
//   its own. That tile carries a DEFAULT pin, and clicking it sends "default"
//   rather than the layout's name: choosing the layout you already fall back to
//   should drop the override, not pin the workspace to it (ADR 0003).
//
//   `value === "default"` paints the inherited tile as selected, tinted rather
//   than filled, so an answer the scope inherits looks different from one it
//   gave.
//
// Keyboard behaviour is Segmented's: one Tab stop, h / l inside.
Item {
  id: root

  property var options: []          // [{ value, label, tooltip }]
  property string value: ""
  property string inherited: ""     // "" at global scope: nothing to inherit
  property bool enabled: true
  property color foreground: Color.foreground
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  property bool focusable: true

  signal changed(string value)

  readonly property real _radius: Style.cornerRadius
  readonly property real _seam: Math.max(1, Style.normalBorderWidth)
  // Room above the tiles for the pin, which straddles the top edge.
  readonly property real _pinRise: pinMetrics.implicitHeight / 2
  property int _focusedIndex: -1

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight + _pinRise
  activeFocusOnTab: focusable

  function optionValue(o) { return (o && typeof o === "object") ? String(o.value) : String(o) }
  function optionLabel(o) { return (o && typeof o === "object" && o.label !== undefined) ? String(o.label) : String(o) }
  function optionTooltip(o) { return (o && typeof o === "object" && o.tooltip) ? String(o.tooltip) : "" }
  function isInherited(o) { return inherited !== "" && optionValue(o) === inherited }
  function isSelected(o) { return value === "default" ? isInherited(o) : optionValue(o) === value }
  // What a click on this tile means.
  function sendValue(o) { return isInherited(o) ? "default" : optionValue(o) }

  function selectedOptionIndex() {
    for (var i = 0; i < options.length; i++)
      if (isSelected(options[i])) return i
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
        root.changed(sendValue(options[_focusedIndex]))
      event.accepted = true
    }
  }

  // Measured once so the pin's height is known before any tile exists.
  Text {
    id: pinMetrics
    visible: false
    text: "DEFAULT"
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
  }

  Row {
    id: row
    y: root._pinRise
    width: root.width
    spacing: -root._seam

    Repeater {
      model: root.options

      delegate: Button {
        id: tile
        required property var modelData
        required property int index

        readonly property bool isFirst: index === 0
        readonly property bool isLast: index === root.options.length - 1
        readonly property bool inheritedTile: root.isInherited(modelData)
        // Selected by inheritance: tinted, not filled, and the drawing keeps
        // its accent since it is not sitting on an accent fill.
        readonly property bool tinted: root.value === "default" && inheritedTile

        width: (row.width + root._seam * (root.options.length - 1)) / root.options.length
        // Extra room at the top so the pin, which hangs into the tile by half
        // its height, does not sit on the drawing.
        readonly property real pinRoom: root._pinRise + Style.space(4)
        implicitHeight: body.implicitHeight + pinRoom + verticalPadding * 2 + _reservedBorderTop + _reservedBorderBottom

        tooltipText: root.optionTooltip(modelData) + (inheritedTile ? " — the global layout; choosing it means follow the global" : "")
        selected: root.isSelected(modelData) && !tinted
        background: tinted ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"
        hasCursor: root.activeFocus && root._focusedIndex === index
        bordered: true
        enabled: root.enabled
        opacity: root.enabled ? 1 : 0.45

        radius: 0
        topLeftRadius: isFirst ? root._radius : 0
        bottomLeftRadius: isFirst ? root._radius : 0
        topRightRadius: isLast ? root._radius : 0
        bottomRightRadius: isLast ? root._radius : 0
        z: selected || tinted || hasCursor ? 1 : 0

        foreground: root.foreground
        accent: root.accent
        fontFamily: root.fontFamily
        onClicked: root.changed(root.sendValue(modelData))

        Column {
          id: body
          anchors.centerIn: parent
          anchors.verticalCenterOffset: tile.pinRoom / 2
          spacing: Style.spacing.md

          LayoutGlyph {
            anchors.horizontalCenter: parent.horizontalCenter
            layout: root.optionValue(tile.modelData)
            foreground: root.foreground
            accent: root.accent
            selected: tile.selected
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: root.optionLabel(tile.modelData)
            color: tile.selected ? tile._selectedColor : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: tile.selected
          }
        }

        // The pin: sits on the top edge, centred, over the border.
        Rectangle {
          visible: tile.inheritedTile
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.top
          width: pin.implicitWidth + Style.space(10)
          height: pin.implicitHeight + Style.space(2)
          radius: Style.cornerRadius
          color: Color.popups.background
          border.width: Math.max(1, Style.normalBorderWidth)
          border.color: root.accent
          z: 2

          Text {
            id: pin
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "DEFAULT"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.1
          }
        }
      }
    }
  }
}
