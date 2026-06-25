## Purpose: Central signal hub — all inter-system communication passes through here.
extends Node

# Game state
signal game_started
signal game_paused
signal game_resumed
signal game_over(stats: Dictionary)
signal run_ended

# Waves
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal all_enemies_cleared
signal ready_for_next_wave  # emitted by UpgradePanel after player picks an upgrade

# Enemies
signal enemy_spawned(enemy_data: Dictionary)
signal enemy_killed(enemy_data: Dictionary)
signal enemy_damaged(position: Vector2, amount: float, is_crit: bool)
signal enemy_reached_ship(damage: float)

# Wave threat (Wave Info panel): total HP set at wave start, then the live aggregate.
signal wave_threat_total(total_hp: float, counts: Dictionary)
signal wave_threat_changed(current_hp: float, max_hp: float, counts: Dictionary)

# Effects / feedback
signal credit_awarded(position: Vector2, amount: float)

# Ship / shield
signal ship_hull_damaged(amount: float)  # damage that passed through shield
signal ship_damaged(amount: float, current_hp: float)
signal ship_died
signal shield_initialized(max_shield: float)
signal shield_damaged(amount: float, current_shield: float)
signal shield_broken
signal shield_recharged

# Economy
signal credits_changed(new_total: BigNum)
signal void_cores_changed(new_total: int)
signal gems_changed(new_total: int)
signal void_cores_spend_requested(amount: int, context: String)
signal void_cores_spend_result(context: String, success: bool)
signal credits_spend_requested(amount: BigNum, context: String)
signal credits_spend_result(context: String, success: bool)
signal run_summary(summary: Dictionary)  # emitted at run end: earned cores/credits + best wave

# Upgrades
signal upgrade_purchased(upgrade_id: String)
signal upgrade_applied(upgrade_id: String, new_value: float)

# Spaceport
signal spaceport_opened
signal spaceport_closed
signal meta_upgrade_purchased(upgrade_id: String)
signal spaceport_bonus_applied(key: String, value: float)
signal shield_activate_requested(max_shield: float)

# Prestige
signal prestige_triggered

# UI / HUD controls
signal stats_toggle_requested      # STATS button in bottom HUD
signal upgrades_toggle_requested   # UPGRADES button in bottom HUD
signal menu_toggled                # hamburger menu button
