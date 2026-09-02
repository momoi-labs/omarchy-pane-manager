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
// Drawn as a Group rather than a bordered card: the setting is already inside
// a tab, and boxing every row put a border around a control that draws its own.
// The rail carries the row instead.
Group {
  id: root

  property var options: []
  property string value: ""
  property bool interactive: true
  property color accent: Color.accent

  signal changed(string value)

  prominent: true

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
