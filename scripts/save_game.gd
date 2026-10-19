class_name SaveGame
## Sauvegardes de parties dans user://saves/partie_N.save (format binaire de Godot, sans objets).
## Chaque fichier contient d'abord un petit résumé (pour le menu « Charger »), puis la partie complète.
## Sous Windows : %APPDATA%\Godot\app_userdata\Gardien forestier\saves\

const DIR := "user://saves"
const LEGACY_PATH := "user://sauvegarde.save"   # ancienne sauvegarde unique (avant la 0.8)
const VERSION := 1

static var load_requested := false   # le menu demande à main.gd de charger la partie "slot"
static var slot := 0                 # partie en cours (0 : pas encore choisie)

static func path(n: int) -> String:
	return "%s/partie_%d.save" % [DIR, n]

## Numéros des parties existantes, de la plus récemment sauvegardée à la plus ancienne.
static func slots() -> Array:
	_migrate()
	var found: Array = []
	var d := DirAccess.open(DIR)
	if d == null:
		return found
	for f in d.get_files():
		if f.begins_with("partie_") and f.ends_with(".save"):
			var n := f.trim_prefix("partie_").trim_suffix(".save").to_int()
			if n > 0:
				found.append(n)
	var saved := {}
	for n in found:
		saved[n] = float(read_meta(n).get("saved", 0.0))
	found.sort_custom(func(a, b): return saved[a] > saved[b])
	return found

static func exists() -> bool:
	return not slots().is_empty()

static func latest() -> int:
	var s := slots()
	return s[0] if not s.is_empty() else 0

static func next_free() -> int:
	var n := 1
	for s in slots():
		n = maxi(n, int(s) + 1)
	return n

## Résumé d'une partie (lecture rapide : la partie complète n'est pas décodée).
static func read_meta(n: int) -> Dictionary:
	var f := FileAccess.open(path(n), FileAccess.READ)
	if f == null:
		return {}
	var v = f.get_var(false)
	if v is Dictionary and v.get("is_meta", false):
		return v
	# Sauvegarde sans résumé : on le reconstruit depuis la partie
	return make_meta(v) if v is Dictionary else {}

static func read(n: int = slot) -> Dictionary:
	var f := FileAccess.open(path(n), FileAccess.READ)
	if f == null:
		return {}
	var v = f.get_var(false)
	if v is Dictionary and v.get("is_meta", false):
		v = f.get_var(false)
	if v is Dictionary and int(v.get("version", 0)) == VERSION:
		return v
	return {}

static func write(d: Dictionary, n: int = slot) -> bool:
	if n <= 0:
		n = next_free()
		slot = n
	d["version"] = VERSION
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var final_path := ProjectSettings.globalize_path(path(n))
	var tmp_path := final_path + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(make_meta(d), false)
	f.store_var(d, false)
	f.close()
	# On écrit d'abord un fichier temporaire : un plantage pendant l'écriture n'abîme pas l'ancienne sauvegarde.
	if FileAccess.file_exists(final_path):
		DirAccess.remove_absolute(final_path)
	return DirAccess.rename_absolute(tmp_path, final_path) == OK

static func delete(n: int) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path(n)))
	if slot == n:
		slot = 0

static func make_meta(d: Dictionary) -> Dictionary:
	var saved := float(d.get("saved_at", 0.0))
	if saved <= 0.0:
		var t: Dictionary = d.get("time", {})
		if not t.is_empty():
			# Anciennes sauvegardes : l'heure était enregistrée en heure locale
			saved = Time.get_unix_time_from_datetime_dict(t) - _bias()
	var furn: Dictionary = d.get("furniture", {})
	var placed: Dictionary = d.get("placed", {})
	return {
		"is_meta": true,
		"started": float(d.get("started_at", 0.0)),
		"saved": saved,
		"play_time": float(d.get("play_time", 0.0)),
		"collected": int(d.get("collected", 0)),
		"sorted": int(d.get("sorted", 0)),
		"restored": float(d.get("restored", -1.0)),
		"chalet": placed.has("chalet"),
		"furniture": furn.size(),
	}

# ---------- Textes pour les menus ----------
static func _bias() -> float:
	return float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0

## "18/10/2026 à 14h32" (heure locale)
static func date_text(unix: float) -> String:
	if unix <= 0.0:
		return "date inconnue"
	var t := Time.get_datetime_dict_from_unix_time(int(unix + _bias()))
	return "%02d/%02d/%d à %02dh%02d" % [t["day"], t["month"], t["year"], t["hour"], t["minute"]]

## "2 h 05 min", "12 min", "moins d'une minute"
static func duration_text(sec: float) -> String:
	var m := int(sec / 60.0)
	if m < 1:
		return "moins d'une minute"
	if m < 60:
		return "%d min" % m
	return "%d h %02d min" % [m / 60, m % 60]

## Texte court pour le menu principal : "Partie 2 · sauvegardée le 18/10/2026 à 14h32 · 523 objets ramassés".
static func summary(n: int = latest()) -> String:
	var m := read_meta(n)
	if m.is_empty():
		return ""
	return "Partie %d · sauvegardée le %s · %d objets ramassés" % [n, date_text(m["saved"]), int(m["collected"])]

# Ancienne sauvegarde unique → partie 1
static func _migrate() -> void:
	if not FileAccess.file_exists(LEGACY_PATH):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var dest := ProjectSettings.globalize_path(path(1))
	var n := 1
	while FileAccess.file_exists(dest):
		n += 1
		dest = ProjectSettings.globalize_path(path(n))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(LEGACY_PATH), dest)
