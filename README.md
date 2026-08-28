# Pane Manager

An [Omarchy](https://omarchy.org/) shell plugin for managing tiled panes from
the bar: resize them by dragging the divider with your mouse, set the border
thickness and corner style, and put a mangled layout back the way it was.

![Pane Manager panel](preview.png)

## Why

Hyprland already ships modifier-driven mouse resize, and Omarchy binds it out of
the box:

| Binding | Action |
|---|---|
| `SUPER` + drag left button | Move window |
| `SUPER` + drag right button | Resize window |

What it leaves off is `general:resize_on_border`, which lets you grab the
divider between two tiled panes directly, the way panes work in an IDE. This
plugin turns that on from the bar, puts the border chrome that goes with it in
the same place, and — because a resized dwindle tree has no built-in undo —
gives you a way to reset the split ratios.

## The panel

Left-clicking the bar icon opens it.

- **Drag the border** — `general:resize_on_border` on and off.
  Turning it **off hands everything back to the system**: the border thickness,
  corner radius and grab area all revert to whatever `~/.config/hypr/` says.
- **Thickness** — border width in px (`general:border_size`)
- **Corners** — Square or Round (`decoration:rounding`)
- **Reset this workspace** / **Reset all workspaces** — restore default split
  ratios, then reload the config

Everything the panel changes is runtime-only, so the two resets and the off
switch are all reliable ways back to your configured state.

## Install

```bash
omarchy plugin add https://github.com/<you>/omarchy-pane-manager.git --enable
```

Requires `jq` and Omarchy 4 (Quattro) or newer.

## Persisting the setting

To have drag-the-border on at every login, put it in
`~/.config/hypr/looknfeel.lua`:

```lua
hl.config({
  general = {
    resize_on_border = true,
    -- Pixels beyond the drawn border that still count as the handle. Larger is
    -- easier to grab; too large starts stealing clicks near a pane's edges.
    extend_border_grab_area = 10,
    -- Cursor changes shape over the handle, so the affordance is discoverable.
    hover_icon_on_border = true,
  },
})
```

## Settings

In `~/.config/omarchy/shell.json`:

```json
{ "id": "me.swebber.pane-manager", "grabArea": 10, "roundedRadius": 8, "maxBorderSize": 12 }
```

| Key | Default | What it does |
|---|---|---|
| `grabArea` | `10` | Grab area in px applied when the switch turns resizing on |
| `roundedRadius` | `8` | Corner radius applied by the Round option |
| `maxBorderSize` | `12` | Upper bound of the thickness field |

## CLI

The helper is usable on its own — handy for a keybinding:

```bash
BIN=~/.config/omarchy/plugins/me.swebber.pane-manager/bin/pane-manager
$BIN state                # JSON: enabled, grabArea, borderSize, rounding
$BIN enable [grabArea]
$BIN disable              # also reverts border chrome to your config
$BIN toggle [grabArea]
$BIN border <px>
$BIN corners <px>         # 0 = square
$BIN reset [--all]
```

## Notes for hackers

Omarchy 4 runs Hyprland's Lua config parser, which retires the legacy `hyprctl`
forms. Anything poking at Hyprland from a plugin needs the new spelling:

| Legacy | Omarchy 4 |
|---|---|
| `hyprctl keyword general:border_size 2` | `hyprctl eval 'hl.config({ general = { border_size = 2 } })'` |
| `hyprctl dispatch splitratio +0.1` | `hyprctl dispatch 'hl.dsp.layout("splitratio +0.1")'` (one string, not separate args) |
| — | `hyprctl dispatch 'hl.dsp.focus({ window = "address:0x…" })'` |

Boolean options come back as `.bool` in `hyprctl getoption -j`; `.int` is `null`
for them. The full Lua API is stubbed at `/usr/share/hypr/stubs/hl.meta.lua`.

Three more things worth knowing before you script against Hyprland:

- **`hyprctl` exits 0 when a dispatcher fails.** It prints `error: …` on stdout
  and returns success anyway, so a `set -e` script sails straight past a broken
  dispatch. Check the output.
- **`splitratio` takes a delta, and dwindle has no `exact`** (at least through
  0.56.2 — `splitratio exact 1` answers `failed to parse "exact" as a delta`).
  There is no "set this node to 1.0" message. Ratios clamp to `[0.1, 1.9]`
  though, so `splitratio -5` lands on a known 0.1 and `splitratio +0.9` reaches
  the default. That two-hop is how the reset here works.
- **`fc-query`'s charset can lie about Nerd Font glyphs.** It reported
  `U+F006E` (nf-md-backup_restore) as covered by JetBrainsMono Nerd Font; it
  renders as tofu. Screenshot your widget before trusting a glyph.

## License

MIT
