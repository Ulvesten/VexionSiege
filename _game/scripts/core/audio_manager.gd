## Purpose: Sound effects and music. Registry-driven and missing-file-safe — every
## play call no-ops cleanly until the matching asset is dropped in and imported, so the
## game runs silent-but-fine before any audio exists.
##
## Drop assets here (names must match the registries below):
##   res://_game/assets/audio/sfx/<name>.wav    (short one-shots)
##   res://_game/assets/audio/music/<name>.ogg  (looping tracks — set Loop on import)
extends Node

# ── Asset registries ────────────────────────────────────────────────────────
const _SFX_DIR: String   = "res://_game/assets/audio/sfx/"
const _MUSIC_DIR: String = "res://_game/assets/audio/music/"

const SFX: Dictionary = {
	"enemy_explode":   "enemy_explode.wav",
	"boss_explode":    "boss_explode.wav",
	"ship_hit":        "ship_hit.wav",
	"shield_hit":      "shield_hit.wav",
	"shield_break":    "shield_break.wav",
	"upgrade_buy":     "upgrade_buy.wav",
	"purchase_ok":     "purchase_ok.wav",
	"purchase_fail":   "purchase_fail.wav",
	"wave_start":      "wave_start.wav",
	"wave_complete":   "wave_complete.wav",
	"game_over":       "game_over.wav",
	"prestige":        "prestige.wav",
	"ui_tap":          "ui_tap.wav",
}

const MUSIC: Dictionary = {
	"combat":    "combat.ogg",
	"spaceport": "spaceport.ogg",
}

const _SFX_VOICES: int = 8  # how many SFX can overlap at once

# ── Volume (0..1 linear, persisted in the "settings" save section) ───────────
var _master: float = 1.0
var _sfx_vol: float = 1.0
var _music_vol: float = 0.7
var _muted: bool = false

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _music_player: AudioStreamPlayer
var _current_music: String = ""

# Loaded-stream cache. Missing assets cache as null so we probe disk only once.
var _stream_cache: Dictionary = {}

func _ready() -> void:
	_load_settings()

	for i: int in _SFX_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)

	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	# Restart the loop if a non-looping stream slips in.
	_music_player.finished.connect(_on_music_finished)

	_apply_volumes()
	_wire_events()

# ── Public API ───────────────────────────────────────────────────────────────

func play_sfx(sfx_name: String) -> void:
	if _muted or _sfx_vol <= 0.0:
		return
	var stream := _get_stream(SFX, _SFX_DIR, sfx_name)
	if stream == null:
		return
	var p := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _SFX_VOICES
	p.stream = stream
	p.play()

func play_music(track_name: String) -> void:
	if track_name == _current_music and _music_player.playing:
		return
	var stream := _get_stream(MUSIC, _MUSIC_DIR, track_name)
	_current_music = track_name
	if stream == null:
		_music_player.stop()
		return
	_music_player.stream = stream
	if not (_muted or _music_vol <= 0.0):
		_music_player.play()

func stop_music() -> void:
	_current_music = ""
	_music_player.stop()

# ── Settings ──────────────────────────────────────────────────────────────────

func set_master_volume(v: float) -> void:
	_master = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()

func set_sfx_volume(v: float) -> void:
	_sfx_vol = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()

func set_music_volume(v: float) -> void:
	_music_vol = clampf(v, 0.0, 1.0)
	_apply_volumes()
	if _music_vol <= 0.0:
		_music_player.stop()
	elif _current_music != "" and not _music_player.playing:
		play_music(_current_music)
	_save_settings()

func set_muted(m: bool) -> void:
	_muted = m
	if _muted:
		_music_player.stop()
	elif _current_music != "":
		play_music(_current_music)
	_save_settings()

func is_muted() -> bool:
	return _muted

# ── Internals ─────────────────────────────────────────────────────────────────

func _apply_volumes() -> void:
	# Master folds into each player's gain (keeps everything on the default bus,
	# so no custom AudioBusLayout is required).
	var sfx_db := linear_to_db(maxf(_sfx_vol * _master, 0.0001))
	for p: AudioStreamPlayer in _sfx_players:
		p.volume_db = sfx_db
	_music_player.volume_db = linear_to_db(maxf(_music_vol * _master, 0.0001))

func _get_stream(registry: Dictionary, dir: String, key: String) -> AudioStream:
	if _stream_cache.has(key):
		return _stream_cache[key]
	var stream: AudioStream = null
	if registry.has(key):
		var path: String = dir + registry[key]
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
	_stream_cache[key] = stream
	return stream

func _on_music_finished() -> void:
	# Loop the current track if its import wasn't set to loop.
	if _current_music != "" and not (_muted or _music_vol <= 0.0):
		_music_player.play()

func _load_settings() -> void:
	_master   = float(SaveManager.get_value("settings", "vol_master", 1.0))
	_sfx_vol  = float(SaveManager.get_value("settings", "vol_sfx", 1.0))
	_music_vol = float(SaveManager.get_value("settings", "vol_music", 0.7))
	_muted    = bool(SaveManager.get_value("settings", "muted", false))

func _save_settings() -> void:
	SaveManager.set_value("settings", "vol_master", _master)
	SaveManager.set_value("settings", "vol_sfx", _sfx_vol)
	SaveManager.set_value("settings", "vol_music", _music_vol)
	SaveManager.set_value("settings", "muted", _muted)
	SaveManager.save()

# ── EventBus auto-wiring ─────────────────────────────────────────────────────

func _wire_events() -> void:
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.ship_damaged.connect(_on_ship_damaged)
	EventBus.shield_damaged.connect(_on_shield_damaged)
	EventBus.shield_broken.connect(func(): play_sfx("shield_break"))
	EventBus.upgrade_purchased.connect(func(_id): play_sfx("upgrade_buy"))
	EventBus.void_cores_spend_result.connect(_on_spend_result)
	EventBus.credits_spend_result.connect(_on_spend_result)
	EventBus.wave_started.connect(func(_n): play_sfx("wave_start"))
	EventBus.wave_completed.connect(func(_n): play_sfx("wave_complete"))
	EventBus.prestige_triggered.connect(func(): play_sfx("prestige"))

	# Music transitions follow run lifecycle.
	EventBus.game_started.connect(func(): play_music("combat"))
	EventBus.game_over.connect(_on_game_over)
	EventBus.spaceport_opened.connect(func(): play_music("spaceport"))
	EventBus.spaceport_closed.connect(func(): play_music("combat"))

func _on_enemy_killed(data: Dictionary) -> void:
	play_sfx("boss_explode" if data.get("type", "drone") == "boss" else "enemy_explode")

func _on_ship_damaged(amount: float, _current_hp: float) -> void:
	if amount > 0.0:
		play_sfx("ship_hit")

func _on_shield_damaged(amount: float, _current_shield: float) -> void:
	if amount > 0.0:
		play_sfx("shield_hit")

func _on_spend_result(_context: String, success: bool) -> void:
	play_sfx("purchase_ok" if success else "purchase_fail")

func _on_game_over(_stats: Dictionary) -> void:
	play_sfx("game_over")
	stop_music()
