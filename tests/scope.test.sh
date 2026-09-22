# Where a setting lands, and what Hyprland is asked to do about it. Every
# test starts on workspace 1 with three workspaces open, all on dwindle, and
# an empty store (see setup in tests/run).

# ---- layout, per workspace

test_layout_for_another_workspace_pins_only_that_one() {
  pm set layout scrolling --workspace 2
  assert_json "$STORE/overrides.json" '. == {"2": {"layout": "scrolling"}}'
  assert_json "$STORE/global.json" '. == {}'
  assert_eq 'hl.workspace_rule({ workspace = "2", layout = "scrolling" })' "$(cat "$LAYOUTS/2.lua")" "2.lua"
  assert_absent "$LAYOUTS/1.lua"
  assert_called 'eval hl.workspace_rule({ workspace = "2", layout = "scrolling" })'
  assert_not_called 'workspace = "1"'
  assert_not_called reload
}

test_layout_without_an_id_means_the_active_workspace() {
  hypr '.activeWorkspace = 3'
  pm set layout master --workspace
  assert_json "$STORE/overrides.json" '. == {"3": {"layout": "master"}}'
  assert_present "$LAYOUTS/3.lua"
}

test_layout_default_drops_the_override_and_reloads() {
  pm set layout scrolling --workspace 2
  forget_calls
  pm set layout default --workspace 2
  assert_absent "$LAYOUTS/2.lua"
  assert_json "$STORE/overrides.json" '. == {}'
  assert_called reload
}

test_layout_for_all_pins_every_open_workspace_and_clears_overrides() {
  pm set layout scrolling --workspace 2
  pm set drag off --workspace 2
  forget_calls
  pm set layout master --all
  assert_json "$STORE/global.json" '.layout == "master"'
  # The layout override goes; the drag one is a different setting and stays.
  assert_json "$STORE/overrides.json" '. == {"2": {"drag": false}}'
  for ws in 1 2 3; do
    assert_eq "hl.workspace_rule({ workspace = \"$ws\", layout = \"master\" })" "$(cat "$LAYOUTS/$ws.lua")" "$ws.lua"
  done
  assert_not_called reload
}

test_layout_default_for_all_unpins_everything() {
  pm set layout scrolling --all
  forget_calls
  pm set layout default --all
  assert_json "$STORE/global.json" '. == {}'
  assert_absent "$LAYOUTS/1.lua"
  assert_absent "$LAYOUTS/2.lua"
  assert_called reload
}

test_the_default_layout_is_never_pinned() {
  # Nobody chose dwindle: the store is empty and the config says dwindle, so
  # no rule is written that would outlive a later edit to the config.
  pm apply
  assert_absent "$LAYOUTS/1.lua"
  assert_not_called workspace_rule
}

# ---- the global options, per workspace

test_a_workspace_override_waits_until_that_workspace_has_focus() {
  pm set drag off --workspace 2
  assert_json "$STORE/overrides.json" '.["2"].drag == false'
  assert_not_called resize_on_border

  hypr '.activeWorkspace = 2'
  forget_calls
  pm apply --grab 10
  assert_called 'resize_on_border = false'
}

test_an_override_that_switches_something_off_is_not_read_as_absent() {
  pm set drag on --all --grab 10
  pm set drag off --workspace 1
  forget_calls
  pm apply --grab 10
  assert_called 'resize_on_border = false'
  assert_not_called 'resize_on_border = true'
}

test_setting_for_all_applies_to_the_active_workspace_at_once() {
  pm set drag on --all --grab 12
  assert_json "$STORE/global.json" '.drag == true'
  assert_called 'resize_on_border = true, extend_border_grab_area = 12'
}

test_setting_for_all_drops_every_workspace_answer_for_that_key() {
  pm set dropside on --workspace 2
  pm set dropside off --workspace 3
  pm set dropside on --all
  assert_json "$STORE/overrides.json" '. == {}'
}

test_default_at_workspace_scope_falls_back_to_the_global_value() {
  pm set dropside on --all
  pm set dropside off --workspace 1
  pm set dropside default --workspace 1
  assert_json "$STORE/overrides.json" '. == {}'
  assert_called 'precise_mouse_move = true'
}

