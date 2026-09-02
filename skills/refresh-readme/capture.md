# Capturing the preview assets

Reached from step 3 of [`refresh-readme`](SKILL.md), for the assets the diff
said were stale. Everything here runs against a live Hyprland session on the
machine — there is no headless path.

Two captures taken months apart should differ only in what actually changed.
That is what the conditions below are for, and it is the bar the result is
judged against: open the asset you are replacing beside the new one and confirm
the only difference is the feature.

## Before anything

- **The plugin has to be dev-linked.** The shell loads
  `~/.config/omarchy/plugins/dev.momoi-labs.pane-manager`, which for local work
  is a symlink to the checkout. Confirm it points at the tree you are shooting
  from — a worktree is not the linked one, so a capture there quietly shows the
  old code. `omarchy-restart-shell` reloads the plugin after a code change.
- **Ask the user before capturing.** Every recipe here drives their real mouse
  and keyboard and covers their screen with test panes. It is their session.
- **Shoot on an empty workspace you set up yourself.** The backdrop shows
  through the panel's dimmed overlay and into the finished asset, so an
  existing workspace puts whatever the user had open — messages, mail, a client
  repo — into a file headed for a public README. Pick an unused id, open two
  neutral windows on it, and close them afterwards. Anything captured by
  mistake has to be deleted before it reaches the repo.

## Conditions to pin

| Condition | Value |
|---|---|
| Theme | Whatever the current assets used — `omarchy-theme-current` reports the active one |
| Monitor | One monitor, so `hyprctl monitors -j` has a single entry to reason about |
| Panes | Exactly two, side by side, for both GIFs, with the terminal's resize overlay off |
| Cursor | Visible: `grim` never draws it, `gpu-screen-recorder` draws it by default |
| Output size | `preview.png` 748 wide, height follows the panel; both GIFs 900×506 at 12 fps |

Geometry is logical throughout — `hyprctl` and `grim -g` both speak it — while
the pixels that come out are physical. On a scale-2 monitor a 374×528 logical
crop lands as the 748×1056 file. Read the scale rather than assuming it:

```bash
hyprctl monitors -j | jq -c '.[] | {name, width, height, scale}'
```

Derive every coordinate from `hyprctl clients -j` (`.at`, `.size`, both
logical) rather than typing one in. That is what keeps the framing stable
across months.

Moving between workspaces goes through `focus`, which is the one dispatcher
here that is hard to guess — `hl.dsp.workspace` is a namespace for renaming and
moving, not for going somewhere:

```bash
hyprctl dispatch 'hl.dsp.focus({ workspace = 5 })'
```

## Synthetic input

`ydotool` drives the drags. It writes real events through `/dev/uinput`, so
Hyprland cannot tell them from a hand on the mouse — which matters here,
because both GIFs are of a drag Hyprland has to honour.

Omarchy sets it up in one command — the package, the `input` group, the
`/dev/uinput` udev rule and the user service, which is the whole of what
ydotool normally makes you assemble by hand. **The user runs this one, in a
terminal**: it needs a password, and an agent's shell has no tty to read one
from, so it aborts before changing anything.

```bash
omarchy dev install ydoo
```

It prints `ydotool is ready.` when it worked. Being added to the `input` group
takes effect on the next login, so a first run on a fresh machine may need a
relogin before the daemon will start — though logind already grants the active
session write access to `/dev/uinput` through an ACL, so check whether
`test -w /dev/uinput` passes before assuming a relogin is needed.

Check it before every session — the service is per-user and does not survive a
reboot enabled:

```bash
systemctl --user is-active ydotool.service
```

The vocabulary is small:

```bash
ydotool mousemove --absolute -x 900 -y 540   # jump to a point
ydotool click 0x40                            # left button DOWN
ydotool click 0x80                            # left button UP
ydotool key 125:1                             # SUPER down   (125:0 releases)
```

`0x40` and `0x80` are what make a drag possible at all: they are press and
release as separate calls, with the moves in between.

**Move in small steps.** Hyprland's border resize accumulates the delta between
successive cursor positions rather than tracking where the cursor absolutely
is, so a coarse sweep compounds: a run of 8 px jumps that should end mid-screen
instead collapses one pane to a sliver, and the recording is unusable. Steps of
about 4 px with a ~60 ms sleep track the cursor honestly.

### Calibrate first

ydotool's absolute axis and Hyprland's logical space agree on this machine's
scale or they do not, and a drag aimed at the wrong point silently grabs
nothing. One round trip settles it:

```bash
ydotool mousemove --absolute -x 900 -y 540 && sleep 0.2 && hyprctl cursorpos
```

`900, 540` back means the two agree and every coordinate below is logical. Any
other answer is a scale factor — divide the targets by it, and re-run this
until the round trip matches before shooting anything.

## Recording

`gpu-screen-recorder` ships with Omarchy and is what
`omarchy-capture-screenrecording` drives. Called directly it takes a region and
skips the picker and the toast:

```bash
gpu-screen-recorder -w region -region 900x506+X+Y -f 60 -cursor yes \
  -o /tmp/capture.mp4 &
```

