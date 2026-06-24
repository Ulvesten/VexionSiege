## Purpose: Design-token colours from VexionSiege_Mockup.html :root variables. Single source of truth.
class_name Palette
extends Object

# ── Surface hierarchy ──────────────────────────────────────────────────────
const BG     := Color("#060810")   # --bg   main scene background
const S1     := Color("#0a0d16")   # --s1   cards, panels
const S2     := Color("#0f1220")   # --s2   icon wells, inputs
const S3     := Color("#141828")   # --s3   deepest surface

# ── Borders ────────────────────────────────────────────────────────────────
const BORDER  := Color(1.0, 1.0, 1.0, 0.039)  # #ffffff0a  hairline divider
const BORDER2 := Color(1.0, 1.0, 1.0, 0.078)  # #ffffff14  card border
const BORDER3 := Color(1.0, 1.0, 1.0, 0.133)  # #ffffff22  interactive border

# ── Text ───────────────────────────────────────────────────────────────────
const TEXT    := Color("#d8e0f5")  # primary text
const MUTED   := Color("#5a6280")  # secondary / label text
const DIM     := Color("#2e3350")  # empty slots, placeholder

# ── Accent ─────────────────────────────────────────────────────────────────
const BLUE      := Color("#4488ff")  # --blue   primary accent, ship, active
const BLUE2     := Color("#1144aa")  # --blue2  dark blue
const BLUE_GLOW := Color(0.267, 0.533, 1.0, 0.12)  # button bg, highlights
const GREEN     := Color("#34d47a")  # --green
const AMBER     := Color("#f5a020")  # --amber  credits, cost, highlights
const CORAL     := Color("#ff5566")  # --coral  danger, game-over
const PURPLE    := Color("#9966ff")  # --purple void cores, epic, spaceport
const TEAL      := Color("#22ccbb")  # --teal   gems

# ── Progress bars ──────────────────────────────────────────────────────────
# Mockup uses linear-gradient; ProgressBar fill is solid — use the bright end.
const HP_FILL   := Color("#ff4455")  # bright end of #cc2233 → #ff4455
const HP_DARK   := Color("#cc2233")  # dark end (for future gradient shader)
const SH_FILL   := Color("#4488ff")  # bright end of #1155cc → #4488ff
const SH_DARK   := Color("#1155cc")  # dark end
const BAR_BG    := Color(1.0, 1.0, 1.0, 0.031)  # #ffffff08

# ── Enemy types (DESIGN §349 base palette — Galaxy 1) ───────────────────────
const E_DRONE    := Color("#b0bec5")  # light grey — basic fodder
const E_BRUISER  := Color("#78909c")  # darker grey — tanky
const E_SWARM    := Color("#cfd8dc")  # pale dot — fast/fragile
const E_SHIELDER := Color("#4fc3f7")  # shield blue — has a ring
const E_BOMBER   := Color("#ff8a50")  # orange glow — explodes
const E_BOSS     := Color("#ff5566")  # coral — milestone threat

static func enemy_color(type: String) -> Color:
	match type:
		"bruiser":  return E_BRUISER
		"swarm":    return E_SWARM
		"shielder": return E_SHIELDER
		"bomber":   return E_BOMBER
		"boss":     return E_BOSS
		_:          return E_DRONE

# Relative visual scale per enemy type (drone = 1.0).
static func enemy_scale(type: String) -> float:
	match type:
		"bruiser":  return 1.8
		"swarm":    return 0.5
		"shielder": return 1.1
		"bomber":   return 1.2
		"boss":     return 3.0
		_:          return 1.0

# ── Rarity ─────────────────────────────────────────────────────────────────
const R_COMMON    := Color("#8899aa")
const R_RARE      := Color("#4488ff")  # = BLUE
const R_EPIC      := Color("#9966ff")  # = PURPLE
const R_LEGENDARY := Color("#f5a020")  # = AMBER

# ── Rarity card tints (border / bg) ────────────────────────────────────────
static func rarity_border(rarity: int) -> Color:
	match rarity:
		1: return Color(BLUE.r,   BLUE.g,   BLUE.b,   0.35)
		2: return Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.35)
		3: return Color(AMBER.r,  AMBER.g,  AMBER.b,  0.40)
		_: return BORDER2

static func rarity_bg(rarity: int) -> Color:
	match rarity:
		1: return Color(BLUE.r,   BLUE.g,   BLUE.b,   0.05)
		2: return Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.05)
		3: return Color(AMBER.r,  AMBER.g,  AMBER.b,  0.05)
		_: return S1

static func rarity_dot(rarity: int) -> Color:
	match rarity:
		1: return R_RARE
		2: return R_EPIC
		3: return R_LEGENDARY
		_: return R_COMMON
