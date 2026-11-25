class_name SaveSystem
extends RefCounted
## Save files (from the godot-template project). There are CAMPAIGNS campaign
## slots ("Campaign 1" to 3); each holds MANUAL_SLOTS saves the player picks
## and AUTO_SLOTS autosaves used in turn (a new autosave overwrites the
## oldest). Hollowlike saves when you rest at a bench, as an autosave
## (GameState.rest_at); the manual slots are there for a save menu later. Each save is one JSON file:
##   user://saves/campaign_<n>/slot_<1-3>.json and auto_<1-3>.json
## holding {"header": ..., "state": GameState.to_dict()}. The header is what save
## lists show: the save's version, campaign, slot and date, plus whatever
## GameState.save_header() adds (the room, and the play time).
##
## Writes go to a .tmp file first and replace the save only once complete; the
## save they replace is kept as .bak, and a broken save is read from its .bak.
##
## What the last read skipped or repaired is listed in `notes`, as lines for
## the player.
##
## Debug saves: in debug builds, every save file copied into res://debug_saves/
## (unchanged; the file name is its label) is listed at the bottom of each
## campaign's saves on Load. Loading one makes that campaign current. They're
## read-only: never saved over or deleted. Their slot id is "debug:<file name>".

## The save format. Add 1 whenever a change makes existing saves invalid
## (GameState.to_dict()). A save of any other version is listed but refused: old
## saves aren't upgraded.
const VERSION := 1
const CAMPAIGNS := 3
const MANUAL_SLOTS := 3
const AUTO_SLOTS := 3

## Where campaigns live. Tests point it at their own folder.
static var root := "user://saves/"
## Where debug saves live (the folder has a .gdignore, so Godot doesn't import
## the files). Tests point it at their own folder.
static var debug_root := "res://debug_saves/"
const DEBUG_PREFIX := "debug:"
## What the last load skipped or repaired, as lines for the player.
static var notes: PackedStringArray = []


## Slot ids: "slot_1".."slot_3".
static func manual_slots() -> Array[String]:
	var slots: Array[String] = []
	for i in MANUAL_SLOTS:
		slots.append("slot_%d" % (i + 1))
	return slots


## Slot ids: "auto_1".."auto_3".
static func auto_slots() -> Array[String]:
	var slots: Array[String] = []
	for i in AUTO_SLOTS:
		slots.append("auto_%d" % (i + 1))
	return slots


static func is_auto(slot: String) -> bool:
	return slot.begins_with("auto_")


static func is_debug(slot: String) -> bool:
	return slot.begins_with(DEBUG_PREFIX)


## "Save 2", "Autosave 1" or "Debug: early_town".
static func slot_name(slot: String) -> String:
	if is_debug(slot):
		return _t("UI_SAVE_DEBUG").format({"name": slot.trim_prefix(DEBUG_PREFIX)})
	return _t("UI_SAVE_AUTOSAVE" if is_auto(slot) else "UI_SAVE_SLOT").format({"n": slot.get_slice("_", 1)})


static func campaign_dir(campaign: int) -> String:
	return root + "campaign_%d/" % campaign


## A slot's file; a debug save's is in debug_root whatever the campaign.
static func path(campaign: int, slot: String) -> String:
	if is_debug(slot):
		return debug_root + slot.trim_prefix(DEBUG_PREFIX) + ".json"
	return campaign_dir(campaign) + slot + ".json"


## The debug saves (debug builds only), as {slot, header}, by file name.
static func debug_saves() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not OS.is_debug_build() or not DirAccess.dir_exists_absolute(debug_root):
		return result
	var files := Array(DirAccess.get_files_at(debug_root)).filter(func(f: String) -> bool: return f.ends_with(".json"))
	files.sort()
	for file: String in files:
		var slot := DEBUG_PREFIX + file.get_basename()
		var header := read_header(0, slot)
		if not header.is_empty():
			result.append({"slot": slot, "header": header})
	return result


# --- Writing -----------------------------------------------------------------

## Writes `state` (GameState.to_dict()) to a slot, with `extra_header`
## (GameState.save_header()) in its header. Returns false if it couldn't.
static func write(campaign: int, slot: String, state: Dictionary, extra_header := {}) -> bool:
	if is_debug(slot):
		return false   # read-only
	DirAccess.make_dir_recursive_absolute(campaign_dir(campaign))
	var file_path := path(campaign, slot)
	var tmp := file_path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"header": make_header(campaign, slot, extra_header), "state": state}, "\t"))
	file.close()
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path + ".bak")
		DirAccess.rename_absolute(file_path, file_path + ".bak")
	return DirAccess.rename_absolute(tmp, file_path) == OK


## The next autosave slot: an empty one, or the oldest.
static func next_auto_slot(campaign: int) -> String:
	var oldest := ""
	var oldest_time := INF
	for slot in auto_slots():
		var header := read_header(campaign, slot)
		if header.is_empty():
			return slot
		if float(header.saved_at) < oldest_time:
			oldest_time = float(header.saved_at)
			oldest = slot
	return oldest