The region is 900×506 logical, like every other coordinate here, so on a
scale-2 monitor the mp4 comes out 1800×1012 and the `scale=900` below brings it
back. Both dimensions have to be even or the encoder refuses the region.

Stop it with `pkill -SIGINT -f '^gpu-screen-recorder'` — SIGINT, or the file is
not finalised. That pattern also matches a recording the user started
themselves, so check `pgrep -f '^gpu-screen-recorder'` is empty before you
begin.

Then to GIF, at the size and frame rate the current assets use:

```bash
ffmpeg -y -i /tmp/capture.mp4 -vf \
  "fps=12,scale=900:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle" \
  <asset>.gif
```

`stats_mode=diff` and `diff_mode=rectangle` restrict each frame to the
rectangle that changed, which is most of why the existing GIFs are as small as
they are.

## The three assets

### `preview.png` — the panel, every control visible

No mouse needed. The panel opens over IPC:

```bash
omarchy-shell shell toggle dev.momoi-labs.pane-manager
```

**Open it fresh on the workspace you are shooting.** The scope is set when the
panel opens and then stays put, so a panel carried across a workspace change
shows a header reading `WS 5` above an **Apply to** reading `WS 3`. It is a
toggle, so confirm it was closed before you open it — and `grim` never takes
focus, so the panel survives the capture.

Finding the panel's box takes a measurement. `hyprctl layers -j` is no help:
the panel is drawn inside `omarchy-keyboard-panel`, a full-screen layer whose
geometry is the whole monitor. What is findable is the panel's own border — a
bright line against the dimmed backdrop:

```bash
grim /tmp/shot.png && magick /tmp/shot.png -depth 8 /tmp/shot.ppm
```

Read the PPM, find the two brightest pixels on a horizontal line crossing the
panel body for the left and right edges, then take the longest bright vertical
run in the left edge's column for the top and bottom. Scan for *brightness*
rather than a colour: the border is a gradient — light blue down one side,
lavender down the other — so matching the colour sampled from one edge misses
the other entirely.

That gives the panel box in physical pixels. A 14 px margin on each side is the
framing the current asset uses, and on a 720 px-wide panel it is what makes the
file 748 across:

```bash
magick /tmp/shot.png -crop 748x<h>+<x-14>+<y-14> +repage preview.png
```

Every control has to be in frame — including whichever one the change added,
which is the reason you are re-shooting. Open the file and look: cropping to a
row of text rather than the border is an easy miss, and it takes the title with
it.

### `preview-resize.gif` — a divider dragged, no modifier

**Drag the border** must be on, and the workspace on `dwindle`. Two panes side
by side; the divider is the seam between them, at the left pane's `at.x +
size.x`, vertically centred.

Dress the scene before recording. A terminal that draws its dimensions on every
resize — Ghostty's `resize-overlay`, on by default — stamps `164 x 68` across
the frame throughout the drag, which is the one thing the eye follows instead
of the divider. Command-line overrides do not reach it; launch the panes with a
throwaway config directory instead, which also leaves the user's own untouched:

```bash
mkdir -p /tmp/gcfg/ghostty
printf 'resize-overlay = never\n' >/tmp/gcfg/ghostty/config
XDG_CONFIG_HOME=/tmp/gcfg ghostty --gtk-single-instance=false
```

`--gtk-single-instance=false` matters: without it the new window is served by
the already-running instance and inherits its config, flags and all. Closing
these afterwards wants `hl.dsp.window.kill({})` — `close` returns `ok` and
leaves the window standing.

Reset the ratios between takes with `bin/pane-manager reset`, or the second
drag starts from wherever the first one left the divider.

Approach the seam first and pause — the cursor changing shape is half of what
this GIF is demonstrating, and cutting straight to the press loses it. Then
press, move across in steps of a few pixels with a short sleep between them so
the recording has frames to show, and release.

Keep both hands off the modifiers for the whole take. A `SUPER` held here
turns the capture into a recording of Hyprland's built-in resize — the thing
this feature is the modifier-free alternative to.

### `preview-drop.gif` — a `SUPER` drag with the indicator painted

**Drop to any side** must be on, and the workspace on `dwindle` — on
`scrolling` the indicator deliberately draws nothing.

Hold `SUPER` for the whole drag (`key 125:1` … `key 125:0`), press on one
pane, and move it over the other. Cross the target's centre slowly and pause on
more than one side of it: the shaded half switching as the cursor moves is the
entire point, and a drag straight to the drop shows a static rectangle instead.

The indicator only appears once Hyprland flips the dragged pane to floating, so
give the press a moment before moving.

## Judging the result

Before replacing anything, open the new asset and the one in git beside each
other. Three questions:

1. Is the thing the asset exists to demonstrate still visible in it?
2. Does anything differ from the old asset other than the change?
3. Are the dimensions the ones in the table above? A `preview.png` that is
   not 748 wide means the crop missed the border.

A "no" to any of them means re-shoot rather than commit. The GIFs are large
binaries in the repo's history — `preview-drop.gif` alone is 2.6 MB — so each
one committed is permanent weight.
