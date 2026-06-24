# Vexion Siege — Game Design Document

> Read this before implementing any game logic, balancing any numbers,
> or adding any upgrade. All design decisions live here.
> When a decision changes, update this file first, then implement.

---

## Core fantasy
The player is the last defence of a spaceship being overwhelmed by endless alien waves.
The ship fires automatically. The player's job is to make decisions — what to upgrade,
when to spend, how to build toward a dominant configuration before the waves overwhelm them.
Every run ends in death. Every death makes the next run stronger.

---

## Feel targets
- Minimalist and clean — no clutter, every element earns its place on screen
- Satisfying on every interaction — upgrade purchases, kills, credits collecting
- Particles and screen feedback do the heavy lifting visually, not complex art
- Numbers that feel big but readable — suffix notation (1.23K, 4.5M, not 1230000)
- Pacing: slow and deliberate early, increasingly frantic mid-run, overwhelming late

---

## Game loop

### Single run loop
```
Run starts
  → Wave begins (enemies spawn from screen edges toward ship)
  → Ship auto-fires at nearest enemy in range
  → Enemies die → drop Credits
  → Player spends Credits on in-run Upgrades (UpgradePanel)
  → Wave clears → brief pause → next wave
  → As waves increase: more enemies, faster, higher HP
  → Ship dies → Run ends
Run ends
  → Stats screen (waves survived, enemies killed, credits earned)
  → Void Cores awarded based on wave reached
  → Player enters Spaceport
    → Spend Void Cores on permanent meta-upgrades
  → New run begins with meta-upgrades applied
```

### Prestige loop (unlocks after Galaxy 1 cleared)
```
Player reaches Prestige threshold
  → Soft reset: in-run upgrades and Spaceport progress partially reset
  → Award Star Shards
  → Prestige tree upgrades unlocked — spend Star Shards
  → New run with prestige bonuses active — progression faster, ceiling higher
```

---

## Galaxy system

Three Galaxies, each with distinct visual identity and enemy types.
Galaxies unlock sequentially. Galaxy 1 must be fully cleared to unlock Galaxy 2.
"Cleared" means surviving to the Galaxy's final wave in a single run.

| Galaxy | Name | Wave range | Visual theme | Enemy colours |
|---|---|---|---|---|
| 1 | Milky Way | Waves 1–500 | Deep blue, cyan stars | White, light grey |
| 2 | Andromeda | Waves 501–2000 | Purple, violet nebula | Purple, magenta |
| 3 | Triangulum | Waves 2001+ | Red, orange, gold | Red, orange, gold |

Each Galaxy has a background variant, a distinct starfield colour palette,
and enemy sprites recoloured to fit the theme. Same enemy types, different skins.

---

## Enemy system

### Enemy types

| Type | Role | HP | Speed | Damage to ship | Credit value | Visual |
|---|---|---|---|---|---|---|
| Drone | Basic fodder | Low | Medium | 5 | 1 | Small circle |
| Bruiser | Tanky, slow | High | Slow | 15 | 4 | Large circle |
| Swarm | Many, fast, fragile | Very low | Fast | 2 | 0.5 | Tiny dot |
| Shielder | Has a damage-absorbing shield | Medium + shield | Medium | 10 | 6 | Circle with ring |
| Bomber | Explodes on death near ship | Medium | Medium | 30 (on death) | 8 | Circle with glow |
| Boss | Rare, milestone wave only | Very high | Slow | 50 | 50+ | Distinct large shape |

All enemies move directly toward the ship's position using simple steering.
No pathfinding — direct line with slight spread on spawn angle.

### Wave scaling formula
```
base_count = 5 + floor(wave * 1.4)
hp_multiplier = 1.0 + (wave * 0.08)
speed_multiplier = 1.0 + (wave * 0.015)
credit_multiplier = 1.0 + (wave * 0.05)
```

Boss spawns on waves: 25, 50, 100, then every 100 waves after that.
Swarm waves: every 10 waves, enemy count triples but only Swarm type spawns.
Elite wave (all enemies have +50% HP and speed): every 25 waves from wave 50 onward.

---

## Ship

The ship sits at the bottom-centre of the screen (fixed position).
It does not move. All positioning logic is enemy-side.

