# Audio assets

`AudioManager` (autoload) loads these by name. Until a file exists the matching
sound simply no-ops — the game runs silent but error-free. Filenames must match
exactly (they come from the registries in `audio_manager.gd`).

## SFX → `sfx/` (short one-shots, `.wav`)
| File | Plays when |
|---|---|
| `enemy_explode.wav` | a normal enemy dies |
| `boss_explode.wav`  | a boss dies |
| `ship_hit.wav`      | the hull takes damage |
| `shield_hit.wav`    | the shield takes damage |
| `shield_break.wav`  | the shield breaks |
| `upgrade_buy.wav`   | an in-run upgrade is purchased |
| `purchase_ok.wav`   | a Void Core purchase succeeds |
| `purchase_fail.wav` | a Void Core purchase fails (too poor) |
| `wave_start.wav`    | a wave begins |
| `wave_complete.wav` | a wave is cleared |
| `game_over.wav`     | the run ends |
| `prestige.wav`      | a prestige/rebirth fires |
| `ui_tap.wav`        | (reserved) generic button tap |

## Music → `music/` (looping, `.ogg`, enable **Loop** in the import dock)
| File | Plays during |
|---|---|
| `combat.ogg`    | an active run |
| `spaceport.ogg` | the Spaceport meta screen |

Volumes (master / sfx / music) and mute persist in the save's `settings` section
via `AudioManager.set_*_volume()` — wire these to a settings panel later.
