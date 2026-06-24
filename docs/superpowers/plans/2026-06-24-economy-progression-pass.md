# Economy, Progression & Persistence Pass — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make in-run upgrades cost Credits (wave-clear shop), make the Spaceport meta-shop use exponential pricing with progression-gated tier unlocks, and add the save foundation (lifetime stats + versioning) those depend on.

**Architecture:** Pure-GDScript Godot 4.7 changes across 5 scripts. All cross-system comms stay on EventBus (new `credits_spend_requested`/`credits_spend_result` pair mirrors the existing void-cores pair). UI panels keep local `_levels` mirrors and read persisted data from the `SaveManager` autoload (a data store, not a manager). No new autoloads, no scene changes.

**Tech Stack:** Godot 4.7 stable, GDScript only, ConfigFile persistence (`user://savegame.cfg`), verified by running the game via the Godot MCP and inspecting node/state (no unit-test framework in this repo).

## Global Constraints

- Engine: Godot 4 stable, **GDScript only** (no C#/C++).
- All inter-system comms via **EventBus**; declare new signals in `event_bus.gd` before use. No manager-to-manager references.
- Managers update via **TickSystem.tick**, never raw `_process()`.
- Credits are **BigNum**; Void Cores / Gems are ints.
- Every script opens with a one-line `## Purpose:` comment; typed GDScript everywhere; private members prefixed `_`.
- This repo is **not a git repository** and has **no test runner**. "Verify" = run via Godot MCP and inspect state, or run a one-off headless calc; do not invent pytest. Commit only if the user later initialises git and asks.
- In-run shop bases: **Common 5 / Rare 18 / Epic 50 / Legendary 150**, growth **×1.55** per that upgrade's own level.
- Spaceport growth: **×1.6** per level; galaxy one-time unlocks stay flat.
- Spaceport tier unlock thresholds (best wave ever): **T1=0, T2=50, T3=100, T4=150**.

---

## File map

- `_game/scripts/core/save_manager.gd` — add schema version + migration hook (Task 1).
- `_game/scripts/managers/economy_manager.gd` — write lifetime stats at run end (Task 2); credits spend handler (Task 6).
- `_game/scripts/core/event_bus.gd` — 2 new credits-spend signals (Task 6).
- `_game/scripts/managers/spaceport_system.gd` — exponential cost helper + tier-unlock logic (Tasks 3, 4).
- `_game/scripts/ui/spaceport_panel.gd` — per-card scaled cost + locked-tier rendering (Task 5).
- `_game/scripts/ui/upgrade_panel.gd` — credit cost / affordability / spend flow / countdown bar / hide no-op upgrades (Tasks 7, 8).

Build order is dependency-driven: **Save (1–2) → Spaceport (3–5) → In-run shop (6–8).**

---

## PART 1 — Save foundation

### Task 1: Save schema version + migration hook

**Files:**
- Modify: `_game/scripts/core/save_manager.gd`

**Interfaces:**
- Produces: `SaveManager.SAVE_VERSION` (int); a `meta` section persisted with `version`; `_migrate_if_needed()` runs on load. No change to `get_value`/`set_value`/`save`/`load_save` signatures.

- [ ] **Step 1: Define the expected behaviour (the check)**

After a `save()` then fresh `load_save()`, `get_value("meta","version")` must equal `1`. Loading an old save with no `meta` section must not error and must end with version stamped to `1`.

- [ ] **Step 2: Add the version constant and stamp it on save**

In `save_manager.gd`, add the constant near `SAVE_PATH`:

```gdscript
const SAVE_VERSION: int = 1
```

Change `save()` to stamp the meta section before writing:

```gdscript
func save() -> void:
	_data["meta"] = {"version": SAVE_VERSION}
	var file := ConfigFile.new()
	for section: String in _data:
		for key: String in _data[section]:
			file.set_value(section, key, _data[section][key])
	file.save(SAVE_PATH)
```

- [ ] **Step 3: Run the migration hook on load**

Change `load_save()` to call the hook after populating `_data`:

```gdscript
func load_save() -> void:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return
	for section: String in file.get_sections():
		_data[section] = {}
		for key: String in file.get_section_keys(section):
			_data[section][key] = file.get_value(section, key)
	_migrate_if_needed()
```

Add the hook (v0→v1 is a no-op stamp; future versions branch here):

```gdscript
func _migrate_if_needed() -> void:
	var meta: Dictionary = _data.get("meta", {})
	var v: int = meta.get("version", 0)
	if v == SAVE_VERSION:
		return
	# v0 (pre-versioning) → v1: no structural change; stamp current version.
	_data["meta"] = {"version": SAVE_VERSION}
```

- [ ] **Step 4: Verify via Godot MCP**

Launch the game (main.tscn) via MCP. In a one-off `execute_script` (or after the autoload runs), evaluate:

```gdscript
SaveManager.save()
SaveManager.load_save()
print(SaveManager.get_value("meta", "version", -1))  # expect: 1
```
Expected output: `1`. No errors in the Godot log.

### Task 2: Lifetime stats written at run end

**Files:**
- Modify: `_game/scripts/managers/economy_manager.gd:83-90` (the `_on_run_ended` function)

**Interfaces:**
- Consumes: `SaveManager.get_value/set_value/save` (Task 1).
- Produces: persisted `lifetime` section keys — `total_void_cores_ever` (int), `best_wave` (int), `total_runs` (int). Spaceport gating (Task 4) reads `lifetime/best_wave`.

- [ ] **Step 1: Define the expected behaviour (the check)**

After a run that reaches wave 30 with 1 boss kill: `cores = floor(30/10) + 1*5 = 8`. Then `lifetime/best_wave == 30`, `lifetime/total_runs` incremented by 1, and `lifetime/total_void_cores_ever` increased by 8 (×`_void_core_multiplier`, default 1.0). A second run reaching wave 12 must leave `best_wave == 30` (max, not overwrite).

- [ ] **Step 2: Append lifetime tracking inside `_on_run_ended`**

Replace the body of `_on_run_ended` with (additions after the existing core award):

```gdscript
func _on_run_ended(stats: Dictionary) -> void:
	var wave: int = stats.get("wave_reached", 0)
	var boss_kills: int = stats.get("boss_kills", 0)
	var cores: int = floori(wave / 10.0) + boss_kills * 5
	cores = int(cores * _void_core_multiplier)
	add_void_cores(cores)

	# Lifetime stats — persist; drive prestige (sqrt) + Spaceport tier gating.
	var total_cores: int = SaveManager.get_value("lifetime", "total_void_cores_ever", 0)
	SaveManager.set_value("lifetime", "total_void_cores_ever", total_cores + cores)
	var best: int = SaveManager.get_value("lifetime", "best_wave", 0)
	if wave > best:
		SaveManager.set_value("lifetime", "best_wave", wave)
	var runs: int = SaveManager.get_value("lifetime", "total_runs", 0)
	SaveManager.set_value("lifetime", "total_runs", runs + 1)
	SaveManager.save()

	credits = BigNum.from(0.0)
	EventBus.credits_changed.emit(credits)
```

- [ ] **Step 3: Verify via Godot MCP**

Play until the ship dies (let enemies through), or emit `EventBus.game_over.emit({"wave_reached":30,"boss_kills":1})` via `execute_script`. Then:

```gdscript
print(SaveManager.get_value("lifetime", "best_wave", -1))             # expect: 30
print(SaveManager.get_value("lifetime", "total_void_cores_ever", -1)) # expect: >= 8
print(SaveManager.get_value("lifetime", "total_runs", -1))            # expect: >= 1
```
Expected: best_wave 30, cores ≥ 8, runs ≥ 1.

---

## PART 2 — Spaceport meta-shop

### Task 3: Exponential cost helper in SpaceportSystem

**Files:**
- Modify: `_game/scripts/managers/spaceport_system.gd:13-17` (the `try_purchase` function)

**Interfaces:**
- Produces: `SpaceportSystem.cost_for(base_cost: int, level: int) -> int` and `SpaceportSystem.COST_GROWTH` (float). The panel (Task 5) calls `cost_for` so display and charge use one source of truth.

- [ ] **Step 1: Define the expected behaviour (the check)**

`cost_for(10, 0) == 10`, `cost_for(10, 1) == 16` (round(10×1.6)), `cost_for(10, 3) == 41` (round(10×4.096)), `cost_for(10, 5) == 105` (round(10×10.4858)).

- [ ] **Step 2: Add the constant and helper, route `try_purchase` through it**

In `spaceport_system.gd` add near the top (after `extends Node`):

```gdscript
const COST_GROWTH: float = 1.6

func cost_for(base_cost: int, level: int) -> int:
	return int(round(base_cost * pow(COST_GROWTH, level)))
```

Replace `try_purchase` to use the helper (keeps it consistent even though the panel emits directly):

```gdscript
func try_purchase(upgrade_id: String, base_cost: int) -> void:
	var level: int = get_level(upgrade_id)
	var cost: int = cost_for(base_cost, level)
	_pending_purchase_id = upgrade_id
	EventBus.void_cores_spend_requested.emit(cost, upgrade_id)
```

- [ ] **Step 3: Verify**

Via `execute_script`:

```gdscript
print(SpaceportSystem.cost_for(10, 0), " ", SpaceportSystem.cost_for(10, 1), " ", SpaceportSystem.cost_for(10, 3), " ", SpaceportSystem.cost_for(10, 5))
```
Expected: `10 16 41 105`.

### Task 4: Tier-unlock logic in SpaceportSystem

**Files:**
- Modify: `_game/scripts/managers/spaceport_system.gd`

**Interfaces:**
- Consumes: `SaveManager.get_value("lifetime","best_wave",0)` (Task 2).
- Produces: `SpaceportSystem.TIER_UNLOCK_WAVE` (Dictionary), `SpaceportSystem.is_tier_unlocked(tier: int) -> bool`, `SpaceportSystem.unlock_wave_for_tier(tier: int) -> int`.

- [ ] **Step 1: Define the expected behaviour (the check)**

With `lifetime/best_wave == 0`: `is_tier_unlocked(1)` true, `is_tier_unlocked(2)` false. With `best_wave == 60`: tiers 1 and 2 true, tier 3 false. `unlock_wave_for_tier(3) == 100`.

- [ ] **Step 2: Add the tier table and predicates**

In `spaceport_system.gd` add:

```gdscript
const TIER_UNLOCK_WAVE: Dictionary = {1: 0, 2: 50, 3: 100, 4: 150}

func unlock_wave_for_tier(tier: int) -> int:
	return TIER_UNLOCK_WAVE.get(tier, 0)

func is_tier_unlocked(tier: int) -> bool:
	var best: int = SaveManager.get_value("lifetime", "best_wave", 0)
	return best >= unlock_wave_for_tier(tier)
```

- [ ] **Step 3: Verify**

Via `execute_script`:

```gdscript
SaveManager.set_value("lifetime", "best_wave", 60)
print(SpaceportSystem.is_tier_unlocked(1), SpaceportSystem.is_tier_unlocked(2), SpaceportSystem.is_tier_unlocked(3))
```
Expected: `truetruefalse`. Reset best_wave afterward if testing further.

### Task 5: Spaceport panel — scaled cost + locked-tier rendering

**Files:**
- Modify: `_game/scripts/ui/spaceport_panel.gd` (UPGRADES array, `_ready`, `_build_sp_card`, `_on_spaceport_opened`; add `_levels`, `_on_meta_purchased`)

**Interfaces:**
- Consumes: `SpaceportSystem.cost_for`, `SpaceportSystem.is_tier_unlocked`, `SpaceportSystem.unlock_wave_for_tier` (Tasks 3–4); `SaveManager.get_value("spaceport","upgrades",{})`.

- [ ] **Step 1: Define the expected behaviour (the check)**

With `best_wave == 0`: Tier-1 cards (Reinforced Hull, Reactor Boost, Starting Credits) are buyable and show their scaled cost; all Tier-2+ cards render greyed with "Reach Wave N to unlock" and ignore taps. After buying Reinforced Hull once, its cost label updates from `10vc` to `16vc`.

- [ ] **Step 2: Add a `tier` to every upgrade entry**

Replace the `UPGRADES` array with tier-tagged entries (the 3 absent DESIGN upgrades stay deferred):

```gdscript
const UPGRADES: Array[Dictionary] = [
	{"id":"reinforced_hull",  "tab":0, "tier":1, "icon":"🔩", "name":"Reinforced Hull",  "desc":"+25 base max HP",         "base_cost":10},
	{"id":"reactor_boost",    "tab":0, "tier":1, "icon":"⚡", "name":"Reactor Boost",    "desc":"+5% base fire rate",      "base_cost":15},
	{"id":"shield_generator", "tab":0, "tier":2, "icon":"🛡", "name":"Shield Gen",       "desc":"+25 max shield",          "base_cost":25},
	{"id":"targeting_system", "tab":0, "tier":2, "icon":"🎯", "name":"Targeting Sys",    "desc":"+3% base crit chance",    "base_cost":20},
	{"id":"engine_coolant",   "tab":0, "tier":3, "icon":"❄",  "name":"Engine Coolant",   "desc":"-10% upgrade cost",       "base_cost":30},
	{"id":"void_extractor",   "tab":1, "tier":2, "icon":"◈",  "name":"Void Extractor",   "desc":"+15% Void Cores per run", "base_cost":20},
	{"id":"starting_credits", "tab":1, "tier":1, "icon":"◉",  "name":"Starting Credits", "desc":"Begin run with bonus ₵",  "base_cost":10},
	{"id":"upgrade_discount", "tab":1, "tier":3, "icon":"✦",  "name":"Upgrade Discount", "desc":"-5% upgrade costs",       "base_cost":25},
	{"id":"galaxy_scanner",   "tab":2, "tier":4, "icon":"🔭", "name":"Galaxy Scanner",   "desc":"Reveal enemy HP bars",    "base_cost":50},
	{"id":"fast_forward",     "tab":2, "tier":4, "icon":"⏩", "name":"Fast Forward",     "desc":"Unlock 2× game speed",    "base_cost":100},
]
```

- [ ] **Step 3: Add a level mirror, seed it on open, refresh on purchase**

Add a member near `_active_tab`:

```gdscript
var _levels: Dictionary = {}
```

In `_ready`, after the existing `EventBus.gems_changed.connect(...)` line, add:

```gdscript
	EventBus.meta_upgrade_purchased.connect(_on_meta_purchased)
```

Add the handler (place near `_on_void_cores_changed`):

```gdscript
func _on_meta_purchased(id: String) -> void:
	_levels[id] = _levels.get(id, 0) + 1
	_populate_grid()
```

Update `_on_spaceport_opened` to seed the mirror from the save before populating:

```gdscript
func _on_spaceport_opened() -> void:
	_levels = SaveManager.get_value("spaceport", "upgrades", {}).duplicate()
	_active_tab = 0
	_update_tab_visuals()
	_populate_grid()
	visible = true
```

- [ ] **Step 4: Render scaled cost + locked state in `_build_sp_card`**

Replace the footer cost-label block and the button block (lines ~298-318) with tier/cost-aware logic:

```gdscript
	var uid: String = entry.get("id", "")
	var tier: int = entry.get("tier", 1)
	var base_cost: int = entry.get("base_cost", 10)
	var level: int = _levels.get(uid, 0)
	var unlocked: bool = SpaceportSystem.is_tier_unlocked(tier)
	var cost: int = SpaceportSystem.cost_for(base_cost, level)

	var cost_lbl := Label.new()
	cost_lbl.add_theme_font_override("font", UIFonts.mono_bold())
	cost_lbl.add_theme_font_size_override("font_size", 30)
	if unlocked:
		cost_lbl.text = "%dvc" % cost
		cost_lbl.add_theme_color_override("font_color", Palette.PURPLE)
	else:
		cost_lbl.text = "🔒 Wave %d" % SpaceportSystem.unlock_wave_for_tier(tier)
		cost_lbl.add_theme_color_override("font_color", Palette.MUTED)
	footer.add_child(cost_lbl)

	if not unlocked:
		card.modulate = Color(1, 1, 1, 0.45)   # greyed locked terminal

	# Invisible button overlay for tap-to-purchase (disabled while locked)
	var btn := Button.new()
	btn.flat = true
	btn.disabled = not unlocked
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_theme_stylebox_override("normal",  UIStyles.empty())
	btn.add_theme_stylebox_override("hover",   UIStyles.empty())
	btn.add_theme_stylebox_override("pressed", UIStyles.empty())
	btn.add_theme_stylebox_override("focus",   UIStyles.empty())
	card.add_child(btn)

	if unlocked:
		btn.pressed.connect(func(): EventBus.void_cores_spend_requested.emit(cost, uid))

	return card
```

(Delete the old `var cost_lbl`, old `var btn`, old `var uid/cost`, and old `btn.pressed.connect` lines this replaces — there must be exactly one `cost_lbl`, one `btn`, one `return card`.)

- [ ] **Step 5: Verify via Godot MCP**

Open the Spaceport (`EventBus.spaceport_opened.emit()` or via game over → Spaceport). With `best_wave 0`: inspect the grid — Tier-1 cards show e.g. `10vc`/`15vc`, Tier-2+ show `🔒 Wave 50` greyed. Buy Reinforced Hull (need void cores; grant via `EconomyManager.add_void_cores(50)` in `execute_script`), confirm its label flips to `16vc`. Set `best_wave` to 60, reopen, confirm Tier-2 cards un-grey.

---

## PART 3 — In-run credit shop

### Task 6: Credits spend signals + EconomyManager handler

**Files:**
- Modify: `_game/scripts/core/event_bus.gd:39-40` (Economy section)
- Modify: `_game/scripts/managers/economy_manager.gd:13-20` (`_ready` connections) and add a handler

**Interfaces:**
- Produces: `EventBus.credits_spend_requested(amount: BigNum, context: String)`, `EventBus.credits_spend_result(context: String, success: bool)`. EconomyManager consumes the request, calls existing `spend_credits`, emits the result synchronously.

- [ ] **Step 1: Define the expected behaviour (the check)**

With 20 credits, `credits_spend_requested(BigNum.from(15), "inrun:fire_rate")` → `credits_spend_result("inrun:fire_rate", true)` and credits become 5. A second request for 15 → result `false`, credits stay 5.

- [ ] **Step 2: Declare the two signals**

In `event_bus.gd`, in the `# Economy` block after `void_cores_spend_result`, add:

```gdscript
signal credits_spend_requested(amount: BigNum, context: String)
signal credits_spend_result(context: String, success: bool)
```

- [ ] **Step 3: Connect + handle in EconomyManager**

In `economy_manager.gd` `_ready`, after the `void_cores_spend_requested` connect, add:

```gdscript
	EventBus.credits_spend_requested.connect(_on_credits_spend_requested)
```

Add the handler (near `_on_void_cores_spend_requested`):

```gdscript
func _on_credits_spend_requested(amount: BigNum, context: String) -> void:
	var ok: bool = spend_credits(amount)
	EventBus.credits_spend_result.emit(context, ok)
```

- [ ] **Step 4: Verify**

Via `execute_script`:

```gdscript
EconomyManager.add_credits(20)
var got := []
EventBus.credits_spend_result.connect(func(c, s): got.append([c, s]), CONNECT_ONE_SHOT)
EventBus.credits_spend_requested.emit(BigNum.from(15), "inrun:test")
print(got, " credits=", EconomyManager.credits.value)
```
Expected: `[["inrun:test", true]] credits=5`.

### Task 7: Upgrade panel — credit cost, affordability, spend flow

**Files:**
- Modify: `_game/scripts/ui/upgrade_panel.gd` (add cost/discount helpers, credits mirror, cost label on cards, rewrite `_choose`, add `_on_spend_result`)

**Interfaces:**
- Consumes: `EventBus.credits_changed`, `EventBus.credits_spend_requested/result` (Task 6); `SaveManager.get_value("spaceport","upgrades",{})` for the discount.
- Produces: still emits the existing `EventBus.upgrade_purchased(uid)` on a successful buy (UpgradeManager/StatsPanel unchanged).

- [ ] **Step 1: Define the expected behaviour (the check)**

A level-0 Common costs 5; Rare 18; Epic 50; Legendary 150. With Upgrade Discount level 2 owned, a Common costs `round(5×0.90)=5` (floor mult 0.75 at level ≥5). Tapping an unaffordable card does nothing; tapping an affordable one deducts the cost, bumps the level, advances the wave.

- [ ] **Step 2: Add cost constants, credits mirror, pending id**

In `upgrade_panel.gd`, after the `const AUTO_PICK_SECONDS := 10` line, add:

```gdscript
const RARITY_BASE: Array[int] = [5, 18, 50, 150]   # common, rare, epic, legendary
const COST_GROWTH: float = 1.55

var _credits_value: float = 0.0
var _pending_uid: String = ""
```

In `_ready`, after the `EventBus.game_started.connect(...)` line, add:

```gdscript
	EventBus.credits_changed.connect(func(c: BigNum): _credits_value = c.value)
	EventBus.credits_spend_result.connect(_on_spend_result)
```

- [ ] **Step 3: Add cost + discount helpers**

Add near `_get_upgrade_info`:

```gdscript
func _cost_for(uid: String) -> int:
	var info: Dictionary = _get_upgrade_info(uid)
	var rarity: int = info.get("rarity", 0)
	var level: int = _levels.get(uid, 0)
	var base: int = RARITY_BASE[rarity]
	return int(round(base * pow(COST_GROWTH, level) * _discount_mult()))

func _discount_mult() -> float:
	var owned: Dictionary = SaveManager.get_value("spaceport", "upgrades", {})
	var lvl: int = owned.get("upgrade_discount", 0)
	return maxf(0.75, 1.0 - 0.05 * lvl)
```

- [ ] **Step 4: Show cost on each card + grey unaffordable**

In `_build_card`, in the right column (`right_vbox`) after the `level_label` block, add a cost label:

```gdscript
	var uid_for_cost: String = info.get("id", "")
	var cost_val: int = _cost_for(uid_for_cost)
	var affordable: bool = _credits_value >= cost_val
	var cost_label := Label.new()
	cost_label.text = "%d₵" % cost_val
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_label.add_theme_font_override("font", UIFonts.mono_bold())
	cost_label.add_theme_font_size_override("font_size", 30)
	cost_label.add_theme_color_override("font_color", Palette.AMBER if affordable else Palette.CORAL)
	right_vbox.add_child(cost_label)
```

In the same function, where the tap button is built, gate it on affordability (only matters on wave-clear). Change the `btn.disabled` line and the connect block to:

```gdscript
	btn.disabled = (not _advance_on_close) or (not affordable)
	card.add_child(btn)

	if _advance_on_close and affordable:
		var idx := index
		btn.pressed.connect(func(): _choose(idx))
```

(Replace the existing `btn.disabled = not _advance_on_close` and the `if _advance_on_close:` block.)

- [ ] **Step 5: Route `_choose` through the spend request**

Replace `_choose` with:

```gdscript
func _choose(index: int) -> void:
	if index >= _current_upgrades.size():
		return
	var uid: String = _current_upgrades[index]
	var cost: int = _cost_for(uid)
	if _credits_value < cost:
		return   # not affordable; ignore
	_auto_timer.stop()
	_pending_uid = uid
	EventBus.credits_spend_requested.emit(BigNum.from(cost), "inrun:" + uid)
```

Add the result handler (signals are synchronous, so this completes inside `_choose`'s call):

```gdscript
func _on_spend_result(context: String, success: bool) -> void:
	if not context.begins_with("inrun:"):
		return
	if not success:
		_pending_uid = ""
		return
	var uid: String = _pending_uid
	_pending_uid = ""
	_levels[uid] = _levels.get(uid, 0) + 1
	EventBus.upgrade_purchased.emit(uid)
	_slide_down()
```

- [ ] **Step 6: Verify**

(`Palette.AMBER` = credits/cost amber, `Palette.CORAL` = danger red — both confirmed present in `palette.gd`.) Run the game, clear wave 1 (have ~6 credits): the offered Common shows `5₵` in amber and is tappable; tap it → credits drop to ~1, the wave advances. Re-check via `execute_script` that `EconomyManager.credits.value` dropped by the cost.

### Task 8: Countdown bar, auto-buy-affordable, hide no-op upgrades

**Files:**
- Modify: `_game/scripts/ui/upgrade_panel.gd` (UPGRADE_POOL flags, `_pick_three`, header countdown bar, `_start_countdown`, `_on_auto_tick`)

**Interfaces:**
- Consumes: `_cost_for`, `_credits_value` (Task 7).
- Produces: no new external interface; behavioural only.

- [ ] **Step 1: Define the expected behaviour (the check)**

`chain_lightning`, `explosive_round`, `second_wind` never appear in offers. At 0s the panel buys a random *affordable* offer; if none are affordable it slides down and advances with no purchase. A countdown bar in the header drains over 10s, amber→red.

- [ ] **Step 2: Flag the no-op upgrades disabled and exclude them**

In `UPGRADE_POOL`, add `"enabled": false` to the three entries (chain_lightning, explosive_round, second_wind), e.g.:

```gdscript
	{"id":"chain_lightning",  "label":"Chain Lightning",  "desc":"On hit, arc to nearby enemy 60%","rarity":2, "unlock":15, "max":5,  "icon":"🔗", "enabled": false},
	{"id":"explosive_round",  "label":"Explosive Round",  "desc":"On kill, AoE explosion",         "rarity":2, "unlock":20, "max":5,  "icon":"💣", "enabled": false},
	{"id":"second_wind",      "label":"Second Wind",      "desc":"On death, revive once at 25% HP","rarity":3, "unlock":50, "max":1,  "icon":"🛡", "enabled": false},
```

In `_pick_three`, skip disabled entries — change the inner test to:

```gdscript
	for entry: Dictionary in UPGRADE_POOL:
		var id: String = entry["id"]
		if not entry.get("enabled", true):
			continue
		var unlocked: bool = wave_number >= entry.get("unlock", 1)
		var maxed: bool = _levels.get(id, 0) >= entry.get("max", 9999)
		if unlocked and not maxed:
			pool.append(id)
```

- [ ] **Step 3: Add a draining countdown bar to the header**

Add a member near `_countdown`:

```gdscript
var _countdown_bar: ProgressBar
```

In `_build_header`, after the `sub` label is added to `inner`, add the bar:

```gdscript
	_countdown_bar = ProgressBar.new()
	_countdown_bar.show_percentage = false
	_countdown_bar.custom_minimum_size = Vector2(0, 9)
	_countdown_bar.max_value = float(AUTO_PICK_SECONDS)
	_countdown_bar.value = float(AUTO_PICK_SECONDS)
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color = Palette.BAR_BG
	var fill_s := StyleBoxFlat.new()
	fill_s.bg_color = Palette.AMBER
	_countdown_bar.add_theme_stylebox_override("background", bg_s)
	_countdown_bar.add_theme_stylebox_override("fill", fill_s)
	inner.add_child(_countdown_bar)
```

- [ ] **Step 4: Drive the bar + auto-buy only affordable offers**

In `_start_countdown`, after setting `_countdown`, reset the bar:

```gdscript
func _start_countdown() -> void:
	_countdown = AUTO_PICK_SECONDS
	if _countdown_bar:
		_countdown_bar.value = float(AUTO_PICK_SECONDS)
		(_countdown_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Palette.AMBER
	_update_countdown_footer()
	_auto_timer.start()
```

Replace `_on_auto_tick` to update the bar (amber→red) and auto-pick affordable at 0s:

```gdscript
func _on_auto_tick() -> void:
	_countdown -= 1
	if _countdown_bar:
		_countdown_bar.value = float(max(_countdown, 0))
		var t: float = 1.0 - (float(_countdown) / float(AUTO_PICK_SECONDS))
		(_countdown_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Palette.AMBER.lerp(Palette.CORAL, t)
	if _countdown <= 0:
		_auto_timer.stop()
		_auto_pick_affordable()
		return
	_update_countdown_footer()

func _auto_pick_affordable() -> void:
	var affordable: Array[int] = []
	for i: int in _current_upgrades.size():
		if _credits_value >= _cost_for(_current_upgrades[i]):
			affordable.append(i)
	if affordable.is_empty():
		_slide_down()   # nothing affordable → advance with no purchase
		return
	_choose(affordable[randi() % affordable.size()])
```

- [ ] **Step 5: Verify via Godot MCP**

Play through several wave clears. Confirm: the 3 no-op upgrades never appear; the header bar drains and reddens over 10s; if you can't afford any offer (force by spending credits first), at 0s the panel closes and the next wave starts with no purchase; if you can, a random affordable one is bought.

---

### Task 9: Game Over panel real stats + in-run purchase audio

**Files:**
- Modify: `_game/scripts/managers/economy_manager.gd` (track + report run earnings)
- Modify: `_game/scripts/ui/game_over_panel.gd` (display earned cores, credits earned, best wave)
- Modify: `_game/scripts/core/audio_manager.gd` (wire `credits_spend_result`)

**Interfaces:**
- Consumes: lifetime `best_wave` (Task 2); `EventBus.credits_spend_result` (Task 6).
- Produces: `EventBus.run_summary(summary: Dictionary)` with keys `void_cores_earned` (int),
  `credits_earned` (BigNum), `best_wave` (int), emitted by EconomyManager at run end.

> Context (bugs this fixes — found in the Session 09 polish pass): the Game Over panel shows
> the *lifetime total* Void Cores under "VOID CORES EARNED" (via `void_cores_changed`), and its
> "CREDITS EARNED" / "BEST WAVE" rows are hardcoded "—". `_enemies_killed` is now supplied by
> GameManager (already fixed), so "ENEMIES KILLED" is correct.

- [ ] **Step 1: Track credits earned this run in EconomyManager**

Add a member `var _credits_earned_run: BigNum = BigNum.from(0.0)`. Reset it in `_on_game_started`
(`_credits_earned_run = BigNum.from(0.0)`). In `add_credits`, after computing the gained amount,
add it: `_credits_earned_run = _credits_earned_run.add(BigNum.from(amount * _credit_multiplier))`.

- [ ] **Step 2: Declare and emit `run_summary` at run end**

Add to `event_bus.gd` Economy block: `signal run_summary(summary: Dictionary)`. In
`economy_manager._on_run_ended`, after computing `cores` and writing lifetime stats, emit:

```gdscript
	EventBus.run_summary.emit({
		"void_cores_earned": cores,
		"credits_earned": _credits_earned_run,
		"best_wave": SaveManager.get_value("lifetime", "best_wave", 0),
	})
```

- [ ] **Step 3: Display real values in the Game Over panel**

In `game_over_panel.gd`: capture the BEST WAVE row label (store the return of its
`_add_stat_row`). Connect `EventBus.run_summary.connect(_on_run_summary)` in `_ready`.
Replace the `void_cores_changed` dependency for the reward with:

```gdscript
func _on_run_summary(summary: Dictionary) -> void:
	_reward_val.text = "+%d vc" % int(summary.get("void_cores_earned", 0))
	var earned: BigNum = summary.get("credits_earned", BigNum.from(0.0))
	_credits_earned_val.text = earned.to_display()
	_best_wave_val.text = str(int(summary.get("best_wave", 0)))
```

Remove the `_on_void_cores_changed` reward overwrite (keep the chip count elsewhere if needed).
Order is safe: GameManager emits `game_over` → EconomyManager `_on_run_ended` runs (computes
cores, emits `run_summary`) within that dispatch, so the panel updates after it is shown.

- [ ] **Step 4: Wire in-run purchase audio**

In `audio_manager._wire_events`, add:

```gdscript
	EventBus.credits_spend_result.connect(_on_spend_result)
```

(`_on_spend_result` already plays `purchase_ok`/`purchase_fail` — it now serves both currencies.)

- [ ] **Step 5: Verify via Godot MCP**

Play a run, buy some upgrades, die. Game Over shows: ENEMIES KILLED non-zero, CREDITS EARNED =
total banked this run, VOID CORES EARNED = this run's cores only (not lifetime total), BEST WAVE
= the persisted best. Confirm a purchase plays a sound (once audio assets exist).

---

## Self-review notes (author)

- **Spec coverage:** A (shop) → Tasks 6–8; A pricing → Task 7; hide no-op → Task 8; discount hook → Task 7 (`_discount_mult`). B exponential → Task 3; B tiers → Tasks 4–5. C lifetime → Task 2; C versioning → Task 1; encryption correctly deferred (not in plan).
- **Known deferrals (carry to SESSION.md):** `core_recycler`/`combat_log`/`wave_forecast` not added (absent from panel); several meta effects (void_extractor, starting_credits, engine_coolant) remain unwired — pricing/gating only this pass; `engine_coolant`'s "-10% upgrade cost" not applied to in-run costs (only `upgrade_discount` is).
- **Type consistency:** `cost_for(int,int)->int`, `is_tier_unlocked(int)->bool`, `_cost_for(String)->int`, spend signals `(BigNum,String)`/`(String,bool)` are used identically across tasks. `Palette.AMBER` (credits/cost), `Palette.CORAL` (danger), `Palette.BAR_BG` all confirmed present in `palette.gd`.
