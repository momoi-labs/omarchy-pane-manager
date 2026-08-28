import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// Bar widget + panel for managing how tiled panes are sized and framed.
//
// Hyprland already ships modifier-driven mouse resize (SUPER + right drag in
// Omarchy's defaults). What it leaves off is `general:resize_on_border`, which
// lets you grab the divider between two tiled panes directly. This plugin turns
// that on, exposes the border chrome that goes with it, and — because a resized
// dwindle tree has no built-in undo — gives you a way to put the ratios back.
Panel {
  id: root
  moduleName: "dev.momoi-labs.pane-manager"
  ipcTarget: moduleName

  readonly property string helper: Quickshell.env("HOME") + "/.config/omarchy/plugins/" + moduleName + "/bin/pane-manager"
  readonly property int grabArea: Number(setting("grabArea", 10))
  readonly property int roundedRadius: Number(setting("roundedRadius", 8))
  readonly property int maxBorderSize: Number(setting("maxBorderSize", 12))

  property bool dragEnabled: false
  property int activeGrabArea: 0
  property int borderSize: 0
  property int rounding: 0
  property bool dropAnySide: false
  property string statusMessage: ""
  property bool busy: false

  readonly property string icon: "󰕰"  // nf-md-border_all

  function run(args, done) {
    if (busy) return
    busy = true
    helperProc.action = String(args[0] || "")
    helperProc.pendingDone = done || null
    helperProc.command = [helper].concat(args)
    helperProc.running = true
  }

  function refresh() { run(["state"]) }

  // Off does more than flip a flag: it hands the border chrome back to
  // ~/.config/hypr/ as well, so the switch is a clean "plugin, hands off".
  function toggleDrag() { run([dragEnabled ? "disable" : "enable", String(grabArea)]) }
  function setBorderSize(px) { run(["border", String(px)]) }
  function toggleDropAnySide() { run(["dropside", dropAnySide ? "false" : "true"]) }
  function setCorners(style) { run(["corners", style === "round" ? String(roundedRadius) : "0"]) }
  function resetWorkspace() { run(["reset"], function() { root.statusMessage = "Current workspace reset" }) }
  function resetAll() { run(["reset", "--all"], function() { root.statusMessage = "All workspaces reset" }) }

  Component.onCompleted: refresh()
  onOpenedChanged: if (opened) { statusMessage = ""; refresh() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    tooltipText: root.dragEnabled
      ? "Pane Manager — border drag on, " + root.activeGrabArea + "px handle"
      : "Pane Manager — border drag off"
    // Deliberately not bound to `active`: the accent fill reads as an alert,
    // and this widget is a place to go, not a condition to notice. Drag state
    // lives in the tooltip and the panel's own switch.
    onPressed: function(mouseButton) { root.toggle() }
  }

  // One Process, serialized behind `busy`. Only an action re-reads state
  // afterwards — a `state` call must never schedule another one, or the widget
  // spins at ~50 subprocesses a second and `busy` swallows every click.
  Process {
    id: helperProc
    property string action: ""
    property var pendingDone: null

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (raw === "") return
        try {
          var parsed = JSON.parse(raw)
          root.dragEnabled = parsed.enabled === true
          root.activeGrabArea = Number(parsed.grabArea) || 0
          root.borderSize = Number(parsed.borderSize) || 0
          root.rounding = Number(parsed.rounding) || 0
          root.dropAnySide = parsed.dropAnySide === true
        } catch (e) {
          root.statusMessage = "Could not read Hyprland state"
        }
      }
    }
    stderr: StdioCollector { id: helperError; waitForEnd: true }

    onExited: function(exitCode) {
      root.busy = false
      var done = pendingDone
      pendingDone = null

      if (exitCode !== 0) {
        var raw = String(helperError.text || "").trim()
        var message = "Helper failed"
        try { message = JSON.parse(raw).error || message } catch (e) { if (raw !== "") message = raw }
        root.statusMessage = message
        return
      }

      if (done) done()
      // Actions print nothing, so read the state back to catch up. `reset` in
      // particular reloads the Hyprland config and can change everything.
      if (helperProc.action !== "state") Qt.callLater(root.refresh)
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(10)

          Text {
            text: root.icon
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.display
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(2)

            Text {
              Layout.fillWidth: true
              text: "Pane Manager"
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              Layout.fillWidth: true
              text: root.statusMessage !== ""
                ? root.statusMessage
                : (root.dragEnabled
                    ? root.activeGrabArea + "PX HANDLE · " + root.borderSize + "PX BORDER"
                    : "DRAG OFF · " + root.borderSize + "PX BORDER")
              color: Qt.darker(root.barForeground, 1.4)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.1
              elide: Text.ElideRight
            }
          }
        }

        Toggle {
          Layout.fillWidth: true
          // The switch carries the state; the description carries what switching
          // off does, which is more than clearing a flag.
          label: "Drag the border"
          description: root.dragEnabled
            ? "Grab the divider to resize, no modifier held. Switching off restores your Hyprland defaults."
            : "Only SUPER + right drag resizes. Switching on uses a " + root.grabArea + "px handle; switching off restores your Hyprland defaults."
          checked: root.dragEnabled
          enabled: !root.busy
          foreground: root.barForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          onClicked: root.toggleDrag()
        }

        Toggle {
          Layout.fillWidth: true
          label: "Drop to any side"
          description: root.dropAnySide
            ? "Dropping a dragged pane on another tiles it above, below or beside, by cursor position. The half it will take is shaded while you drag."
            : "A dropped pane only ever tiles left or right. Switch on for above and below too, with the landing spot shaded while you drag."
          checked: root.dropAnySide
          enabled: !root.busy
          foreground: root.barForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          onClicked: root.toggleDropAnySide()
        }

        PanelSeparator { Layout.fillWidth: true; foreground: root.barForeground }

        PanelSectionHeader {
          text: "BORDER"
          foreground: root.barForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(16)

          NumberField {
            label: "Thickness (px)"
            value: root.borderSize
            from: 0
            to: root.maxBorderSize
            enabled: !root.busy
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            onModified: function(v) { root.setBorderSize(v) }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Style.spacing.md

            Text {
              text: "Corners"
              color: Qt.darker(root.barForeground, 1.4)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            ButtonGroup {
              Layout.fillWidth: true
              enabled: !root.busy
              options: [
                { value: "square", label: "Square", tooltip: "No corner radius" },
                { value: "round", label: "Round", tooltip: "Rounded corners at " + root.roundedRadius + "px" }
              ]
              value: root.rounding > 0 ? "round" : "square"
              foreground: root.barForeground
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onChanged: function(v) { root.setCorners(v) }
            }
          }
        }

        PanelSeparator { Layout.fillWidth: true; foreground: root.barForeground }

        PanelSeparator { Layout.fillWidth: true; foreground: root.barForeground }

        Button {
          Layout.fillWidth: true
          text: "Reset this workspace"
          iconText: "󰑓"
          leftAlign: true
          bordered: true
          focusable: true
          enabled: !root.busy
          foreground: root.barForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          tooltipText: "Restore default split ratios on the active workspace"
          onClicked: root.resetWorkspace()
        }

        Button {
          Layout.fillWidth: true
          text: "Reset all workspaces"
          iconText: "󰑐"
          leftAlign: true
          bordered: true
          focusable: true
          enabled: !root.busy
          foreground: root.barForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          tooltipText: "Restore default split ratios everywhere, and reload border settings"
          onClicked: root.resetAll()
        }
      }
    }
  }
}
