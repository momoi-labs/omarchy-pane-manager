# 1. Answer the pane settings per workspace

- Status: accepted
- Date: 2026-08-31

## Context

The panel's switches were global. Turning on the scrolling layout, border
dragging or the four-way drop applied to every workspace at once — and the one
setting Hyprland does track per workspace, the layout, was flattened to match,
because a layout you have to set workspace by workspace felt like a chore rather
than a setting.

That answer stops holding once workspaces are used for different kinds of work.
A workspace holding a browser and a terminal wants dwindle splits; one holding a
long row of editors wants the scrolling layout. Neither can win while there is a
single value.

Hyprland does not treat the three settings alike:

- `layout` is genuinely per workspace, as a workspace rule. Omarchy persists it
  in `~/.local/state/omarchy/workspace-layouts/<id>.lua`, replayed on reload.
- `general:resize_on_border` and `dwindle:precise_mouse_move` are single global
  options. There is no per-workspace form of either.
- `general:border_size`, `decoration:rounding` and
  `general:extend_border_grab_area` are also global, and are chrome rather than
  behaviour.

A second problem sits underneath: `hyprctl getoption` answers with the value in
force, not the one in the config. These are exactly the options this plugin
overwrites at runtime, so "what did the user configure?" has no reliable answer
once the plugin has written anything.

## Decision

The panel gained an **Apply to** scope picker — a workspace, or `all` — and each
of the three behaviour switches gained a third state.

- **Scoped**: Scrolling layout, Drag the border, Drop to any side.
- **Global**: thickness, corners, grab area. Chrome, and Hyprland has no
  per-workspace notion of them either, so pretending otherwise would be a lie
  the plugin has to maintain.
- **Default** is not a value but the absence of one. At workspace scope it hands
  the answer back to the global value; at global scope back to
  `~/.config/hypr/`. Without it, a two-state switch can create an override but
  never drop one, and the only way back would be a reset that takes everything
  with it.
- Setting a value at `all` scope clears the workspaces' own answers for that
  setting. `all` says "everywhere"; leaving an override standing would make the
  panel lie about what is in force.
- The scope resets to the active workspace every time the panel opens. A sticky
  `all` is how you change every workspace believing you are changing one.

Because the two global options have no per-workspace form, a per-workspace value
means *write it when that workspace takes focus*. The panel watches
`Hyprland.focusedWorkspace` and runs `pane-manager apply`, which writes the
effective values for the workspace being entered. Nothing there reloads: a
reload on every workspace change would throw away the border chrome set at
runtime.

The store lives in `~/.local/state/omarchy/pane-manager/`:

- `global.json` — the value every workspace falls back to
- `overrides.json` — `{ "<ws>": { "<key>": value } }` for the ones that disagree
- `config.json` — a snapshot of what `~/.config/hypr/` asked for, taken while
  the values are still untouched and again after every reload, which is the one
  moment the runtime is known to match the config

The layout keeps using Omarchy's store rather than a second one of our own, so
this switch and `omarchy-hyprland-workspace-layout-toggle` stay in agreement.
Workspace rules are only written when someone actually chose a layout: pinning a
workspace to the value it was already falling back to would quietly outlive a
later edit to the config.

Both resets delete the store. Reset is the way back to `~/.config/hypr/`, and it
would not be if the plugin's own answers survived it.

## Consequences

- The plugin now drives global Hyprland state continuously rather than only when
  you click something. If the bar widget is not loaded, per-workspace values for
  drag and drop side stop being applied — the layout still holds, because
  Hyprland owns that one.
- Every workspace change spawns the helper. It is a few `hyprctl` calls and no
  reload, and it is debounced, so holding a workspace key does not run it once
  per workspace passed through.
- The config snapshot can go stale: editing `~/.config/hypr/` and reloading by
  hand leaves the plugin believing the old defaults until a reset or a reload it
  performs itself. Reset is documented as the way to re-read the config.
- Two states per switch would have been simpler to draw and to explain. The
  third state is the cost of being able to say "no answer of its own", which is
  what makes an override droppable one setting at a time.

## Alternatives considered

- **Scope only the layout, keep the rest global.** Honest about what Hyprland
  offers and needs no focus listener, but it splits the panel into two classes of
  switch for a reason the user has no way to see.
- **Three states with no scope picker**, editing the active workspace only. Less
  UI, but then the global value can only be reached from a workspace that has no
  override, which is a rule nobody can guess.
- **Two states plus a per-row "clear override" affordance.** Same expressiveness,
  but the state of a row then lives in two controls instead of one.
- **A separate daemon for the focus listener.** The bar widget is always loaded
  and already owns a long-running helper for the drop indicator; a second process
  would add a lifecycle to manage for no behaviour that is not already available.
