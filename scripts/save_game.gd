class_name SaveGame
## Sauvegarde de la partie dans user://sauvegarde.save (format binaire de Godot, sans objets).
## Sous Windows : %APPDATA%\Godot\app_userdata\Gardien forestier\

const PATH := "user://sauvegarde.save"
const VERSION := 1

static var load_requested := false   # le menu demande à main.gd de charger la sauvegarde

static func exists() -> bool:
	return FileAccess.file_exists(PATH)

static func read() -> Dictionary:
	if not exists():
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var v = f.get_var(false)
	if v is Dictionary and int(v.get("version", 0)) == VERSION:
		return v
	return {}

static func write(d: Dictionary) -> bool:
	d["version"] = VERSION
	var final_path := ProjectSettings.globalize_path(PATH)
	var tmp_path := final_path + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(d, false)
	f.close()
	# On écrit d'abord un fichier temporaire : un plantage pendant l'écriture n'abîme pas l'ancienne sauvegarde.
	if FileAccess.file_exists(final_path):
		DirAccess.remove_absolute(final_path)
	return DirAccess.rename_absolute(tmp_path, final_path) == OK

## Texte court pour le menu : "Sauvegarde du 18/10/2026 à 14h32 · 523 objets ramassés".
static func summary() -> String:
	var d := read()
	if d.is_empty():
		return ""
	var t: Dictionary = d.get("time", {})
	var when := ""
	if not t.is_empty():
		when = "du %02d/%02d/%d à %02dh%02d" % [t["day"], t["month"], t["year"], t["hour"], t["minute"]]
	return "Sauvegarde %s · %d objets ramassés" % [when, int(d.get("collected", 0))]
