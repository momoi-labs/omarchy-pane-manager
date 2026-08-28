import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// Fullscreen, click-through overlay that shades the half of a pane a dragged
// window would land in. The detection and the geometry live in
// bin/drop-indicator; this only paints what that reports.
Item {
  id: root

  property QtObject bar: null
  property string moduleName: "me.swebber.pane-manager"
  property var settings: ({})

  readonly property string helper: Quickshell.env("HOME") + "/.config/omarchy/plugins/me.swebber.pane-manager/bin/drop-indicator"

  property bool dragging: false
  property string direction: ""
  property real dropX: 0
  property real dropY: 0
  property real dropW: 0
  property real dropH: 0

  function apply(line) {
    var text = String(line || "").trim()
    if (text === "") return
    var data
    try { data = JSON.parse(text) } catch (e) { return }
    if (data.dragging !== true) {
      root.dragging = false
      return
    }
    root.direction = String(data.dir || "")
    root.dropX = Number(data.x) || 0
    root.dropY = Number(data.y) || 0
    root.dropW = Number(data.w) || 0
    root.dropH = Number(data.h) || 0
    root.dragging = true
  }

  Process {
    running: true
    command: [root.helper]
    stdout: SplitParser { onRead: function(data) { root.apply(data) } }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: surface
      required property var modelData

      screen: modelData
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      WlrLayershell.namespace: "omarchy-drop-indicator"

      // Empty input region: the overlay must never receive a pointer event, or
      // it would swallow the very drag it is drawing.
      mask: Region {}

      anchors { top: true; left: true; right: true; bottom: true }
      visible: root.dragging

      Rectangle {
        // Reported coordinates are global; a PanelWindow is placed at its own
        // screen's origin.
        x: root.dropX - surface.screen.x
        y: root.dropY - surface.screen.y
        width: root.dropW
        height: root.dropH

        color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
        border.width: Math.max(2, Style.space(2))
        border.color: Color.accent
        radius: Style.cornerRadius

        Behavior on x { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
      }
    }
  }
}
