import QtQuick
import qs.Commons

// A screen in one of Hyprland's tiled layouts, small enough to sit on a
// button: the panes as rectangles, the focused one in accent. Rectangles
// rather than an icon font because no font ships a monocle.
//
// Sized on a 44 x 28 grid and scaled with the shell's spacing so it keeps
// step with the text beside it. Each pane is { x, y, w, h } on that grid.
Item {
  id: root

  // dwindle | scrolling | master | monocle
  property string layout: "dwindle"
  property color foreground: Color.foreground
  property color accent: Color.accent
  // On a filled tile the accent pane would vanish into the fill, so it flips
  // to the tile's own text colour, the way the label does.
  property bool selected: false

  readonly property real unit: Style.spaceReal(1)
  implicitWidth: 44 * unit
  implicitHeight: 28 * unit

  // Focused pane first. `back` panes are the ones behind in monocle, drawn
  // fainter; `cut` panes run off the edge in scrolling, saying the row goes on.
  readonly property var panes: ({
    dwindle: [
      { x: 1, y: 1, w: 19, h: 26, focus: true },
      { x: 22, y: 1, w: 21, h: 12 },
      { x: 22, y: 15, w: 9, h: 12 },
      { x: 33, y: 15, w: 10, h: 5 },
      { x: 33, y: 22, w: 10, h: 5 }
    ],
    scrolling: [
      { x: 17, y: 1, w: 16, h: 26, focus: true },
      { x: 1, y: 1, w: 14, h: 26 },
      { x: 35, y: 1, w: 14, h: 26, cut: true }
    ],
    master: [
      { x: 1, y: 1, w: 24, h: 26, focus: true },
      { x: 27, y: 1, w: 16, h: 7.5 },
      { x: 27, y: 10.25, w: 16, h: 7.5 },
      { x: 27, y: 19.5, w: 16, h: 7.5 }
    ],
    monocle: [
      { x: 11, y: 0.5, w: 32, h: 20, back: 2 },
      { x: 6, y: 3.75, w: 32, h: 20, back: 1 },
      { x: 1, y: 7, w: 32, h: 20, focus: true }
    ]
  })

  readonly property color paneColor: root.selected
    ? Qt.rgba(0, 0, 0, 0.25)
    : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
  readonly property color paneBorder: root.selected
    ? Qt.rgba(0, 0, 0, 0.35)
    : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.35)
  readonly property color focusColor: root.selected
    ? Style.selectedStateColor(root.foreground, root.accent)
    : root.accent

  clip: true

  Repeater {
    model: root.panes[root.layout] || root.panes.dwindle

    Rectangle {
      required property var modelData
      x: modelData.x * root.unit
      y: modelData.y * root.unit
      width: modelData.w * root.unit
      height: modelData.h * root.unit
      radius: Math.max(1, 1.5 * root.unit)
      // Monocle: further back, fainter.
      opacity: modelData.back === 2 ? 0.45 : modelData.back === 1 ? 0.7 : 1
      color: modelData.focus ? Qt.rgba(root.focusColor.r, root.focusColor.g, root.focusColor.b, 0.8) : root.paneColor
      border.width: Math.max(1, root.unit)
      border.color: modelData.focus ? root.focusColor : root.paneBorder
    }
  }
}