### Ship stats (base values, before any upgrades)
| Stat | Base value | Notes |
|---|---|---|
| Max HP | 100 | Shown as HP bar at top of HUD |
| HP regen | 0 /sec | Unlocked via upgrade |
| Shield | 0 | Unlocked via Spaceport |
| Shield regen | 5 /sec | When shield not at 0 |
| Shield regen delay | 5 sec | After taking damage |
| Fire rate | 1 shot/sec | Upgradeable |
| Damage | 10 | Upgradeable |
| Range | 600 px | Upgradeable — shown as circle on screen |
| Projectile speed | 800 px/sec | Upgradeable |
| Game speed | 1.0× | Upgradeable — scales TickSystem delta |
| Crit chance | 0% | Upgradeable |
| Crit multiplier | 2.0× | Upgradeable |

---

## In-run upgrade system

### Philosophy
One weapon that evolves through modifiers — not separate weapon types.
Every upgrade should be immediately visible on screen.
No single correct build. Every stat has a tradeoff or unlock condition.
High-risk upgrades exist — power now, dangerous later.

### Upgrade presentation — credit shop (locked 2026-06-24, Session 09)
After each wave the player is offered 3 random upgrades in a **paid shop** (not a free pick).
- The shop is wave-clear gated and pauses the game; **one buy per wave clear**, then advance.
- Cards **cost Credits**: `cost = rarity_base × 1.55 ^ (that upgrade's own level)`, bases
  **Common 5 / Rare 18 / Epic 50 / Legendary 150** (calibrated so a Common is always affordable
  at the wave-1 clear, ~6 credits). Unaffordable cards grey out.
- A **10s countdown** runs; at 0s a random *affordable* offer is auto-bought (else the wave
  advances with no purchase). Credits persist within a run; reset on death.
- Spaceport "Upgrade Discount" applies a multiplier (−5%/level, floor 0.75×).
Upgrades at max level are excluded from the pool. Unimplemented effects (chain_lightning,
explosive_round, second_wind) are hidden from the pool until wired.
Rarity system: Common (white), Rare (blue), Epic (purple), Legendary (gold).
Higher rarity upgrades appear more often as wave number increases.
Full spec: `docs/superpowers/specs/2026-06-24-economy-progression-pass-design.md`.

### Upgrade categories

#### Offensive tree
| Upgrade | Effect per level | Max levels | Unlock wave | Notes |
|---|---|---|---|---|
| Fire Rate | +12% shots/sec | 20 | 1 | Visible density increase each level |
| Damage | +18% base damage | 20 | 1 | Scales all damage types |
| Crit Chance | +5% | 15 | 1 | Hard cap 75% |
| Crit Multiplier | +0.25× | 10 | 5 | Base 2×, max 4.5× |
| Projectile Count | +1 projectile | 5 | 10 | Spread pattern changes visually |
| Projectile Speed | +15% | 10 | 1 | Affects feel significantly |
| Range | +8% | 15 | 1 | Range circle grows visually |
| Bounce Shot | Bullets bounce off screen edges N times | 5 | 10 | Bounced hits deal 70% damage |
| Pierce | Bullets pass through N enemies | 5 | 8 | Pierced hits deal 80% damage |
| Chain Lightning | On hit, arcs to nearest enemy for 60% | 5 | 15 | Arc range upgradeable |
| Explosive Round | On kill, AoE explosion | 5 | 20 | AoE radius upgradeable |
| Homing | Bullets curve toward nearest enemy | 3 | 25 | Slight curve, not full lock-on |
| Overcharge | Every 5th shot deals 3× damage | 3 | 30 | Counter resets on death |

#### Defensive tree
| Upgrade | Effect per level | Max levels | Unlock wave | Notes |
|---|---|---|---|---|
| Max HP | +20 HP | 20 | 1 | |
| HP Regen | +0.5 HP/sec | 15 | 5 | |
| Damage Reduction | -3% incoming damage | 10 | 10 | Cap 30% |
| Thorns | Reflect 10% damage to attacker | 5 | 20 | |
| Emergency Shield | On HP < 20%, gain 50 temp shield | 1 | 30 | Legendary — one-time per run |
| Second Wind | On death, revive once with 25% HP | 1 | 50 | Legendary |

#### Economy tree
| Upgrade | Effect per level | Max levels | Unlock wave | Notes |
|---|---|---|---|---|
| Credit Magnet | +15% credits from kills | 20 | 1 | |
| Void Harvester | +10% Void Cores at run end | 10 | 1 | Meta-currency bonus |
| Kill Streak | Consecutive kills in 3 sec give +5% credits | 5 | 10 | Stacks up to 10× |
| Boss Bounty | +50% credits from boss kills | 5 | 25 | |
| Compound Interest | +1% credits per 10 waves survived | 10 | 15 | |

---

## Spaceport (meta-upgrade hub)

