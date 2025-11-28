extends Node

## Sistema de Audio para BattleTech
## Maneja música de fondo y efectos de sonido

# Configuración de volumen (0.0 a 1.0)
var music_volume: float = 0.7:
	set(v):
		music_volume = clamp(v, 0.0, 1.0)
		if music_player:
			music_player.volume_db = _safe_linear_to_db(music_volume)
		_save_settings()

var sfx_volume: float = 0.8:
	set(v):
		sfx_volume = clamp(v, 0.0, 1.0)
		_save_settings()

var master_volume: float = 1.0:
	set(v):
		master_volume = clamp(v, 0.0, 1.0)
		AudioServer.set_bus_volume_db(0, _safe_linear_to_db(master_volume))
		_save_settings()

## Convierte linear a dB de forma segura (evita NaN/inf)
func _safe_linear_to_db(linear_val: float) -> float:
	if linear_val <= 0.0:
		return -80.0  # Silencio efectivo
	return linear_to_db(linear_val)

# Reproductor de música
var music_player: AudioStreamPlayer
var current_music: String = ""

# Pool de reproductores de SFX (para múltiples sonidos simultáneos)
var sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE = 8

# Cache de sonidos cargados
var sound_cache: Dictionary = {}

# Rutas de audio
const AUDIO_PATH = "res://assets/audio/"
const MUSIC_PATH = AUDIO_PATH + "music/"
const SFX_PATH = AUDIO_PATH + "sfx/"

# Constantes de Música
const MUSIC_MENU = 0
const MUSIC_BATTLE = 1
const MUSIC_VICTORY = 2
const MUSIC_DEFEAT = 3

# Constantes de SFX
const SFX_UI_CLICK = 0
const SFX_UI_HOVER = 1
const SFX_UI_CONFIRM = 2
const SFX_UI_CANCEL = 3
const SFX_UI_ERROR = 4
const SFX_WEAPON_FIRE = 10
const SFX_LASER_FIRE = 11
const SFX_MISSILE_LAUNCH = 12
const SFX_AUTOCANNON_FIRE = 13
const SFX_PPC_FIRE = 14
const SFX_HIT_ARMOR = 20
const SFX_HIT_STRUCTURE = 21
const SFX_EXPLOSION_SMALL = 22
const SFX_EXPLOSION_LARGE = 23
const SFX_MECH_DESTROYED = 24
const SFX_MECH_STEP = 30
const SFX_MECH_JUMP = 31
const SFX_MECH_LAND = 32
const SFX_HEAT_WARNING = 40
const SFX_SHUTDOWN = 41
const SFX_TURN_START = 42
const SFX_PHASE_CHANGE = 43

# Mapeo de SFX a archivos
var sfx_files: Dictionary = {
	SFX_UI_CLICK: "ui_click.ogg",
	SFX_UI_HOVER: "ui_hover.ogg",
	SFX_UI_CONFIRM: "ui_confirm.ogg",
	SFX_UI_CANCEL: "ui_cancel.ogg",
	SFX_UI_ERROR: "ui_error.ogg",
	
	SFX_WEAPON_FIRE: "weapon_fire.ogg",
	SFX_LASER_FIRE: "laser.ogg",
	SFX_MISSILE_LAUNCH: "missile_launch.ogg",
	SFX_AUTOCANNON_FIRE: "autocannon.ogg",
	SFX_PPC_FIRE: "ppc.ogg",
	
	SFX_HIT_ARMOR: "hit_armor.ogg",
	SFX_HIT_STRUCTURE: "hit_structure.ogg",
	SFX_EXPLOSION_SMALL: "explosion_small.ogg",
	SFX_EXPLOSION_LARGE: "explosion_large.ogg",
	SFX_MECH_DESTROYED: "mech_destroyed.ogg",
	
	SFX_MECH_STEP: "mech_step.ogg",
	SFX_MECH_JUMP: "mech_jump.ogg",
	SFX_MECH_LAND: "mech_land.ogg",
	
	SFX_HEAT_WARNING: "heat_warning.ogg",
	SFX_SHUTDOWN: "shutdown.ogg",
	SFX_TURN_START: "turn_start.ogg",
	SFX_PHASE_CHANGE: "phase_change.ogg"
}

# Mapeo de música a archivos
var music_files: Dictionary = {
	MUSIC_MENU: "menu_theme.mp3",
	MUSIC_BATTLE: "battle_theme.mp3",
	MUSIC_VICTORY: "victory_theme.mp3",
	MUSIC_DEFEAT: "defeat_theme.mp3"
}

func _ready():
	_load_settings()
	_setup_music_player()
	_setup_sfx_pool()
	print("[AudioManager] Initialized with music_vol=%.1f, sfx_vol=%.1f" % [music_volume, sfx_volume])

func _setup_music_player():
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"  # Usa bus de música si existe, sino Master
	music_player.volume_db = _safe_linear_to_db(music_volume)
	add_child(music_player)
	
	# Crear bus de música si no existe
	if AudioServer.get_bus_index("Music") == -1:
		var bus_idx = AudioServer.bus_count
		AudioServer.add_bus(bus_idx)
		AudioServer.set_bus_name(bus_idx, "Music")

