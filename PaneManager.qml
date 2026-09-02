import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
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
  // The layout of the active workspace, not the global default: a workspace
  // rule can pin one workspace to scrolling while the rest stay on dwindle.
  property string layout: "dwindle"
  // The tab the panel reopens on. Lives as long as the shell does: a popup
  // that closes on focus loss is reopened to carry on with what you were
  // doing, and a reload is a fresh start.
  property string tab: "panes"
  property string statusMessage: ""
  property bool busy: false

  // ------------------------------------------------------------------ scope
  //
  // Three settings are answered per workspace on top of a global value, so the
  // panel needs to say which of the two a click is editing. `scope` is "all" or
  // a workspace id as a string; the helper's store is the source of truth for
  // what each scope currently holds, while the properties above stay what
  // Hyprland reports right now.
  property var workspaces: []
  property int activeWorkspace: 0
  property var globalValues: ({})
  property var overrides: ({})
  property string scope: "all"

  readonly property bool scopeIsAll: scope === "all"
  // At global scope there is nothing to inherit from, so the third state would
  // be an empty promise: the global value is what "default" means everywhere
  // else.
  // The same set the bar's own workspace widget shows: 1 to 5 always, plus
  // whatever else is open up to 10. Scoping to a workspace that has nothing on
  // it yet is the point — the answer is waiting when you get there.
  readonly property var scopeWorkspaces: {
    var ids = [1, 2, 3, 4, 5]
    for (var i = 0; i < workspaces.length; i++) {
      var id = Number(workspaces[i])
      if (id > 0 && id <= 10 && ids.indexOf(id) < 0) ids.push(id)
    }
    ids.sort(function(left, right) { return left - right })
    return ids
  }

  // Bare numbers: with ten of them the row has no width to spend on saying
  // "ws" ten times. Where you are is underlined rather than spelled out, which
  // is not the same thing as which scope is selected — you can set up 3 from 1.
  readonly property var workspaceOptions: scopeWorkspaces.map(function(id) {
    return {
      value: String(id),
      label: String(id),
      marked: id === activeWorkspace,
      tooltip: id === activeWorkspace ? "Workspace " + id + ", the one you are on" : "Workspace " + id
    }
  })

  readonly property var scopeOptions: scopeIsAll
    ? [{ value: "off", label: "Off" }, { value: "on", label: "On" }]
    : [{ value: "default", label: "Default", tooltip: "Follow the global setting" },
       { value: "off", label: "Off" }, { value: "on", label: "On" }]

  readonly property var settingText: ({
    layout: {
      on: "New panes join a row that scrolls sideways, niri style.",
      off: "New panes split the pane they land in, dwindle style."
    },
    drag: {
      on: "Grab the divider to resize, no modifier held, with a " + grabArea + "px handle.",
      off: "Only SUPER + right drag resizes."
    },
    dropside: {
      on: "Dropping a dragged pane on another tiles it above, below or beside, by cursor position. The half it will take is shaded while you drag.",
      off: "A dropped pane only ever tiles left or right."
    },
    openside: {
      on: "A new pane splits whatever is under the mouse, on the side the mouse is nearest — the same rule dropping one already follows.",
      off: "A new pane always splits the focused one, on the side your config picked. The mouse has no say."
    }
  })

  // The store speaks Hyprland's vocabulary; the switches speak on / off, so a
  // scrolling layout is the layout row's "on".
  function uiValue(key, raw) {
    if (key === "layout") return String(raw) === "scrolling" ? "on" : "off"
    return raw === true ? "on" : "off"
  }
  function cliValue(key, value) {
    if (value === "default") return "default"
    if (key === "layout") return value === "on" ? "scrolling" : "dwindle"
    return value
  }

  // What the global value is, whoever set it — the helper folds ~/.config/hypr/
  // in, so this is never empty.
  function globalOf(key) { return uiValue(key, globalValues ? globalValues[key] : undefined) }

  // What the current scope holds: at workspace scope, "default" means the
  // workspace has no answer of its own and takes the global one.
  function storedOf(key) {
    if (scopeIsAll) return globalOf(key)
    var ws = overrides ? overrides[scope] : undefined
    if (!ws || ws[key] === undefined) return "default"
    return uiValue(key, ws[key])
  }
  function effectiveOf(key) {
    var v = storedOf(key)
    return v === "default" ? globalOf(key) : v
  }

  function badgeOf(key) {
    if (scopeIsAll) return "ALL"
    return storedOf(key) === "default"
      ? "DEFAULT · " + globalOf(key).toUpperCase()
      : "WS " + scope
  }

  function describe(key) {
    var text = settingText[key][effectiveOf(key)]
    if (scopeIsAll || storedOf(key) !== "default") return text
    return "Follows the global setting: " + text.charAt(0).toLowerCase() + text.slice(1)
  }

  // A workspace on the scrolling layout has no split tree, so the row that
  // depends on splitting says so rather than pretending to work.
  readonly property bool scopeScrolling: effectiveOf("layout") === "on"

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

  // One entry point for the three scoped settings: the scope picker decides
  // where the value lands, and "default" is the absence of one rather than a
  // value — at workspace scope it hands the answer back to the global setting,
  // at global scope back to ~/.config/hypr/.
  function setScoped(key, value) {
    var args = ["set", key, cliValue(key, value)]
    args = args.concat(scopeIsAll ? ["--all"] : ["--workspace", scope])
    if (key === "drag") args = args.concat(["--grab", String(grabArea)])
    run(args)
  }
  function setBorderSize(px) { run(["border", String(px)]) }
  function setCorners(style) { run(["corners", style === "round" ? String(roundedRadius) : "0"]) }
  // `drag` and the drop side are global options in Hyprland: a per-workspace
  // answer only exists while that workspace has focus, so it is written on the
  // way in. Cheap enough to run on every switch, and it never reloads.
  function applyActive() { run(["apply", "--grab", String(grabArea)]) }
  // `refresh` after every action already repaints the switches, so a reset that
  // drops a scrolling override shows up here as well as on screen.
  function resetWorkspace() { run(["reset"], function() { root.statusMessage = "Current workspace reset" }) }
  function resetAll() { run(["reset", "--all"], function() { root.statusMessage = "All workspaces reset" }) }

  // The drop indicator rides along with the bar widget rather than being a
  // `panel` entry point of its own. Declaring a second kind made the plugin id
  // resolve to that panel, so `omarchy-shell shell toggle <id>` — the documented
  // way to bind a key to this — stopped reaching the bar widget entirely.
  DropIndicator {}

  Component.onCompleted: refresh()
  // The scope resets to the active workspace on every open: a sticky "all" is
  // how you change every workspace while believing you are changing this one.
  onOpenedChanged: if (opened) { statusMessage = ""; scope = String(activeWorkspace); refresh() }

  // Hyprland has no per-workspace resize_on_border or drop side, so the values
  // the store holds for a workspace are written when it takes focus. Debounced:
  // holding a workspace key walks through several in a row.
  readonly property var focusedWorkspace: Hyprland.focusedWorkspace
  onFocusedWorkspaceChanged: applyTimer.restart()

  Timer {
    id: applyTimer
    interval: 120
    onTriggered: {
      if (root.busy) { restart(); return }
      root.applyActive()
    }
  }

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
          root.layout = String(parsed.layout || "dwindle")
          root.workspaces = parsed.workspaces || []
          root.activeWorkspace = Number(parsed.activeWorkspace) || 0
          root.globalValues = parsed.global || ({})
          root.overrides = parsed.overrides || ({})
          // A scope pointing at a workspace the picker stopped showing would
          // edit a store entry nobody can see, so it falls back to where you are.
          if (root.scope !== "all" && root.scopeWorkspaces.indexOf(Number(root.scope)) < 0)
            root.scope = String(root.activeWorkspace)
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

      // Runs on every workspace change, so it stays out of everything below:
      // the panel is usually closed, and nothing it touches is themed.
      if (helperProc.action === "apply") {
        if (root.opened) Qt.callLater(root.refresh)
        return
      }

      if (helperProc.action !== "state") {
        // Actions print nothing, so read the state back to catch up. `reset` in
        // particular reloads the Hyprland config and can change everything.
        Qt.callLater(root.refresh)

        // The shell mirrors decoration:rounding into Style.cornerRadius, but
        // only re-reads it at startup and on a theme change — so without this
        // its own panels keep the old corners after Corners is switched, and
        // the panel saying "Square" is itself still round. Debounced upstream.
        Style.scheduleRefresh()
      }
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
                : "WS " + root.activeWorkspace + " · " + root.layout.toUpperCase()
                  + " · " + root.borderSize + "PX BORDER"
              color: Qt.darker(root.barForeground, 1.4)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.1
              elide: Text.ElideRight
            }
          }
        }

        // Scope picker. Above the tab strip rather than inside a tab: it scopes
        // the pane settings, and a control that governs the panel has to stay
        // visible from every tab or it gets set once and forgotten.
        //
        // Two groups of chips rather than one row with `all` on the end: `all`
        // is not another workspace, and reading it as one is how you change
        // every workspace meaning to change this one. A Flow, not the shell's
        // ButtonGroup, because the workspace list is however many are open and
        // a Row of them would run off the panel.
        Group {
          Layout.fillWidth: true
          label: "APPLY TO"
          badge: root.scopeIsAll ? "ALL" : "WS " + root.scope
          description: root.scopeIsAll
            ? "Changing a setting here changes it everywhere, and drops the workspaces' own answers."
            : "Scopes the pane settings to workspace " + root.scope + ". Border is session-wide and ignores this."
          foreground: root.barForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

          Flow {
            Layout.fillWidth: true
            Layout.topMargin: Style.spacing.xs
            spacing: Style.spacing.md

            Segmented {
              options: root.workspaceOptions
              value: root.scopeIsAll ? "" : root.scope
              enabled: !root.busy
              foreground: root.barForeground
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onChanged: function(v) { root.scope = v }
            }

            Segmented {
              options: [{ value: "all", label: "all", tooltip: "The value every workspace falls back to" }]
              value: root.scopeIsAll ? "all" : ""
              enabled: !root.busy
              foreground: root.barForeground
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onChanged: function(v) { root.scope = "all" }
            }
          }
        }

        Tabs {
          Layout.fillWidth: true
          options: [
            { value: "panes", label: "Panes", tooltip: "How panes split, resize and land when you drag one" },
            { value: "border", label: "Border", tooltip: "Border thickness and corner style" },
            { value: "reset", label: "Reset", tooltip: "Put a mangled layout back" }
          ]
          value: root.tab
          foreground: root.barForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          onChanged: function(v) { root.tab = v }
        }

        // The three tabs. Plain visibility rather than a Loader: the panel is
        // small, so keeping every tab built makes switching cost nothing and
        // rebuilds nothing on the way back.
        ColumnLayout {
          Layout.fillWidth: true
          visible: root.tab === "panes"
          spacing: Style.space(12)

          // No caption above these four: titled rows say what the tab holds
          // better than a sentence repeating the tab's name.
          ScopedSetting {
            Layout.fillWidth: true
            label: "Scrolling layout"
            badge: root.badgeOf("layout")
            description: root.describe("layout")
            options: root.scopeOptions
            value: root.storedOf("layout")
            interactive: !root.busy
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            onChanged: function(v) { root.setScoped("layout", v) }
          }

          ScopedSetting {
            Layout.fillWidth: true
            label: "Drag the border"
            badge: root.badgeOf("drag")
            description: root.describe("drag")
            options: root.scopeOptions
            value: root.storedOf("drag")
            interactive: !root.busy
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            onChanged: function(v) { root.setScoped("drag", v) }
          }

          // Above its twin because opening comes before dragging in a pane's
          // life, and because the pair is one rule read twice: `any side` is
          // this panel's word for "four directions, by the cursor".
          ScopedSetting {
            Layout.fillWidth: true
            label: "Open to any side"
            badge: root.badgeOf("openside")
            description: root.scopeScrolling
              ? "Not available while this scope is on the scrolling layout: a new pane joins the row rather than splitting anything."
              : root.describe("openside")
            options: root.scopeOptions
            value: root.scopeScrolling ? "off" : root.storedOf("openside")
            interactive: !root.busy && !root.scopeScrolling
            opacity: root.scopeScrolling ? 0.45 : 1
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            onChanged: function(v) { root.setScoped("openside", v) }
          }

          ScopedSetting {
            Layout.fillWidth: true
            label: "Drop to any side"
            badge: root.badgeOf("dropside")
            description: root.scopeScrolling
              ? "Not available while this scope is on the scrolling layout: a dropped pane joins the row rather than splitting anything."
              : root.describe("dropside")
            options: root.scopeOptions
            // Reads off on a scrolling workspace even when the option is on:
            // the row describes what the workspace does, and it does not do
            // this. The stored value is left alone, so it comes back with
            // dwindle.
            value: root.scopeScrolling ? "off" : root.storedOf("dropside")
            interactive: !root.busy && !root.scopeScrolling
            // `interactive` alone blocks the click but looks untouched, so the
            // whole group — rail included — dims at the shell's own 0.45 to
            // say why it stopped responding.
            opacity: root.scopeScrolling ? 0.45 : 1
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            onChanged: function(v) { root.setScoped("dropside", v) }
          }
        }

        // No label on this group or the next: the tab already carries the name,
        // and a group repeating it titles the same thing twice. What a tab name
        // cannot say — the scope, and that a reset is also the way out of the
        // scrolling layout — stays as the description.
        Group {
          Layout.fillWidth: true
          visible: root.tab === "border"
          badge: "EVERY WORKSPACE"
          description: "Hyprland keeps one border for the whole session, so this is not scoped."
          foreground: root.barForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

          RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Style.spacing.xs
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

              Segmented {
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
        }

        Group {
          Layout.fillWidth: true
          visible: root.tab === "reset"
          description: "Puts the layout and the default split ratios back — also the way out of the scrolling layout."
          foreground: root.barForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

          Button {
            Layout.fillWidth: true
            Layout.topMargin: Style.spacing.xs
            text: "Reset this workspace"
            iconText: "󰑓"
            leftAlign: true
            bordered: true
            focusable: true
            enabled: !root.busy
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            tooltipText: "Restore the layout and the default split ratios on the active workspace"
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
            tooltipText: "Restore the layout and the default split ratios everywhere, and reload border settings"
            onClicked: root.resetAll()
          }
        }
      }
    }
  }
}
