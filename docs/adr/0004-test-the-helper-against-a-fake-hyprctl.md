# 4. Test the helper against a fake hyprctl

- Status: accepted
- Date: 2026-09-22

## Context

The plugin had no tests. Every change was checked by hand: open the panel,
click, look. That held while the panel had three global switches. It stopped
holding once settings gained a scope (ADR 0001) and a fourth answer (ADR
0003): the number of states to click through grew faster than anyone would
click, and regressions started shipping. The one that prompted this ADR: the
panel opened on workspace 2 with the scope on workspace 1, so every click
edited the wrong workspace.

The plugin is two things that are hard to test in different ways:

- `bin/pane-manager`, bash and jq, talking to Hyprland through `hyprctl`.
  All the scope logic lives here: which file a value lands in, when a
  workspace rule is written, when a reload is due, what `default` means at
  each scope.
- `PaneManager.qml`, a Quickshell component that only loads inside Omarchy's
  shell, on a live Wayland session, with the shell's own `qs.Ui` modules.
  There is no headless runner for it.

## Decision

The helper is tested automatically. The panel is checked live, by a script,
with a screenshot as the result.

**`tests/run`** runs bash functions from `tests/*.test.sh` with a fresh `HOME`
and `XDG_STATE_HOME` for each, and `tests/fake/hyprctl` first on `PATH`. The
fake answers the read-only queries (`getoption`, `activeworkspace`,
`workspaces`, `clients`, `activewindow`) from a JSON file the test can edit,
and records every call. Tests assert on two things: the store the helper
left behind, and the calls it made. Nothing models what Hyprland would do
with those calls. A test that needs the compositor to have changed state
edits the JSON itself and says so.

The fake is deliberately thin. Parsing the Lua the helper emits, so that a
`workspace_rule` eval updates `tiledLayout`, would be a second implementation
of Hyprland to keep in step with the first. Asserting that the call was made,
with those arguments, is what the helper is responsible for.

**`tests/live [workspace]`** swaps the plugin symlink to the checkout,
restarts the shell, focuses the workspace, opens the panel and screenshots
it, then puts everything back. The check is by eye: the header says where you
are, the APPLY TO badge says what a click would edit, and they must agree.
The regression above is exactly this shot.

No new dependency: the runner needs bash and jq, which the helper already
needs. No bats, no shellcheck, no Qt test runner.

A bug fix comes with a test in whichever layer can see it. The panel's pure
derivations (`storedOf`, `effectiveOf`, `badgeOf`, `describe`) stay in QML
for now; if they grow, they move to a `.js` library the QML imports and node
runs, and the fake compositor stays where it is.

## Consequences

- `tests/run` is the check before a commit to `bin/pane-manager`, and takes
  about a second.
- A change to what the helper asks Hyprland for shows up as a failing
  `assert_called`, which is the point: the calls are the contract.
- The fake does not catch a call Hyprland would refuse. Those still need a
  real compositor, and `tests/live` or the CLI on a real session.
- The panel's glue (timers, the `Process`, what happens on open) has no
  automated check. `tests/live` covers the one path that has already bitten;
  more of it means more scenarios in that script, not a QML test harness.