func _setup_sfx_pool():
	# Crear bus de SFX si no existe
	if AudioServer.get_bus_index("SFX") == -1:
		var bus_idx = AudioServer.bus_count
		AudioServer.add_bus(bus_idx)
		AudioServer.set_bus_name(bus_idx, "SFX")
	
	# Crear pool de reproductores
	for i in range(SFX_POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)

## Reproducir música
func play_music(music_id: int, fade_in: float = 1.0):
	if not music_files.has(music_id):
		push_warning("[AudioManager] Music ID not found: %d" % music_id)
		return
	
	var file_name = music_files[music_id]
	var path = MUSIC_PATH + file_name
	
	# Si ya está sonando esta música, no hacer nada
	if current_music == path and music_player.playing:
		return
	
	var stream = _load_audio(path)
	if stream:
		# Configurar loop para la música
		if stream is AudioStreamMP3:
			stream.loop = true
		elif stream is AudioStreamOggVorbis:
			stream.loop = true
		
		current_music = path
		music_player.stream = stream
		music_player.volume_db = -80.0 if fade_in > 0 else _safe_linear_to_db(music_volume)
		music_player.play()
		
		if fade_in > 0:
			_fade_music_in(fade_in)
		
		print("[AudioManager] Playing music: %s" % file_name)

func play_music_file(file_path: String, fade_in: float = 1.0):
	"""Reproduce un archivo de música directamente por ruta"""
	var stream = _load_audio(file_path)
	if stream:
		current_music = file_path
		music_player.stream = stream
		music_player.volume_db = -80.0 if fade_in > 0 else _safe_linear_to_db(music_volume)
		music_player.play()
		
		if fade_in > 0:
			_fade_music_in(fade_in)

func stop_music(fade_out: float = 1.0):
	if fade_out > 0 and music_player.playing:
		_fade_music_out(fade_out)
	else:
		music_player.stop()
		current_music = ""

func _fade_music_in(duration: float):
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", _safe_linear_to_db(music_volume), duration)

func _fade_music_out(duration: float):
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, duration)
	tween.tween_callback(func(): 
		music_player.stop()
		current_music = ""
	)

## Reproducir efecto de sonido
func play_sfx(sfx_id: int, volume_scale: float = 1.0, pitch_variation: float = 0.0):
	if not sfx_files.has(sfx_id):
		push_warning("[AudioManager] SFX ID not found: %d" % sfx_id)
		return
	
	var file_name = sfx_files[sfx_id]
	var path = SFX_PATH + file_name
	play_sfx_file(path, volume_scale, pitch_variation)

func play_sfx_file(file_path: String, volume_scale: float = 1.0, pitch_variation: float = 0.0):
	"""Reproduce un archivo de sonido directamente por ruta"""
	var stream = _load_audio(file_path)
	if not stream:
		return
	
	# Encontrar un reproductor disponible
	var player = _get_available_sfx_player()
	if player:
		player.stream = stream
		player.volume_db = _safe_linear_to_db(sfx_volume * volume_scale)
		
		# Variación de pitch para más variedad
		if pitch_variation > 0:
			player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
		else:
			player.pitch_scale = 1.0
		
		player.play()

func _get_available_sfx_player() -> AudioStreamPlayer:
	# Buscar un reproductor que no esté sonando
	for player in sfx_players:
		if not player.playing:
			return player
	
	# Si todos están ocupados, usar el primero (interrumpir)
	return sfx_players[0]

## Cargar audio con cache
func _load_audio(path: String) -> AudioStream:
	# Verificar cache
	if sound_cache.has(path):
		return sound_cache[path]
	
	# Intentar cargar
	if ResourceLoader.exists(path):
		var stream = load(path)
		if stream:
			sound_cache[path] = stream
			return stream
	
	# Archivo no encontrado - no mostrar error, puede que no exista aún
	# push_warning("[AudioManager] Audio file not found: %s" % path)
	return null

## Precargar sonidos comunes
func preload_common_sounds():
	print("[AudioManager] Preloading common sounds...")
	
	# Precargar SFX de UI
	for sfx_id in [SFX_UI_CLICK, SFX_UI_HOVER, SFX_UI_CONFIRM, SFX_UI_CANCEL]:
		if sfx_files.has(sfx_id):
			_load_audio(SFX_PATH + sfx_files[sfx_id])
	
	# Precargar sonidos de combate
	for sfx_id in [SFX_WEAPON_FIRE, SFX_HIT_ARMOR, SFX_EXPLOSION_SMALL]:
		if sfx_files.has(sfx_id):
			_load_audio(SFX_PATH + sfx_files[sfx_id])

## Guardar/cargar configuración
func _save_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "master_volume", master_volume)
	config.save("user://audio_settings.cfg")

func _load_settings():
	var config = ConfigFile.new()
	if config.load("user://audio_settings.cfg") == OK:
		music_volume = config.get_value("audio", "music_volume", 0.7)
		sfx_volume = config.get_value("audio", "sfx_volume", 0.8)
		master_volume = config.get_value("audio", "master_volume", 1.0)
