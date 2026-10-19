extends Node
## Musique (autoload "Music") : un morceau lo-fi en boucle dans le menu, une playlist calme
## pendant la partie, avec des fondus enchaînés. Toutes les musiques sont sous licence CC0
## (voir assets/music/CREDITS.txt). Le volume se règle dans Options > Audio > Musique.

const MENU_TRACK := "res://assets/music/menu_chill_lofi.mp3"
const GAME_TRACKS := [
	"res://assets/music/jeu_boredom.ogg",
	"res://assets/music/jeu_love.ogg",
	"res://assets/music/jeu_lost_in_your_eyes.ogg",
	"res://assets/music/jeu_you_loved_me_once.ogg",
	"res://assets/music/jeu_night_driving.ogg",
]
const FADE := 2.5
const BASE_DB := -4.0
const GAP := 4.0      # silence entre deux morceaux de la playlist

var _players: Array[AudioStreamPlayer] = []
var _cur := 0
var _what := ""        # "menu" | "game" | ""
var _playlist: Array = []
var _idx := -1
var _gap_timer: Timer
var _tweens: Array = [null, null]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # la musique continue pendant la pause
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Musique"
		p.volume_db = -60.0
		p.finished.connect(_on_finished.bind(p))
		add_child(p)
		_players.append(p)
	_gap_timer = Timer.new()
	_gap_timer.one_shot = true
	_gap_timer.timeout.connect(_next_game_track)
	add_child(_gap_timer)

func play_menu() -> void:
	if _what == "menu":
		return
	_what = "menu"
	_gap_timer.stop()
	var s := load(MENU_TRACK) as AudioStream
	_set_loop(s, true)
	_crossfade(s)

func play_game() -> void:
	if _what == "game":
		return
	_what = "game"
	_playlist = GAME_TRACKS.duplicate()
	_playlist.shuffle()
	_idx = -1
	_next_game_track()

func stop() -> void:
	_what = ""
	_gap_timer.stop()
	_crossfade(null)

func _next_game_track() -> void:
	if _what != "game":
		return
	_idx = (_idx + 1) % _playlist.size()
	if _idx == 0 and _playlist.size() > 1:
		# Nouveau tour : on remélange sans rejouer tout de suite le dernier morceau
		var last = _playlist[-1]
		_playlist.shuffle()
		if _playlist[0] == last:
			_playlist.reverse()
	var s := load(_playlist[_idx]) as AudioStream
	_set_loop(s, false)
	_crossfade(s)

func _on_finished(p: AudioStreamPlayer) -> void:
	if p == _players[_cur] and _what == "game":
		_gap_timer.start(GAP)

## Le morceau en cours s'éteint doucement pendant que le suivant monte.
func _crossfade(s: AudioStream) -> void:
	var old := _players[_cur]
	if old.playing:
		_fade(_cur, -60.0, true)
	if s == null:
		return
	_cur = 1 - _cur
	var p := _players[_cur]
	p.stream = s
	p.volume_db = -40.0
	p.play()
	_fade(_cur, BASE_DB, false)

func _fade(i: int, to_db: float, stop_after: bool) -> void:
	if _tweens[i] != null:
		(_tweens[i] as Tween).kill()
	var tw := create_tween()
	tw.tween_property(_players[i], "volume_db", to_db, FADE)
	if stop_after:
		tw.tween_callback(_players[i].stop)
	_tweens[i] = tw

static func _set_loop(s: AudioStream, on: bool) -> void:
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = on
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = on
