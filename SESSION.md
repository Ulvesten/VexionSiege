# Vexion Siege — Session State

> This file is the handoff document between sessions.
> Update it at the end of every session. Claude Code reads it at session start.
> Keep it short and factual — no paragraphs, just state.

---

## Current status
**Session 09: locked all economy/progression direction, wrote the spec + implementation
plan, and did a codebase polish pass that caught 4 real bugs (1 critical).** No Godot MCP
this session (only Unity/coplay MCP available), so code fixes are reasoned, not runtime-
verified — re-test when Godot is up. The credit-shop numbers + Spaceport pricing/unlock model
are now fully decided (see "Session 09" below). Next session = EXECUTE THE PLAN.

## ⏭️ NEXT SESSION — TEST THE IMPLEMENTATION IN GODOT (all 9 plan tasks CODE-COMPLETE, UNVERIFIED)
The full economy/progression plan was implemented this session **without Godot** (only Unity
MCP available), so NOTHING is runtime-verified. Open Godot, fix any parse errors, then test:
1. **Save**: die → relaunch → Void Cores/Spaceport/best_wave persist; `meta/version=1` written.
2. **In-run shop**: wave-1 clear → a Common shows `5₵` amber and is buyable (~6 cr); buying
   deducts credits + advances; unaffordable cards grey/coral; countdown bar drains amber→red;
   at 0s a random AFFORDABLE card auto-buys (or skips if none); the 3 no-op upgrades never offer.
3. **Spaceport**: costs scale ×1.6/level; Tier-1 buyable, Tier-2+ greyed "🔒 Wave 50/100/150";
   reaching the threshold (best_wave) un-greys a tier on reopen.
4. **Game Over**: ENEMIES KILLED non-zero; CREDITS EARNED = this run; VOID CORES EARNED = this
   run only (not lifetime total); BEST WAVE filled; boss kills add +5 cores each.
5. **Meta-loop**: die → Spaceport → START NEW RUN → wave 1 begins (the critical fix).
- Spec:  `docs/superpowers/specs/2026-06-24-economy-progression-pass-design.md`
- Plan:  `docs/superpowers/plans/2026-06-24-economy-progression-pass.md` (9 tasks, all done)

### Implementation notes / deviations from the plan (read before testing)
- **SpaceportSystem is NOT an autoload** (scene node, no class_name) — so `spaceport_panel.gd`
  computes cost + tier-unlock LOCALLY (mirrors `upgrade_panel`), not via `SpaceportSystem.*`.
  The plan's Task 5 code was corrected on this point. `spaceport_system.gd` still owns the
  authoritative `cost_for`/`is_tier_unlocked`/`unlock_wave_for_tier` (model layer).
- **Game Over ordering**: EconomyManager (GameField) readies before GameOverPanel (UI), so its
  `run_summary` fires BEFORE the panel's `_on_game_over`. The panel therefore lets `run_summary`
  own the reward/credits/best-wave rows and `_on_game_over` only sets wave/enemies/visibility.
- Files touched: save_manager, economy_manager, event_bus (+credits_spend_*/run_summary),
  spaceport_system, spaceport_panel, upgrade_panel, game_over_panel, audio_manager.

## ✅ Session 09 polish fixes APPLIED (re-test when Godot runs)
- **CRITICAL — meta-loop dead-ended after first death** (`game_manager.gd`): nothing called
  `start_run()` after the Spaceport closed; "RUN AGAIN" / "START NEW RUN" only set MENU state.
  Now `_on_spaceport_closed` → `start_run()`. ⇒ TEST: die → Spaceport → START NEW RUN → wave 1
  begins; also Game Over → RUN AGAIN restarts.
- **Boss kills never rewarded Void Cores + Game Over showed 0 enemies** (`game_manager.gd`):
  game_over emitted `enemies_killed:0` and no `boss_kills`, so `floor(wave/10)+boss*5` lost the
  boss bonus. GameManager now tallies `enemy_killed` (+ boss subset) and emits both. ⇒ TEST:
  kill a boss, die → Game Over "ENEMIES KILLED" non-zero; Void Core reward includes +5/boss.
- **Prestige Star Shards always 0** (`prestige_manager.gd`): read a never-written
  `economy/void_cores_ever`; now reads the canonical `lifetime/total_void_cores_ever` (written
  by the save-foundation task). Latent until wave-500 prestige ships.