test_open_to_any_side_writes_both_dwindle_options() {
  pm set openside on --all
  assert_called 'smart_split = true, use_active_for_splits = false'
  forget_calls
  pm set openside off --all
  assert_called 'smart_split = false, use_active_for_splits = true'
}

# ---- what the panel reads

test_state_reports_the_store_with_the_config_folded_in() {
  pm set layout scrolling --workspace 2
  pm set drag off --workspace 2
  out=$(pm state)
  assert_eq 'dwindle' "$(jq -r .global.layout <<<"$out")" "global.layout comes from general:layout"
  assert_eq 'false' "$(jq -r .global.drag <<<"$out")" "global.drag comes from resize_on_border"
  assert_eq '{"2":{"layout":"scrolling","drag":false}}' "$(jq -c .overrides <<<"$out")" "overrides"
  assert_eq '[1,2,3]' "$(jq -c .workspaces <<<"$out")" "workspaces"
  assert_eq '1' "$(jq -r .activeWorkspace <<<"$out")" "activeWorkspace"
}

test_the_config_snapshot_survives_runtime_drift() {
  # getoption answers with the value in force. Once the helper has written
  # something, that is no longer the config, so Default keeps meaning what the
  # config said the first time.
  pm set drag on --all --grab 10
  hypr '.options["general:resize_on_border"].bool = true'
  pm set drag default --all
  assert_eq 'false' "$(pm state | jq -r .global.drag)" "global.drag after default"
}

test_the_snapshot_is_retaken_after_a_reset() {
  pm state >/dev/null
  hypr '.options["general:layout"].str = "master"'
  pm reset --all
  assert_eq 'master' "$(pm state | jq -r .global.layout)" "global.layout after reset"
}

# ---- reset

test_reset_forgets_only_the_active_workspace() {
  pm set layout scrolling --workspace 1
  pm set layout scrolling --workspace 2
  pm set drag off --all
  forget_calls
  pm reset
  assert_json "$STORE/overrides.json" '. == {"2": {"layout": "scrolling"}}'
  assert_json "$STORE/global.json" '.drag == false'
  assert_absent "$LAYOUTS/1.lua"
  assert_present "$LAYOUTS/2.lua"
  assert_called reload
  # The reload put drag back to the config; the store's answer goes on top.
  assert_called 'resize_on_border = false'
}

test_reset_all_deletes_the_store() {
  pm set layout scrolling --workspace 2
  pm set drag on --all
  pm reset --all
  assert_absent "$STORE/global.json"
  assert_absent "$STORE/overrides.json"
  assert_absent "$LAYOUTS/2.lua"
  assert_called reload
}

test_reset_puts_the_split_ratios_back_and_refocuses() {
  hypr '.clients = [
    {"address": "0xa", "workspace": {"id": 1}, "floating": false},
    {"address": "0xb", "workspace": {"id": 1}, "floating": true},
    {"address": "0xc", "workspace": {"id": 2}, "floating": false}
  ] | .activewindow = {"address": "0xb"}'
  pm reset
  assert_called 'focus({ window = "address:0xa" })'
  assert_not_called 'address:0xc'
  assert_called 'splitratio -5'
  # Focus goes back to where it was once every ratio is reset, not before.
  last_reset=$(grep -n 'splitratio' "$FAKE_HYPR/calls" | tail -1 | cut -d: -f1)
  refocus=$(grep -n 'address:0xb' "$FAKE_HYPR/calls" | tail -1 | cut -d: -f1)
  [[ -n $refocus && $refocus -gt $last_reset ]] || fail "expected the refocus on 0xb after the last splitratio"
}

# ---- input

test_rejects_what_it_cannot_store() {
  assert_fails 'expected dwindle, scrolling, master, monocle or default' pm set layout tabbed --all
  assert_fails 'expected on, off or default' pm set drag maybe --all
  assert_fails 'unknown setting' pm set border 2 --all
  assert_fails 'unknown option' pm set drag on --everywhere
}

# ---- the 1.0 spellings

test_legacy_commands_land_in_the_store() {
  pm enable 10
  assert_json "$STORE/global.json" '.drag == true'
  pm dropside true
  assert_json "$STORE/global.json" '.dropside == true'
  pm layout scrolling --workspace
  assert_json "$STORE/overrides.json" '.["1"].layout == "scrolling"'
  pm toggle 10
  assert_json "$STORE/global.json" '.drag == null'
  assert_called reload
}
