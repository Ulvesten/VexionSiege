# Vexion Siege — Economy, Progression & Persistence Pass (Session 09)

> Design spec. Locked via brainstorming on 2026-06-24.
> Supersedes the Session 08 credit-shop sketch in SESSION.md (numbers finalised here).
> When a decision changes, update this file first, then implement.

---

## Goal

Turn the in-run upgrade selection into a paid **credit shop**, make the Spaceport meta-shop
feel like real long-tail progression (exponential pricing + tiered, progression-gated unlocks),
and lay the **persistence foundation** (lifetime stats + save versioning) those systems depend on.

Three coupled subsystems, one spec. Build order is driven by dependency:
**Save foundation → Spaceport → in-run credit shop.**

---

## Architectural constraints (from CLAUDE.md — do not violate)

- All inter-system comms via **EventBus**. No manager calls another manager directly. UI must
  not call `EconomyManager` directly — it goes through EventBus request/result signal pairs.
- Managers update via **TickSystem.tick**, never raw `_process()`.
- Economy values use **BigNum** (credits). Void Cores / Gems are plain ints (small, capped).
- New EventBus signals are declared in `event_bus.gd` before use.
- Known existing debt (NOT addressed this pass): enemy/upgrade data is hardcoded in scripts
  rather than `.tres` Resources. Flagged for a later pass; do not refactor it here.

---

## A. In-run credit shop

### Behaviour (locked)
- Shown on wave clear, **paused** (TickSystem.pause), slides up. Unchanged from current panel.
- **One buy per wave clear.** After a successful buy the panel slides down and the wave advances.
- **10s countdown.** At 0s, auto-buy a random **affordable** offer; if none affordable, skip
  (advance with no purchase). A draining countdown bar (amber→red) shows in the header.
- Credits **persist within a run**, reset only on death (already true in `economy_manager`).
- The bottom-HUD **UPGRADES** button stays a read-only review (shows climbing levels + next cost).

### Pricing (locked)
```
cost = round(rarity_base × 1.55 ^ (that upgrade's current level)) × discount_mult
rarity_base:  Common 5 | Rare 18 | Epic 50 | Legendary 150
discount_mult: default 1.0; if Spaceport "Upgrade Discount" owned, = 1 - 0.05 × level (floor 0.75)
```
Calibration anchor: wave-1 clear yields ~6 credits, so a level-0 Common (5) is always
affordable on the first wave. Cumulative early income ≈ 6 / 13 / 23 / 35 / 50 by wave 1–5.
Same-line repeats climb (Common 5→8→12→19→29…), pushing diversification — intended tension.

### Offer pool
- `chain_lightning`, `explosive_round`, `second_wind` are **hidden from the pool** until their
  effects are implemented. Add an `enabled: false` (or omit) flag per pool entry; `_pick_three`
  excludes disabled entries. Re-enable each when its combat effect ships.

### Architecture (EventBus-pure)
New signals in `event_bus.gd` (mirror the existing Void-Cores pair):
```
signal credits_spend_requested(amount: BigNum, context: String)
signal credits_spend_result(context: String, success: bool)
```
- `economy_manager.gd`: add `_on_credits_spend_requested(amount, context)` → calls existing
  `spend_credits(BigNum)` → emits `credits_spend_result(context, success)`. Synchronous, so the
  request→result round-trips in one call stack (no real async).
- `upgrade_panel.gd`: tracks live credits via `credits_changed`; computes each card's cost from
  its `_levels` mirror; shows cost (amber + credit icon) and greys/disables unaffordable cards
  (red cost). On tap / auto-pick, emit `credits_spend_requested`; on success emit the existing
  `upgrade_purchased(id)` (UpgradeManager + StatsPanel + the panel mirror update unchanged).
- Auto-pick at 0s filters offers to the affordable subset before random-choosing.

### Files
`event_bus.gd` (2 signals), `economy_manager.gd` (spend handler + discount hook),
`upgrade_panel.gd` (cost/affordability/countdown bar/spend, pool-disable flag). No scene changes.

---

## B. Spaceport meta-shop

### Pricing (locked)
```
cost = round(base × 1.6 ^ level)    # leveled upgrades
```
Each upgrade keeps its own DESIGN base. **Galaxy one-time unlocks stay flat** (no level).
Replaces the current linear `cost = base × (level + 1)` in `spaceport_system.try_purchase`.