## The header: `extra` (GameState.save_header()), then what SaveSystem owns.
static func make_header(campaign: int, slot: String, extra: Dictionary) -> Dictionary:
	var header := extra.duplicate(true)
	header.merge({
		"version": VERSION, "campaign": campaign, "slot": slot,
		"saved_at": Time.get_unix_time_from_system(),
	}, true)
	return header


# --- Reading -----------------------------------------------------------------

## True if this build can load the save with this header.
static func is_loadable(header: Dictionary) -> bool:
	return int(header.get("version", 0)) == VERSION


## A save's {header, state}, or {} if there's none, neither it nor its .bak can
## be read, or it's another version. Fills `notes`.
static func read(campaign: int, slot: String) -> Dictionary:
	notes.clear()
	var file_path := path(campaign, slot)
	var save := _parse(file_path)
	if save.is_empty() and FileAccess.file_exists(file_path + ".bak"):
		save = _parse(file_path + ".bak")
		if not save.is_empty():
			notes.append(_t("UI_SAVE_NOTE_BACKUP").format({"slot": slot_name(slot)}))
	if save.is_empty():
		return {}
	if not is_loadable(save.header):
		var newer := int(save.header.get("version", 0)) > VERSION
		notes.append(_t("UI_SAVE_NOTE_NEWER" if newer else "UI_SAVE_NOTE_OLDER").format({"slot": slot_name(slot)}))
		return {}
	return save


## Why the last read() gave nothing, in one line for the player: its notes,
## or that the save couldn't be read.
static func load_problem() -> String:
	return " ".join(notes) if not notes.is_empty() else _t("UI_SAVE_UNREADABLE")


## Just the header (for save lists), or {} for an empty slot.
static func read_header(campaign: int, slot: String) -> Dictionary:
	var save := _parse(path(campaign, slot))
	if save.is_empty():
		save = _parse(path(campaign, slot) + ".bak")
	return save.get("header", {})


static func _parse(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var json := JSON.new()   # unlike JSON.parse_string, a broken file isn't logged as an error
	if json.parse(FileAccess.get_file_as_string(file_path)) != OK:
		return {}
	var parsed: Variant = json.data
	if parsed is Dictionary and parsed.get("header") is Dictionary and parsed.get("state") is Dictionary:
		return parsed
	return {}


## The saves in a campaign, as {slot, header}: the manual slots in order, then
## the autosaves newest first. Empty slots are left out.
static func saves(campaign: int) -> Array[Dictionary]:
	var manual: Array[Dictionary] = []
	for slot in manual_slots():
		var header := read_header(campaign, slot)
		if not header.is_empty():
			manual.append({"slot": slot, "header": header})
	var autos: Array[Dictionary] = []
	for slot in auto_slots():
		var header := read_header(campaign, slot)
		if not header.is_empty():
			autos.append({"slot": slot, "header": header})
	autos.sort_custom(func(a, b): return float(a.header.saved_at) > float(b.header.saved_at))
	return manual + autos


## The newest save in a campaign as {slot, header}, or {}.
static func latest(campaign: int) -> Dictionary:
	var newest := {}
	for save in saves(campaign):
		if newest.is_empty() or float(save.header.saved_at) > float(newest.header.saved_at):
			newest = save
	return newest


## The newest save this build can load, as {campaign, slot, header}, or {}
## (for Continue).
static func latest_overall() -> Dictionary:
	var newest := {}
	for c in range(1, CAMPAIGNS + 1):
		for save in saves(c):
			if is_loadable(save.header) and (newest.is_empty() or float(save.header.saved_at) > float(newest.header.saved_at)):
				newest = save
				newest.campaign = c
	return newest


static func is_used(campaign: int) -> bool:
	return not latest(campaign).is_empty()


## True if any campaign has a save, even one this build can't load.
static func any_used() -> bool:
	for c in range(1, CAMPAIGNS + 1):
		if is_used(c):
			return true
	return false


# --- Deleting ----------------------------------------------------------------

static func delete_save(campaign: int, slot: String) -> void:
	if is_debug(slot):
		return   # read-only
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path(campaign, slot) + suffix):
			DirAccess.remove_absolute(path(campaign, slot) + suffix)


static func delete_campaign(campaign: int) -> void:
	var dir := campaign_dir(campaign)
	if not DirAccess.dir_exists_absolute(dir):
		return
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + file)
	DirAccess.remove_absolute(dir)


# --- Text for save lists -----------------------------------------------------

## "2026-11-03 19:42".
static func date_text(header: Dictionary) -> String:
	var local := Time.get_unix_time_from_system() if header.is_empty() else float(header.saved_at)
	local += Time.get_time_zone_from_system().bias * 60.0
	return Time.get_datetime_string_from_unix_time(int(local), true).left(16)


## A save in one line for save lists: "Campaign 1 · Save 2 · 0:12:03 · 2026-11-12 19:42".
static func describe(campaign: int, save: Dictionary) -> String:
	return _t("UI_SAVE_LINE").format({"n": campaign, "slot": slot_name(save.slot),
			"time": time_text(float(save.header.get("play_time", 0.0))), "date": date_text(save.header)})


## A key's text in the language in use (static code has no tr()).
static func _t(key: String) -> String:
	return str(TranslationServer.translate(key))


## "1:02:33" (a play time).
static func time_text(seconds: float) -> String:
	var t := int(seconds)
	return "%d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]

