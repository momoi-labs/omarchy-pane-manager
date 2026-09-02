---
name: refresh-readme
description: Bring the README back in line with the code after a change to this plugin — the Features prose, the panel bullet list, the Settings table, the CLI block, and the three preview assets. Use after a feature lands, before tagging a release, or when asked whether the README or the screenshots are stale.
---

# Refresh the README

The README's prose keeps up because prose is cheap to edit. The parts that
drift silently are the four sections with a source of truth elsewhere in the
repo, and the three preview assets, which drift because re-shooting one means
arranging a live Hyprland session by hand.

Work from the diff. Re-shooting everything every time is why nothing gets
re-shot.

## 1. Scope the drift

```bash
git diff --stat $(git describe --tags --abbrev=0)..HEAD
```

Read the diff itself for anything that touched `manifest.json`,
`bin/pane-manager`, or the panel's controls in `PaneManager.qml`. From that,
write down two lists before changing anything:

- which of the four prose sections a change could have invalidated
- which of the three assets a change could have invalidated

Both lists are usually short and one is often empty. An empty asset list is the
good case: stop after step 2.

## 2. Sync the prose

Each section is checked against a source of truth, not against memory. Read the
source, then the section, and reconcile.

| README section | Source of truth |
|---|---|
| **Settings** table | `manifest.json` → `barWidget.schema` (key, `defaultValue`, `description`) and `barWidget.defaults` |
| **CLI** block | `bin/pane-manager` — the `case "$cmd"` dispatch at the foot of the file, and the usage comment at its head |
| **The panel** bullet list | `PaneManager.qml` — the tabs, and every labelled control inside them |
| **Features** section | The `docs/adr/` entries and the panel's controls: one heading per behaviour a user can turn on |

Three rules for the reconciliation:

- A control that exists and has no bullet is drift. A bullet for a control that
  no longer exists is drift.
- The Settings table's defaults have to be the literal values in
  `manifest.json`. A number typed twice goes stale once.
- Keep the README's voice: a row exists to answer *"why did it land there?"*,
  which is the bar `docs/adr/0002` sets for adding the control in the first
  place. A bullet that only restates the label has not met it.

The usage comment at the head of `bin/pane-manager` is itself a copy of the
dispatch. Check it in the same pass; it drifts for the same reason.

## 3. Re-shoot the assets that drifted

Only for assets on the list from step 1. The capture conditions, the input
setup and the recipes are in [`capture.md`](capture.md) — read it before
touching anything, because a capture taken under different conditions is worse
than a stale one.

Each asset exists to demonstrate one thing. A refresh that loses it has failed
even when the image is newer:

| Asset | Has to show |
|---|---|
| `preview.png` | The panel open, every control visible |
| `preview-resize.gif` | A divider dragged with **no modifier held** |
| `preview-drop.gif` | A `SUPER` drag with the indicator painted on the landing half |

## 4. Report

Say which sections you changed and which assets you re-shot, and name anything
on either list you left alone and why. If an asset drifted and you could not
re-shoot it, say so plainly — a stale asset that is known to be stale is worth
more than a silent one.