Accessed between runs. Permanent upgrades that persist forever.
Spent currency: Void Cores.
Visual: top-down view of a space station with distinct upgrade terminals.

**Pricing & unlocks (locked 2026-06-24, Session 09):** the per-level "Cost" figures in the
tables below are each upgrade's **base cost**; actual cost scales **exponentially**:
`cost = round(base × 1.6 ^ level)`. One-time Galaxy unlocks stay flat. Upgrades unlock in
**tiers gated by best wave ever reached** (whole tier at once), each tier +50 waves past the
previous → thresholds **T1=0, T2=50, T3=100, T4=150**. Each tier is presented as a cosmetic,
colour-coded **space-region band** (NOT the gameplay Galaxies above — kept separate to avoid
name/threshold collisions; Spaceport-panel theming only):
- T1 (start) — **INNER CORE** (green): Reinforced Hull, Reactor Boost, Starting Credits
- T2 (≥50) — **OUTER RIM** (blue): Shield Generator, Targeting System, Void Extractor
- T3 (≥100) — **DEEP VOID** (purple): Engine Coolant, Upgrade Discount, Core Recycler
- T4 (≥150) — **FRONTIER** (amber): Combat Log, Galaxy Scanner, Wave Forecast, Fast Forward

Locked terminals render greyed with "Reach Wave N to unlock". Best-wave gating reads the
persisted `lifetime/best_wave` stat. Full spec:
`docs/superpowers/specs/2026-06-24-economy-progression-pass-design.md`.

### Spaceport upgrade categories

#### Hull upgrades (permanent ship stat boosts)
| Upgrade | Effect per level | Max level | Cost (Void Cores) |
|---|---|---|---|
| Reinforced Hull | +25 base Max HP | 20 | 10 × level |
| Shield Generator | Unlock shield system, +25 max shield per level | 10 | 25 × level |
| Reactor Boost | +5% base fire rate | 15 | 15 × level |
| Targeting System | +3% base crit chance | 10 | 20 × level |
| Engine Coolant | -10% fire rate upgrade cost | 5 | 30 × level |

#### Economic upgrades
| Upgrade | Effect per level | Max level | Cost (Void Cores) |
|---|---|---|---|
| Void Extractor | +15% Void Cores per run | 10 | 20 × level |
| Starting Credits | Begin each run with bonus credits | 10 | 10 × level |
| Upgrade Discount | -5% cost of in-run upgrades | 5 | 25 × level |
| Core Recycler | Gain Void Cores on losing HP | 5 | 40 × level |

#### Galaxy upgrades (one-time unlocks)
| Upgrade | Effect | Cost |
|---|---|---|
| Galaxy Scanner | Reveal enemy HP bars | 50 |
| Wave Forecast | Show next wave composition | 75 |
| Combat Log | Track DPS and kill stats this run | 30 |
| Fast Forward | Unlock 2× game speed toggle | 100 |

---

## Abilities

Active abilities with cooldowns. Player taps to activate.
Unlocked via Spaceport. Max 3 equipped simultaneously.

| Ability | Effect | Cooldown | Unlock cost |
|---|---|---|---|
| Nova Burst | AoE explosion centred on ship, 500 damage | 30 sec | 50 Void Cores |
| Time Warp | Slow all enemies to 20% speed for 5 sec | 45 sec | 75 Void Cores |
| Repair Drone | Restore 30% max HP | 60 sec | 60 Void Cores |
| Overclock | 3× fire rate for 8 sec | 40 sec | 80 Void Cores |
| Black Hole | Pull all enemies to screen centre for 3 sec | 90 sec | 120 Void Cores |
| Shield Surge | Instantly max shield, no regen delay for 10 sec | 50 sec | 70 Void Cores |

---

## Economy

### Credits (in-run currency)
Earned: killing enemies (value from EnemyData.credit_value × credit multipliers)
Spent: in-run upgrades
Lost on: run end (does not persist)

### Void Cores (meta currency)
Earned: wave milestones (every 25 waves), boss kills, run completion bonus
Formula: `cores_earned = floor(wave_reached / 10) + boss_kills * 5`
Spent: Spaceport upgrades
Persists: forever

### Star Shards (prestige currency)
Earned: prestige rebirths only
Formula: `shards = floor(sqrt(total_void_cores_ever_earned / 100))`
Spent: Prestige tree
Persists: forever

### Gems (premium currency)
Earned: IAP purchases, rare drop from bosses (1–3 gems max per run, so as not to undermine IAP)
Spent: Shop (cosmetics, one-time convenience items, Gem-only upgrades)
Persists: forever