- **Dead crit-colour assignment** (`effect_layer.gd`): AMBER was set then immediately
  overwritten for crits; collapsed to one line. Cosmetic.

## 🌌 Spaceport progression bands (DECIDED + IMPLEMENTED this session)
The 4 Spaceport tiers are now cosmetic **space-region bands** — deliberately SEPARATE from the
gameplay Galaxies (Milky Way/Andromeda/Triangulum) to avoid name/threshold collisions. Each
band has a name + colour shown as a card eyebrow + tinted card border (Spaceport panel only):
- T1 (best-wave ≥0):  **INNER CORE** — green
- T2 (≥50):           **OUTER RIM**  — blue
- T3 (≥100):          **DEEP VOID**  — purple
- T4 (≥150):          **FRONTIER**   — amber
`spaceport_panel._band_for(tier)`. ⇒ TEST: cards in each band show the right name/colour; locked
bands stay greyed with "🔒 Wave N".

## ⏳ Still open (not done)
- `ability_manager` overclock never reverts (its boosted emit trips its own listener) — fix
  when abilities are actually wired; it's an unused stub today.

## 🐛 Logic fixes this session (need a play-test to confirm in motion)
- **UpgradePanel didn't compile** — `_on_auto_tick` and `_on_upgrades_toggle_requested` were
  connected in `_ready` but never defined (GDScript = compile error → whole panel dead).
  Implemented both: 10s auto-pick countdown on wave clear, and a read-only manual review via
  the bottom-HUD UPGRADES button. ⇒ TEST: clear a wave, see the countdown, let it auto-pick
  AND tap-pick; tap UPGRADES mid-run → read-only review, tap again to close.
- **Upgrade stats compounded wrong** (`upgrade_manager.gd`) — `_calculate_stat` read the base
  from the already-upgraded value, so level 2 fire_rate was 1.12³ not 1.12², max_hp L2 = 160
  not 140, etc. Now computes from a run-start `_base_stats` snapshot. ⇒ TEST: take Max HP twice
  → 100→120→140 (not 160); Fire Rate scales 1.12^level.
- **Max-level upgrades now excluded** (DESIGN §137) — added `max` to each pool entry; maxed
  upgrades drop out of the offer; cards show real "Lv N/Max". ⇒ TEST: a capped upgrade stops
  being offered; card level label updates after picks.

## ❓ Design questions for you
- **Credits sink — DECIDED (Session 08): in-run upgrades now cost Credits.** Wave-clear shop,
  one buy per wave, cost scales by each upgrade's own level, 10s auto-buy-affordable timer.
  Full spec in the Session 08 section. (Supersedes the old free choose-one model.)
- **Unimplemented upgrade effects** — `chain_lightning`, `explosive_round`, `second_wind` are in
  the offer pool but have no effect wired in UpgradeManager/AutoFireSystem (they no-op safely).

## ⚠️ MUST TEST WHEN GODOT OPENS (Sessions 06 + 07 — written without Godot running)
Open the editor once so it imports the new `.jpg` icons (generates `.import` files), then play:
1. **Icons import cleanly** — editor shows no import errors for the 4 `icon_*.jpg`. NB they
   are JPGs with dark backgrounds; on the dark UI they should blend, but a faint square halo
   may show. If so, re-export as transparent PNGs (update paths in `ui_icons.gd`).
2. **HUD** — credits icon (amber hex) sits left of "CREDITS"; gear icon replaces the 3-line
   hamburger (top-right). Both should be crisp at their sizes (40px / 56px).
3. **Spaceport** — top-right Void Cores chip shows the purple gem icon instead of the dot.
4. **Game Over** — reward block shows the void-core gem icon instead of the ◈ glyph.
5. **Audio** — game runs silent with NO errors (no audio files yet). Drop files per
   `_game/assets/audio/README.md` to hear them; verify SFX fire on kill/hit/wave/purchase
   and music swaps combat↔spaceport.
6. **Enemy variants (S06)** — drone grey, bruiser big dark-grey, swarm tiny pale, shielder
   blue, bomber orange, boss huge coral. Elites render brighter.
7. **Death particles (S06)** — colour-matched dot burst on kill; bigger/faster for bosses.
8. **UpgradePanel (S07 fixes)** — see "Logic fixes this session" tests above.