Reference (Reinforced Hull, base 10): L1 16, L3 41, L5 105, L10 1100.
Void-Core income for context: reach wave 25 ≈ 7 cores, 50 ≈ 15, 100 ≈ 25, 200 ≈ 40.

### Tiered, progression-gated unlocks (locked)
Tiers unlock by **best wave ever reached** (a persisted lifetime stat — see §C). Each tier is
+50 best-wave past the previous, so thresholds are **0 / 50 / 100 / 150**. A whole tier unlocks
at once. Locked terminals render greyed with "Reach Wave N to unlock" as a visible goal.

| Tier | Unlock (best wave ≥) | Upgrades (own base cost) |
|---|---|---|
| 1 Core      | 0   | Reinforced Hull (10), Reactor Boost (15), Starting Credits (10) |
| 2 Combat    | 50  | Shield Generator (25), Targeting System (20), Void Extractor (20) |
| 3 Advanced  | 100 | Engine Coolant (30), Upgrade Discount (25), Core Recycler (40) |
| 4 Utility   | 150 | Combat Log (30), Galaxy Scanner (50), Wave Forecast (75), Fast Forward (100) |

### Data shape
Spaceport upgrade definitions need `base_cost`, `tier`, and the tier→unlock_wave map. Keep the
existing hardcoded-definition style for this pass (consistent with current code); centralise the
unlock-wave thresholds as one constant `TIER_UNLOCK_WAVE := {1:0, 2:50, 3:100, 4:150}`.

### Architecture
- `spaceport_system.gd`: change cost formula to exponential; expose `is_tier_unlocked(tier)`
  / `unlock_wave_for(upgrade_id)` reading the persisted best-wave stat (via EventBus or a
  SaveManager read on open). Purchase flow (void-core request/result) is unchanged.
- `spaceport_panel.gd`: render locked tiers greyed with "Reach Wave N to unlock"; show each
  upgrade's own next cost.

### Files
`spaceport_system.gd`, `spaceport_panel.gd`. No new autoloads.

---

## C. Save / persistence foundation

Current `save_manager.gd` is a working `ConfigFile` section/key store (`user://savegame.cfg`).
Already persisted: void_cores, gems (economy), spaceport upgrades, audio settings. Gaps:

### Add lifetime stats (locked)
A `lifetime` save section, updated at run end (in `economy_manager._on_run_ended` or a dedicated
stats path):
- `total_void_cores_ever` — running sum of cores earned (for prestige `floor(sqrt(total/100))`).
- `best_wave` — `max(best_wave, wave_reached)` (drives Spaceport tier gating in §B).
- `total_runs` — incremented each run end.

Expose reads via SaveManager (`get_value("lifetime", ...)`) and/or an EventBus broadcast so the
Spaceport panel can gate tiers without a direct manager reference.

### Save versioning (locked)
- Add a `meta.version` key (start at `1`). On load, if missing/older, run a `_migrate(from, to)`
  hook (no-op for v1) before use. Protects future schema changes from wiping players.

### Deferred (NOT this pass)
- **Encryption** — keep plaintext `.cfg` during dev for easy inspection; switch to
  `FileAccess.open_encrypted` as a Phase 7 launch-hardening task.
- Save-cadence batching (currently writes on every currency change) — acceptable for now.

### Files
`save_manager.gd` (version + migration hook + lifetime helpers), `economy_manager.gd`
(write lifetime stats at run end). Possibly one EventBus signal for best-wave broadcast.

---

## Build order

1. **Save foundation** — `best_wave` + lifetime stats + version/migration. (Unblocks B's gating.)
2. **Spaceport** — exponential pricing + tier gating + panel locked-state rendering.
3. **In-run credit shop** — spend signals, cost/affordability/countdown UI, hide no-op upgrades.

## Testing notes (Godot 4.7, run via MCP)
- MCP cannot drive Godot's GUI click pipeline; verify button behaviour by real tap or by
  inspecting node state (`get_ui_elements` / `get_node_info`). Auto/timer paths run fine.
- Per-system: wave-1 clear can afford a Common; auto-buy at 0s picks only affordable; Spaceport
  tiers grey/ungrey at the right best-wave; exponential costs match the table; lifetime stats
  survive a quit+relaunch.

## Out of scope (future sessions)
Implementing chain_lightning/explosive_round/second_wind effects; abilities; prestige tree;
ShopPanel/IAP; data→.tres migration; save encryption.