---

## IAP shop

### Gem packs (one-time purchase)
| Pack | Gems | Price (USD) |
|---|---|---|
| Small | 100 | $0.99 |
| Medium | 550 | $4.99 |
| Large | 1200 | $9.99 |
| Mega | 6500 | $49.99 |

### Spendable items (gems)
| Item | Cost | Notes |
|---|---|---|
| Continue (after death) | 30 gems | Resume run from death point with 50% HP. Once per run. |
| Upgrade Reroll | 10 gems | Reroll current upgrade choice. Unlimited per wave. |
| Void Core Boost | 50 gems | Double Void Cores earned this run |
| Starter Pack | 200 gems | +500 starting credits, +50 Void Cores. Once ever. |

### Permanent purchases (gems, one-time)
| Item | Cost | Notes |
|---|---|---|
| Auto-collect Credits | 150 gems | Credits auto-collect without tapping |
| Offline Progress | 200 gems | Earn credits while app is closed (up to 4 hrs) |
| Ship Skin: Phantom | 300 gems | Cosmetic only |
| Ship Skin: Inferno | 300 gems | Cosmetic only |
| 4th Ability Slot | 500 gems | Unlock 4th active ability slot |

### Monetisation rules
- No pay-to-win: gems cannot buy stat upgrades or bypass progression
- Continue (revive) is the only run-saving mechanic and limited to once per run
- Cosmetics are the primary gem sink
- Offline progress is convenience, not power

---

## Prestige tree

Unlocks after clearing Galaxy 1 (surviving wave 500 in one run).
Prestige resets Spaceport upgrades back 50% (rounded down) and all in-run progress.
Awards Star Shards. Prestige tree is permanent — never resets.

| Upgrade | Effect | Cost (Star Shards) |
|---|---|---|
| Ancient Reactor | +10% to all base ship stats per prestige | 1 |
| Void Mastery | +25% Void Core gain permanently | 2 |
| Shard Resonance | +5% Star Shard gain per prestige done | 3 |
| Overclock Passive | Permanent +5% fire rate (stacks each prestige) | 2 |
| Phoenix Core | Start each run with Emergency Shield active | 5 |
| Singularity | Unlock Galaxy 3 enemy types in Galaxy 1 for bonus Void Cores | 8 |

---

## HUD layout (portrait 1080×1920)

```
┌─────────────────────────┐
│  Wave: 47    [≡ Menu]   │  ← top bar
│  ████████░░  HP 73/100  │  ← HP bar
│  ▓▓▓▓▓▓▓▓▓▓ SH 50/50   │  ← shield bar (hidden if no shield)
│                         │
│                         │
│      [game field]       │
│    enemies + bullets    │
│      + particles        │
│                         │
│         [ship]          │
│                         │
│  Credits: 4.2K          │
│  ┌─────────────────┐    │
│  │  Upgrade Panel  │    │  ← slides up after wave clear
│  └─────────────────┘    │
│  [A1] [A2] [A3]         │  ← ability buttons (if unlocked)
└─────────────────────────┘
```

---

## Visual and feel guidelines for implementation

### Particles
- Every enemy death emits a burst of 8–12 particles in the enemy's colour
- Credits drop as small glowing dots that float toward a credit counter
- Bullet impacts emit a small white flash (2–3 particles)
- Boss death: large multi-ring explosion, screen shake, freeze frame 0.1 sec

### Screen feedback
- Ship takes damage: red vignette flash (0.15 sec), screen shake (small)
- Shield breaks: blue flash, distinct audio cue
- Level up / upgrade selected: brief white flash on whole screen
- Wave clear: text announcement fades in and out over 1.5 sec

### Colours (base palette — Galaxy 1)
- Background: #050A1A (near black, deep space blue)
- Stars: #FFFFFF at varying opacity 0.2–0.9
- Ship: #4FC3F7 (light blue)
- Bullets: #FFFFFF with #4FC3F7 glow trail
- Basic enemy: #B0BEC5 (light grey)
- Bruiser enemy: #78909C (darker grey)
- UI accent: #4FC3F7
- Credits: #FFD54F (amber)
- HP bar: #EF5350 (red)
- Shield bar: #42A5F5 (blue)
- Void Cores: #AB47BC (purple)

---

## Open design questions (do not implement until resolved)
- Tournament system: time-limited leaderboard events — design TBD
- Faction/guild system: social features — not in scope for v1
- Daily missions: potential engagement mechanic — TBD post-launch
- Enemy pathing variants: currently all direct-line — consider zigzag variant post-v1
