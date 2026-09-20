# 3. The layout row picks among Hyprland's layouts

- Status: accepted
- Date: 2026-09-20

## Context

Hyprland 0.56 ships four tiled layouts: `dwindle`, `scrolling`, `master` and
`monocle`. The panel's layout row knew two. It was a switch called **Scrolling
layout**: Off wrote `dwindle`, On wrote `scrolling`, and anything else in force
read as Off.

That held while the only way to leave dwindle was the switch itself. It stops
holding as soon as `~/.config/hypr/` asks for `master`: the workspace is on
master, the row says Off as if it were dwindle, and the two rows that depend on
a split tree stay lit although nothing they write has an effect. The panel can
neither show nor set what the compositor is doing.

Underneath, nothing about the model is two-valued. The row already writes a
workspace rule, and a rule takes any layout name. The store keeps the name. The
helper's `apply` and the resets never look at which layout it is. The only
places that knew "scrolling or not" were the switch, its on/off mapping in the
panel, and the check that greys out the dwindle-only rows.

A prototype (`prototype/scope-model` branch) tried the alternatives on a
simulated workspace before any of this was written.

## Decision

The row is called **Layout** and offers the four layouts as tiles, each with a
small drawing of a screen in that layout, the focused pane in accent.

**Default is not a fifth tile.** At workspace scope, the tile of the global
layout carries a `DEFAULT` pin, and choosing that tile means "follow the
global": it drops the override rather than pinning the workspace to the value
it already falls back to. An inherited choice is drawn tinted, an explicit one
filled. At `all` scope there is no Default (ADR 0001), so the pin is absent.

A fifth tile lost because it competed with the four real answers for the same
row, and because a dashed empty screen said nothing about what Default resolves
to. Drawing the inherited layout inside a Default tile was tried and lost too:
two tiles then showed the same picture.

**The dwindle-only rows go quiet for any layout that is not dwindle**, not for
scrolling alone. Open to any side and Drop to any side write `dwindle:*`
options; master and monocle read them no more than scrolling does.

**The helper accepts all four names.** `set layout <name>` takes `dwindle`,
`scrolling`, `master`, `monocle` or `default`. Nothing else in the helper
changes: the rule, the file in `workspace-layouts/`, the reload on the way back
to Default, and the resets already worked by name.

## Consequences

- The row can now say what is in force when the config, or Omarchy's own
  toggle, chose a layout the switch could not express.
- The legacy `layout <name>` command grows the same two names.
- Master and monocle get no rows of their own. ADR 0002's admission test still
  applies: an option earns a row by explaining a surprise, and this change adds
  none of their options, only the ability to be on them.
- The tile drawings are the plugin's first pictures. They are QML rectangles,
  not icon-font glyphs, because no font ships a monocle.
- The panel grows by one row height, since a tile with a drawing is taller
  than a chip with a word.

## Alternatives considered

- **Keep the switch and add a third state for "other".** Honest about the
  mechanism and useless as a control: it could show master but never choose it.
- **A dropdown.** Fits four names in the space of one, and hides the three not
  chosen, which is where the drawings earn their place: seeing what scrolling
  looks like next to master is the point of showing them at all.
- **Words only, four chips.** Tried in the prototype. `master` and `monocle`
  are not self-describing, and the row had to be read twice.
