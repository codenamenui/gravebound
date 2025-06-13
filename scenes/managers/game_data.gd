extends Node

signal wave_completed(wave_number: int)
signal player_died()
#signal perk_selected(perk_data: PerkData)

var current_wave: int = 0
#var player_stats: PlayerStats
#var selected_perks: Array[PerkData] = []
var total_score: int = 0

enum GameState {
	MAIN_MENU,
	PLAYING,
	WAVE_COMPLETE,
	PERK_SELECTION,
	GAME_OVER,
	SETTINGS,
	PAUSED
}

var current_state: GameState = GameState.MAIN_MENU
var from_game: bool = false
var from_pause: bool = false
