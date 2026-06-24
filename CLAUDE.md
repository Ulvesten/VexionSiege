# Vexion Siege — Claude Context

## What this file is
Permanent project context. Read this at the start of every session before touching any code.
Current task and session state live in SESSION.md. Design decisions live in DESIGN.md.

---

## Project overview
Mobile idle space tower defense. Portrait orientation (1080×1920).
The player defends a spaceship against endless waves of enemies.
Waves scale into the thousands. The game never truly ends — it gets harder until you die, then you meta-upgrade and go again.
Platforms: Android, iOS, browser (HTML5 export).
Monetisation: free with IAP (premium currency, cosmetics, convenience upgrades).
Visual inspiration: Idle Dot Shooter (minimalist, particle-heavy, modern).
Gameplay depth inspiration: The Tower — Idle Tower Defense.

---

## Tech stack
- Engine: Godot 4 (latest stable), GDScript only — no C#, no C++
- Renderer: Mobile (set at project creation — do not change)
- Orientation: Portrait locked
- Base resolution: 1080 × 1920, stretch mode canvas_items, aspect expand
- Version control: Git, sparse commits at milestones only

---

## Architecture rules — read before writing any code

### EventBus
All inter-system communication goes through a global EventBus autoload.
No manager holds a direct reference to another manager.
Pattern: `EventBus.emit_signal("enemy_killed", enemy_data)` — never `EnemyManager.on_enemy_killed()`.
New signals must be declared in EventBus.gd before use.

### Autoloads (global singletons)
Registered in Project Settings → Autoload. Accessible everywhere by name.
```
EventBus       — signal hub, no logic
GameManager    — run lifecycle, game state machine
SaveManager    — serialise/deserialise all persistent data
AudioManager   — sound effects and music
```
Do not add new autoloads without a strong reason. Prefer instancing a scene.

### Managers (one per domain, instanced in Main.tscn)
Each manager owns exactly one domain. They communicate only via EventBus.
```
WaveManager      — spawns waves, tracks wave number, calculates enemy count/speed
EnemyManager     — enemy pool, movement, HP, death
AutoFireSystem   — ship fires automatically, calculates targets, projectile pool
ShieldSystem     — shield HP, regen, visual state
UpgradeManager   — applies in-run upgrade effects to ship stats
EconomyManager   — credits earned/spent during a run
SpaceportSystem  — meta-upgrade hub, persists between runs
AbilityManager   — active abilities, cooldowns
PrestigeManager  — rebirth logic, Star Shard currency
```

### Resources (data layer)
All game data lives in .tres Resource files, never hardcoded.
```
EnemyData.gd      — hp, speed, damage, credit_value, sprite
UpgradeData.gd    — id, name, description, cost, effect_type, effect_value, unlock_wave
AbilityData.gd    — id, name, cooldown, effect
WaveConfig.gd     — base_enemy_count, speed_multiplier, hp_multiplier per wave tier
SpaceportUpgrade.gd — id, name, cost_void_cores, effect_type, max_level
```
If a value might ever need balancing, it goes in a Resource. No magic numbers in scripts.

### Scene structure
```
Main.tscn
  GameManager (autoload, not in scene)
  Background/
    StarfieldLayer      — parallax star particles
  GameField/
    Ship                — player ship node
    EnemyLayer          — enemies spawn here
    ProjectileLayer     — bullets spawn here
    EffectLayer         — particles, damage numbers
  UI/
    HUD                 — wave counter, credits, HP bar, shield bar
    UpgradePanel        — in-run upgrade selection
    SpaceportPanel      — meta-upgrade screen (shown between runs)
    ShopPanel           — IAP / gem shop
    GameOverPanel
```

