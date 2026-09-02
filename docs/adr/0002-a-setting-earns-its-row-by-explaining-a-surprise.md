# 2. A setting earns its row by explaining a surprise

- Status: accepted
- Date: 2026-09-02

## Context

Hyprland's dwindle layout reads nine `dwindle:*` options on 0.56.2, and this
plugin exposes one of them. Deciding which of the other eight to add turned out
to need an answer to a prior question: what is the plugin for?

Two readings were live, and they pull in opposite directions:

- **A settings panel** — surface the options Hyprland buries in
  `looknfeel.lua`. Under this reading every option is a candidate, and the
  panel grows until it mirrors the config file.
- **A way to see what the layout decides** — the drop indicator shades the half
  a dragged pane will take, because Hyprland picks that side from the cursor and
  draws nothing to say which. The two resets are the same idea backwards: the
  split tree has no undo, so the plugin supplies one.

Dwindle makes five decisions every time a pane appears — which pane to split,
which side of it, which orientation, at what ratio, and then how a divider drag
redistributes. All five are invisible. Only the second is illuminated today, and
only when the pane arrives by drag.

## Decision

The plugin does both, and **illuminating leads**: an option earns a row only if
it answers *"why did it land there?"*.

That admission test settles the eight remaining options without arguing each on
its own merits. `column_width`-style preferences do not qualify. `split_bias`
does not, because it explains nothing until the ratio moves off 1.0. What does
qualify is the gap the test makes obvious: a pane you **open** lands somewhere
nothing predicted, because Omarchy pins `force_split = 2` and the cursor is
ignored.

**Open to any side** answers it, and does so by handing over the decision rather
than by drawing it: opening starts following the cursor, the same rule dropping
already follows. A preview was the alternative and lost on a fact about the
runtime — a drag has a start and an end to hang an overlay on
(`changefloatingmode` on socket2), while opening a window announces itself only
once the window is already placed. Illuminating it would mean an overlay that is
either always on screen or bound to a key.

**One row writes two Hyprland options.** `dwindle:smart_split` decides the side
by cursor; `dwindle:use_active_for_splits` decides whether the pane under the
cursor is the one being split at all. Ship only the first and a new pane still
splits the *focused* pane — on the side facing your mouse, which is stranger
than the behaviour it replaced. Neither option is the behaviour alone, so
neither gets its own row.

The row is the fourth scoped key, `openside`, on the same three levels as the
others (ADR 0001): `~/.config/hypr/` under a global value under a per-workspace
override. Its twin is scoped; a pair where one is answered per workspace and the
other is not would be two classes of row that look identical.

Off writes `use_active_for_splits = true` — Hyprland's own default — rather than
a snapshot of the user's config value. Carrying a fourth stored value to
round-trip an option nobody sets by hand costs more than it buys, and reset is
already the documented way back to `~/.config/hypr/`.

## Consequences

- Opening and dropping become one operation with two verbs: target is the pane
  under the cursor, side is one of four by the cursor. Two code paths in
  Hyprland, one rule to learn.
- `force_split` gets no control of its own. With the row off, opening is
  whatever the config says, which on Omarchy is right/bottom — that *is* the off
  state, not a separate setting.
- The drop indicator is untouched. On the drop path `use_active_for_splits`
  already falls through, because the active window is the one being dropped, so
  the target has always been the node nearest the cursor.
- A user whose own config sets `use_active_for_splits = false` has it overridden
  while the row is off. Reset restores it.
- The eight remaining options now have a bar to clear rather than a queue to
  wait in. Some will never clear it, and that is the point.

## Alternatives considered

- **Ship `smart_split` alone.** One option per row is a cleaner rule, and it
  produces a worse setting: the promise on the row would be false.
- **Two rows**, one for the side and one for the target. Honest about the
  mechanism, but it asks the user to assemble a behaviour out of two switches
  that are only useful in one combination.
- **An always-on preview of where the next pane will open.** Answers the
  question literally and costs a permanent overlay plus a cursor poll, to
  describe a decision the user could simply be making.
- **Expose the scrolling layout's nine options** so the Panes tab has live
  content on a scrolling workspace. None of them pass the admission test, and a
  dimmed tab is a symptom of not having decided whether scrolling is a peer
  layout or a mode — which is its own decision, not this one.