Remaining Phase 5: font import (external TTFs), enemy *sprite* art (needs crop+transparency,
see blockers), optional boss freeze-frame.

---

## What's working
- Full game loop: wave → enemies → auto-fire → kill → credits
- All 6 autoloads registered and running (added CameraManager)
- All managers running clean
- **Phase 5 polish (all verified):**
  - **Starfield** (`starfield_layer.gd` on Background/StarfieldLayer): 3 parallax layers
    (speeds 30/70/150 px/s), 25 stars each, white + light-blue, opacity 0.2–0.9, size 1–3px,
    wraps at screen bottom, driven by TickSystem (responds to game speed). `_draw()` based.
  - **Damage numbers** (`effect_layer.gd` on GameField/EffectLayer): pool of 20 Labels,
    fires on `enemy_damaged(pos, amount, is_crit)`. White size-32 normal, yellow size-42 bold
    crit. Floats up 40px / 0.6s + fade. BigNum format ≥1000. Oldest reused if pool full.
  - **Credit popups** (same EffectLayer pool): fires on `credit_awarded(pos, amount)`.
    Amber (#f5a020) "+N" size-26, floats toward CREDITS counter (120,1840) over 0.8s,
    shrinks to 0.6× as it arrives.
  - **Screen shake** (`camera_manager.gd` autoload + Camera2D at 540,960):
    `shake(intensity, duration)` applies decaying random offset each tick. Wired:
    ship_damaged→shake(4,0.2) [guarded amount>0], shield_broken→shake(6,0.3),
    boss enemy_killed→shake(12,0.6). Stronger shake overrides weaker in progress.
  - **Wave announcement** (`wave_announcement.gd` on UI/WaveAnnouncement, layer 20):
    "WAVE N" (Space Mono bold white 110px) + "COMPLETE" (Rajdhani blue #4488ff 60px),
    fade in 0.3s / hold 1.0s / fade out 0.4s. Tween-driven (runs through TickSystem pause).
- Background: deep space blue #050A1A (project clear_color), set per user request
- **UI styling system complete:**
  - `palette.gd` — all :root CSS vars as GDScript Color constants
  - `ui_styles.gd` — StyleBoxFlat factory (panel, bars, buttons, rarity tints)
  - `ui_fonts.gd` — Space Mono + Rajdhani via SystemFont (falls back; load TTFs to unlock)
- **HUD (combat screen):** WAVE badge (#4488ff mono 33px) + wave number (white 66px bold)
  + hamburger menu + HP bar (red, styled, 15px) + "HP" / "98/100" labels + bottom strip
  with "CREDITS" (muted) + amber value. All correct colours from mockup :root.
- **UpgradePanel:** full card layout with rarity tints (common/rare/epic/legendary),
  icon well (S2 bg), name (42px display bold), desc (33px display muted), rarity dot,
  level, cost. Slides up from y=1960→1400. 3× scale from mockup.
- **GameOverPanel:** "RUN ENDED" (coral 27px mono) + "Ship Destroyed" (108px display bold)
  + stats table (S1 panel, BORDER2 border, BORDER row dividers) + void cores reward block
  (purple tint) + 3 buttons (amber/blue/muted)
- **SpaceportPanel:** header with currency chips (pill-shaped, S2 bg) + tabbed grid of
  upgrade cards (2-col) + "START NEW RUN" primary button. ChipResult inner class used for
  clean val-label ref passing.
- `ObjectPool.acquire()` (renamed from conflicting `.get()`)
- Ship visual: blue Polygon2D triangle at (540, 1700)
- All manager/EventBus architecture clean

---

## What's broken / blockers
- **Minor: wave number clipped in HUD** — the "001" wave number (font 110) appears slightly
  clipped under the top bar / HP bar. Cosmetic; lower the font size or give the top bar more
  height in `hud.gd`.
- **Godot editor parse errors** ("EventBus not declared") — editor-only, game runs fine.
  Fix: restart Godot editor.
- **Fonts fallback to system fonts** — Space Mono and Rajdhani not imported yet. Place TTFs
  at `res://_game/assets/fonts/` (SpaceMono-Regular/-Bold, Rajdhani-SemiBold/-Bold).
  `ui_fonts.gd` auto-picks them up. (Mono/sans fallbacks currently render correctly.)
- **Audio files not present** — AudioManager is now fully implemented but `_game/assets/audio/`
  is empty. It runs silent until WAVs/OGGs are added per `audio/README.md`. No code change
  needed to enable — just drop files with the exact names.
- **Enemy sprite art unusable as-is** — the 5 PNGs in `assets/sprites/enemies/` are coral-red
  art on OPAQUE BLACK backgrounds with ~85% empty padding. Not wired into enemies (would show
  black squares + tiny creatures). To use: crop to the art + export transparent PNG, OR set the
  enemy Sprite2D's `blend_mode` to additive (CanvasItemMaterial) so black reads as transparent
  (suits the glow, but dims dark-red fills). Best decided in-editor. Boss is coral-red so these
  are a natural boss/elite skin once processed.
- **Boss death freeze-frame (0.1s)** — DESIGN §341 calls for it; deferred (would need a brief
  TickSystem/time_scale pause). Boss death already has the big burst + shake(12,0.6).

---

## Key architecture note — main.tscn
The four UI CanvasLayer nodes (HUD, UpgradePanel, GameOverPanel, SpaceportPanel) have
**NO scene children** — all UI is built in code by each script's `_build()`.
Godot's auto-save-before-play previously kept overwriting the file with old nodes.
After this session the scene is clean (saved via MCP delete + scene_save).
If old nodes reappear: use `node_manage(delete)` on /Main/UI/HUD/TopBar,HPBar,ShieldBar,
CreditsLabel and /Main/UI/UpgradePanel/Panel, /Main/UI/GameOverPanel/Panel,
/Main/UI/SpaceportPanel/Panel — then save via MCP.

---

## Last session — 2026-06-23 Session 08 (ran the game live; 2 bug fixes + credit-shop design)

### Ran the game via Godot MCP (godot-ai server), Godot 4.7-stable, main.tscn
- Game loop confirmed healthy live: waves spawn, ship auto-fires, kills bank credits, waves
  advance. HUD gear icon + credits icon render. Starfield + enemies render on #050A1A bg.
- Editor logs show only the 5 unused enemy-sprite `.png` import errors (the opaque-black art
  documented in blockers) — NOT wired into the game, harmless. No script parse errors.
- **MCP input limitation discovered:** `game_manage(input_mouse ...)` injects events that do
  NOT reach Godot's Control/GUI pipeline — on-target button clicks (verified coords in both
  window 405×720 and canvas 1080×1920 space) never fire `pressed`. So UI buttons can't be
  driven from the MCP; verify button behaviour by a REAL tap, or inspect node state via
  `game_manage(get_ui_elements / get_node_info / get_scene_tree)`. Auto/timer paths still run.

### BUG FIX 1 — UPGRADES button soft-lock (FIXED in `_game/scripts/ui/upgrade_panel.gd`)
- Root cause: tapping bottom-HUD UPGRADES → `_on_upgrades_toggle_requested` opened a read-only
  review that (a) called `TickSystem.pause()` and (b) slid the 820px panel up over y1100–1920,
  fully covering the bottom HUD (anchored y≈1724–1920) where the UPGRADES button lives. The
  UpgradePanel CanvasLayer is above HUD, its opaque Panel (mouse_filter STOP) ate all clicks
  there, and review-mode cards are `disabled` → NO reachable control to close + game paused =
  hard soft-lock. (Wave-clear mode never locked because you close it by tapping a card.)
- Fix: added a transparent full-panel **close-catcher Button** (`_close_catcher`) added last to
  `_panel` so it's topmost; `visible=true` only in manual review mode (cards disabled there, no
  conflict), `visible=false` on wave-clear (cards must stay tappable) and on slide-down. Footer
  now reads "REVIEW — TAP ANYWHERE TO CLOSE".
- Verified structurally on the live game: catcher node present, full-rect 1080×820, correctly
  `visible:false` during wave-clear. Could not button-drive the close (MCP input limit) — needs
  a real tap to confirm, but logic + node state are correct.

### BUG FIX 2 — STATS button did nothing (FIXED by adding the node to main.tscn)
- Root cause: `_game/scripts/ui/stats_panel.gd` was fully implemented (connects
  `stats_toggle_requested`, builds a slide-up grouped stats panel, layer=11) but **no StatsPanel
  node existed in `main.tscn`** → script never ran → STATS button emitted into the void.
- Fix: added `StatsPanel` CanvasLayer under `/Main/UI` + attached `stats_panel.gd` via MCP
  (node_create + script_attach + scene_save) so the editor's in-memory scene + disk match
  (avoids the autosave-clobber trap). New ext_resource id `21_3w7h5`, uid b2ucjmm1kea1f.
- Verified live: `/Main/UI/StatsPanel` present in the running tree with its Panel built
  (→ `_ready` ran → signal connected). Real-tap confirmation of the open/close still pending.

### Bug A "Lv 0/20 not increasing" — root cause + resolution path
- The wave-clear pick already increments levels correctly (`upgrade_panel._choose` +
  `upgrade_manager._on_upgrade_purchased`); user saw "no increase" because they were in the
  read-only manual UPGRADES review (cards disabled → can't pick). Resolved holistically by the
  credit-shop design below (levels climb on purchase → reflected in shop cards, StatsPanel, and
  the read-only review).

### CREDIT-SHOP SPEC (design APPROVED in principle; only base numbers unconfirmed) — BUILD NEXT
User decisions (locked): wave-clear gated + paused; cards cost Credits; **one buy per
wave-clear**; cost scales **by each upgrade's own level**; **10s countdown** with a visible
indicator; at 0s **auto-buy a random AFFORDABLE offer, else skip** (continue with none).
Outside runs stays Void-Cores→permanent (Spaceport, already exists).
- **Cost formula (constants = tweakable balancing, my proposal — confirm with user):**
  `cost = rarity_base × 1.55^(that upgrade's current level)`;
  rarity_base credits: Common 15, Rare 40, Epic 100, Legendary 250.
  (Calibrated to income: wave1 ≈ 6 credits; drone=1, bruiser=4, shielder=6, bomber=8, boss=50+.)
  Optional Spaceport "Upgrade Discount" hook: read a discount mult if present, default 1.0.
- **Architecture (keep EventBus rule — UI must NOT call EconomyManager directly):** add the
  Void-Cores-style pair to `event_bus.gd`: `credits_spend_requested(amount, context)` →
  `economy_manager.gd` spends (mirror `_on_void_cores_spend_requested`, uses existing
  `spend_credits(BigNum)`) → `credits_spend_result(context, success)`. Panel tracks live credits
  via `credits_changed`, computes per-card cost, shows affordability; on tap/auto-pick emits the
  spend request and on success emits the EXISTING `upgrade_purchased(id)` (so UpgradeManager +
  StatsPanel + the panel's `_levels` mirror update unchanged). Signals are synchronous so the
  request→result round-trips in one call stack (no real async).
- **Panel UI changes (`upgrade_panel.gd`):** show each card's cost (amber + credit icon);
  grey/disable unaffordable cards (red cost); add a draining **countdown bar** in the header
  (amber→red over 10s) alongside the existing "Auto-select in Ns" footer; keep one-buy-then-
  advance; auto-pick at 0s filters offers to affordable ones. Keep the bottom UPGRADES button as
  the read-only review (now shows climbing levels + each upgrade's next cost).
- **Files:** `event_bus.gd` (2 signals), `economy_manager.gd` (spend handler), `upgrade_panel.gd`
  (cost/affordability/countdown/spend). No scene changes. Use `superpowers:writing-plans` then TDD.

## Earlier session — 2026-06-23 Session 07 (icons + audio, no Godot running)
- **New `ui_icons.gd` (`UIIcons`)** — texture factory mirroring `UIFonts`: `credits()`,
  `void_cores()`, `star_shards()`, `settings()` load with `ResourceLoader.exists()` guards and
  cache (null cached too). `make_rect(tex, px, modulate)` returns a sized TextureRect or null.
- **Icons wired (all with glyph/dot fallback if texture missing):**
  - HUD: credits hex left of "CREDITS" (40px); gear replaces hamburger lines (56px).
  - Spaceport: Void Cores chip uses the gem icon (extended `_make_currency_chip` w/ optional
    `icon` param). Gems chip still a teal dot (no gem icon supplied).
  - Game Over: reward block uses gem icon in a CenterContainer (keeps the 120px slot).
  - `star_shards` icon NOT yet used — reserved for the future Prestige UI.
- **AudioManager fully implemented** (was a 3-method stub): registry of 13 SFX + 2 music
  tracks, 8-voice round-robin SFX pool, single music player with loop-restart fallback.
  Volume (master/sfx/music) + mute persist to save `settings` section. Auto-wired to EventBus:
  enemy_killed→(boss_)explode, ship/shield damage, shield_break, upgrade_purchased,
  void_cores_spend_result→ok/fail, wave_started/completed, prestige, game_over; music follows
  game_started/spaceport_opened/closed/game_over. Every path no-ops if the asset is missing.
- **Created `_game/assets/audio/README.md`** documenting the exact filenames AudioManager wants.
- **Enemy sprites NOT wired** — opaque black bg + heavy padding; documented in blockers.
- **Core-loop logic fixes (same session, no Godot):**
  - Fixed UpgradePanel compile error (2 connected-but-undefined methods) → implemented auto-pick
    countdown + read-only manual review. The panel previously could not load at all.
  - Fixed `upgrade_manager._calculate_stat` compounding bug via a `_base_stats` run-start
    snapshot (upgrades now scale from the original base, not the running value).
  - Added max-level data to the upgrade pool + exclusion in `_pick_three`; cards show "Lv N/Max".
  - Audited every bare-identifier `.connect()` across all game scripts + confirmed all five data
    Resource classes exist — UpgradePanel was the only broken script.
- **Verification:** none runtime — Godot binary still absent (only console-launcher stub).
  Validated by API review (signal arg-count matches on all lambda connects, AudioStreamPlayer
  API, TextureRect enums, linear_to_db). See "MUST TEST WHEN GODOT OPENS" at top.

## Earlier session — 2026-06-23 Session 06 (enemy variants + death particles)
- **Enemy colour variants** (`palette.gd` + `enemy_manager.gd`): added `Palette.enemy_color(type)`
  and `Palette.enemy_scale(type)` from DESIGN §349. New `_apply_visual()` in EnemyManager tints
  the `Visual` ColorRect and scales the CharacterBody2D per type on every pool acquire:
  drone #b0bec5 (1.0×), bruiser #78909c (1.8×), swarm #cfd8dc (0.5×), shielder #4fc3f7 (1.1×),
  bomber #ff8a50 (1.2×), boss #ff5566 (3.0×). Elites render lightened(0.35).
- **Death explosion particles** (`effect_layer.gd`): pool of 8 `CPUParticles2D` bursts.
  On `enemy_killed` fires a colour-matched one-shot burst at the death position — 10 dots for
  normal enemies, 40 + faster/larger for boss (DESIGN §337-341). White→transparent `color_ramp`
  multiplies the type tint for a fade. `restart()` + `emitting=true`; oldest reused if all busy.
- **Verification:** could NOT run Godot — only the console-launcher stub is present in
  Downloads (real binary missing), and no Godot MCP available this session. Validated by manual
  GDScript/API review (signal signatures, CPUParticles2D 4.x property names, pool reset path)
  rather than runtime. Needs a runtime/visual check next session.
- Freeze-frame on boss death (DESIGN §341) deferred — see blockers.

## Earlier session — 2026-06-22 Session 05 (Phase 5 polish)
- Starfield: `starfield_layer.gd`, 3 parallax layers via `_draw()` + TickSystem, attached
  to Background/StarfieldLayer
- Damage numbers + credit popups: `effect_layer.gd` (20-label pool) on GameField/EffectLayer.
  Added EventBus signals `enemy_damaged(pos, amount, is_crit)` and `credit_awarded(pos, amount)`.
  AutoFireSystem rolls crit once at fire time, stores it on the projectile, emits on hit.
  EnemyManager adds death `position` to enemy_killed dict; EconomyManager emits credit_awarded.
- Screen shake: `camera_manager.gd` NEW AUTOLOAD (registered in project.godot) + Camera2D at
  (540,960). Decaying random offset via TickSystem. Verified offset reached (25.4, 2.2) mid-shake.
- Wave announcement: `wave_announcement.gd` on UI/WaveAnnouncement (layer 20). Verified visually
  showing "WAVE 1 / COMPLETE".
- Background: set project clear_color to #050A1A (user request) — was grey.
- Verification: damage/credit via runtime label property inspection; shake via camera offset
  inspection; starfield + wave announcement + background via screenshot. Temp debug shakes/holds
  added for verification then reverted.
- FIXED: UpgradePanel card overlap (pre-existing bug). Root cause: card `Panel` had no
  `custom_minimum_size`, so each card collapsed to ~0px and the VBox stacked them. Also the
  inner HBox used absolute `position` inside a non-layout Panel. Fix: gave cards a 150px min
  height, laid content out via a full-rect MarginContainer, full-rect Button overlay for taps,
  and enlarged the panel to 820px (rests at y=1100). Verified: cards render cleanly separated;
  tapping a card selects the upgrade, slides the panel down, and advances to the next wave.

## Earlier session — 2026-06-22 Session 04
- Created `palette.gd`, `ui_styles.gd`, `ui_fonts.gd` (utils)
- Rewrote all 4 UI scripts to build layouts in code matching mockup exactly
- Fixed `_make_currency_chip` bug (was returning wrong node, causing reparent crash)
- Fixed `set_corner_radius_all()` calls (doesn't exist in Godot 4 — set individually)
- Fixed `ui_fonts.gd._get()` override of `Object._get()` → renamed to `_load_font`
- Fixed spaceport tab_name type-inference issue (PackedStringArray literal)
- Deleted all stale scene children from HUD/UpgradePanel/GameOverPanel/SpaceportPanel
  via MCP and saved — disk now clean
- Verified: screenshot shows correct Palette colours, 3× typography, bottom HUD correct

---

## Current task — Phase 5 Polish

**Before any visual work: restart Godot** to clear editor parse errors.

### Next steps (priority order):
1. **Import fonts** — Space Mono + Rajdhani from Google Fonts → `_game/assets/fonts/`
2. **Starfield** — GPUParticles2D on StarfieldLayer: white dots, random screen coverage,
   slow twinkle animation matching mockup `.star` CSS `@keyframes twinkle`
3. **Wave announcement** — on `wave_started`, show centred "WAVE N" label that fades in/out
   over 1.5s (mock up has no explicit spec for this, keep it minimal)
4. **Damage numbers** — on `enemy_killed`, spawn a Label at kill position floating up and
   fading. Color white, font mono 27px. Credit pickup in amber.
5. **Screen shake** — Camera2D on Ship, small random offset tween on `ship_damaged`
6. **Enemy colour variants** — bruiser (#78909c darker), boss (distinct large shape)

---

## Implementation order (full roadmap)

### Phase 1 — Core systems ✅
### Phase 2 — Game field ✅
### Phase 3 — Economy and upgrades ✅
### Phase 4 — Meta layer ✅ (SpaceportSystem, ShieldSystem, stubs for Ability/Prestige)

### Phase 5 — Polish and feel
- [x] Starfield particles (3-layer parallax)
- [x] Wave announcement label
- [x] Damage numbers
- [x] Screen shake on damage (CameraManager autoload)
- [x] Credit popup from kill position
- [ ] Font import (Space Mono, Rajdhani) — fallbacks render fine for now
- [x] Enemy colour variants per type
- [x] Death explosion particles

### Phase 6 — Persistence and IAP
- [ ] SaveManager full implementation
- [ ] PrestigeManager full
- [ ] ShopPanel
- [ ] IAP integration

### Phase 7 — Export
- [ ] Android / HTML5 export

---

## Key decisions made
- GDScript only — no C#
- TickSystem drives all managers — no raw `_process()` in managers
- EventBus for all inter-system comms — no direct manager references
- BigNum for economy values
- ObjectPool.acquire() (not .get())
- UI layouts built entirely in code (not in .tscn) so Godot autosave can't corrupt them
- 3× scale from mockup (mockup at 360px, game at 1080px)
- ui_fonts.gd auto-loads TTFs when present; falls back to SystemFont
- SpaceportPanel.ChipResult inner class for safe label ref passing (no fragile get_child)
- Ship damage chain: enemy_reached_ship → ShieldSystem → ship_hull_damaged → ShipManager
- UpgradePanel emits `ready_for_next_wave` after pick; WaveManager starts next wave
- CameraManager is an autoload (6th) — justified: needs global access + own tick subscription;
  user explicitly requested it as an autoload
- Crit is rolled once at fire time in AutoFireSystem and carried on the projectile, so the
  damage dealt and the floating number always agree
- EffectLayer labels are pooled (20) and reused oldest-first; float tweens run on SceneTree
  (not TickSystem) so they animate even while the upgrade-select pause holds TickSystem
- Camera2D at viewport centre (540,960) preserves exact framing (anchor center) while giving
  shake an offset to drive; only the 2D world shakes, CanvasLayer HUD stays fixed