### Script conventions
- Every script opens with a one-line `## Purpose:` comment
- PascalCase for class names and node names
- snake_case for variables, functions, signals
- Prefix private vars/functions with underscore: `_current_wave`, `_calculate_damage()`
- Typed GDScript everywhere: `var hp: float = 100.0` not `var hp = 100`
- Signals declared at top of file, before variables
- `@onready` vars grouped together below signals
- No raw `_process()` or `_physics_process()` in managers — subscribe to TickSystem instead

### TickSystem
A global tick drives all manager updates instead of individual `_process()` calls.
Managers connect to `TickSystem.tick` signal on `_ready()` and disconnect on exit.
This makes pausing, game speed upgrades, and offline progress calculation trivial.
```gdscript
func _ready() -> void:
    TickSystem.tick.connect(_on_tick)

func _on_tick(delta: float) -> void:
    # update logic here
```

### Pooling
Enemies and projectiles are pooled — never use `queue_free()` and `instantiate()` per bullet.
EnemyManager and AutoFireSystem each maintain their own ObjectPool.
Call `pool.get()` to retrieve, `pool.release(obj)` to return.

---

## Folder structure
```
res://
  _game/
    scenes/
      main.tscn
      ui/
      enemies/
      effects/
    scripts/
      core/
        event_bus.gd
        game_manager.gd
        tick_system.gd
        save_manager.gd
        object_pool.gd
      managers/
        wave_manager.gd
        enemy_manager.gd
        auto_fire_system.gd
        shield_system.gd
        upgrade_manager.gd
        economy_manager.gd
        spaceport_system.gd
        ability_manager.gd
        prestige_manager.gd
      ui/
        hud.gd
        upgrade_panel.gd
        spaceport_panel.gd
        shop_panel.gd
        game_over_panel.gd
      utils/
        bignum.gd
        helpers.gd
    data/
      enemies/
      upgrades/
      waves/
      spaceport/
      abilities/
    assets/
      sprites/
      audio/
      fonts/
      particles/
  addons/
    godot_ai/
```

---

## Number handling — critical
Wave numbers reach into the thousands. Credit values and damage numbers scale exponentially.
All game economy values must go through `BigNum` (res://_game/scripts/utils/bignum.gd).
Never use raw floats for credits, damage totals, or production rates.
Display format: suffix notation — 1.23K, 4.56M, 7.89B, 1.23T etc.
BigNum wraps Godot's float with overflow protection and display helpers.

---

## Game loop summary
1. Run starts → ship appears, wave 1 begins
2. Enemies spawn from edges, move toward ship
3. Ship fires automatically at nearest enemy in range
4. Player spends credits on in-run upgrades (UpgradePanel)
5. Ship dies → Game Over → run stats shown
6. Player enters Spaceport → spends Void Cores on meta-upgrades
7. New run starts with meta-upgrades applied permanently
8. After enough rebirths → Prestige option unlocks → spend Star Shards on prestige tree

---

## Currencies
| Currency | Earned by | Spent on | Persists? |
|---|---|---|---|
| Credits | Killing enemies | In-run upgrades | No — resets each run |
| Void Cores | Wave milestones, boss kills | Spaceport meta-upgrades | Yes |
| Star Shards | Prestige rebirths | Prestige tree | Yes |
| Gems | IAP / rare drops | Shop (cosmetics, convenience) | Yes |

---

## What NOT to do
- Do not add `_process()` to managers — use TickSystem
- Do not reference managers directly — use EventBus
- Do not hardcode numeric values — put them in Resource files
- Do not use `float` for economy values — use BigNum
- Do not create new autoloads without checking this file first
- Do not modify the folder structure without updating this file
- Do not queue_free enemies or bullets during gameplay — release them to the pool

---

## Session startup prompt
At the start of every Claude Code session, run:
```
Read CLAUDE.md, SESSION.md, and DESIGN.md. Summarise the current project state in 3 bullet points, then ask what to work on.
```

## References
- SESSION.md — current task, what's broken, what was last completed
- DESIGN.md — full GDD: upgrade trees, wave formula, Galaxy tiers, Spaceport, economy
