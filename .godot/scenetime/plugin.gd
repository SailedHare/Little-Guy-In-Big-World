@tool



@warning_ignore_start(
	"assert_always_false", "assert_always_true", "confusable_capture_reassignment", "confusable_identifier",
	"confusable_local_declaration", "confusable_local_usage", "constant_used_as_function", "deprecated_keyword",
	"empty_file", "enum_variable_without_default", "function_used_as_property",
	"get_node_default_without_onready", "incompatible_ternary", "inference_on_variant", "inferred_declaration",
	"int_as_enum_without_cast", "int_as_enum_without_match", "integer_division", "missing_tool",
	"narrowing_conversion", "native_method_override", "onready_with_export", "property_used_as_function",
	"redundant_await", "redundant_static_unload", "return_value_discarded", "shadowed_global_identifier",
	"shadowed_variable", "shadowed_variable_base_class", "standalone_expression", "standalone_ternary",
	"static_called_on_instance", "unassigned_variable", "unassigned_variable_op_assign", "unreachable_code",
	"unreachable_pattern", "unsafe_call_argument", "unsafe_cast", "unsafe_method_access",
	"unsafe_property_access", "unsafe_void_return", "untyped_declaration", "unused_local_constant",
	"unused_parameter", "unused_private_class_variable", "unused_signal", "unused_variable")
extends EditorPlugin

const PLUGIN_VERSION := 1
const SHOT_WIDTH := 1920
const SHOT_QUALITY := 0.5
const SHOT_SEC := 30.0
const ALIVE_SEC := 60.0
const IDLE_SEC := 120.0
const ACTIVITY_BUCKET_SEC := 10

var data_dir: String
var shot_dir: String
var log_path: String
var last_script := ""
var main_screen := "2D"
var was_playing := false
var state := {}
var last_input_t := 0.0
var last_mouse := Vector2i.ZERO
var idle := false
var bucket_active := 0
var bucket_ticks := 0
var bucket := {}
var code_edit: CodeEdit
var prev_text := ""
var key_dir: String
var last_hash := {}
var last_lines := 0

var last_versions := {}
var session_id := ""
var dbg: HCDebugger
var game_shot_seq := 9000000



class HCDebugger extends EditorDebuggerPlugin:
	var owner_plugin: Node
	func _has_capture(capture: String) -> bool:
		return capture == "game_view"
	func _capture(message: String, data: Array, _session_id: int) -> bool:
		if message == "game_view:get_screenshot" and data.size() == 4 and int(data[0]) >= 9000000:
			owner_plugin._on_game_shot(int(data[1]), int(data[2]), String(data[3]))
			return true
		return false

var uploader: Node
var project_id := ""

var session_secs := 0
var project_secs := 0
var times_path: String

func _enter_tree():
	session_id = str(int(Time.get_unix_time_from_system()))
	data_dir = OS.get_data_dir().path_join("scenetime")
	shot_dir = data_dir.path_join("shots").path_join(session_id)
	key_dir = data_dir.path_join("keyframes")
	DirAccess.make_dir_recursive_absolute(shot_dir)
	DirAccess.make_dir_recursive_absolute(key_dir)
	log_path = data_dir.path_join("events.jsonl")
	if not FileAccess.file_exists(log_path): FileAccess.open(log_path, FileAccess.WRITE).close()
	project_id = _project_id()
	times_path = data_dir.path_join("times.json")
	var times = JSON.parse_string(FileAccess.get_file_as_string(times_path)) if FileAccess.file_exists(times_path) else null
	if times is Dictionary: project_secs = int(times.get(project_id, 0))
	uploader = load(get_script().resource_path.get_base_dir().path_join("uploader.gd")).new()
	uploader.project_id = project_id

	_build_menu()
	uploader.ready.connect(_refresh_menu, CONNECT_ONE_SHOT)
	uploader.linked_changed.connect(_refresh_menu)
	add_child(uploader)
	emit_ev("session_start", {"project": ProjectSettings.globalize_path("res://"), "project_name": ProjectSettings.get_setting("application/config/name", ""), "project_id": project_id, "git_remote": _git_remote(), "godot": Engine.get_version_info().string, "plugin": PLUGIN_VERSION, "build": _build_id()})

	scene_changed.connect(func(root): emit_ev("scene_changed", {"scene": root.scene_file_path if root else null}))
	scene_saved.connect(func(p): emit_ev("scene_saved", {"path": p}); _keyframe_file(p); _screenshot("save"))
	resource_saved.connect(func(res): emit_ev("resource_saved", {"path": res.resource_path}); _keyframe_file(res.resource_path))
	ProjectSettings.settings_changed.connect(func(): emit_ev("project_settings_changed", {}))
	main_screen_changed.connect(func(n): main_screen = n; emit_ev("main_screen", {"screen": n}))
	EditorInterface.get_script_editor().editor_script_changed.connect(_on_script)
	get_undo_redo().history_changed.connect(_on_history)
	get_undo_redo().version_changed.connect(_on_history)

	last_input_t = Time.get_unix_time_from_system()
	_add_timer(SHOT_SEC, func(): if not idle: _screenshot("periodic"))
	_add_timer(ALIVE_SEC, func(): emit_ev("alive", {}); _save_times(); _refresh_label())
	dbg = HCDebugger.new(); dbg.owner_plugin = self
	add_debugger_plugin(dbg)
	_add_timer(SHOT_SEC, func(): if was_playing: _request_game_shot())
	_add_timer(1.0, _poll)
	set_process_input(true)
	_reset_bucket()
	get_tree().create_timer(5.0).timeout.connect(func(): _screenshot("start"))


func _build_id() -> String:
	var dir := (get_script() as Script).resource_path.get_base_dir()
	var names: Array = []
	for f in DirAccess.get_files_at(dir): if f.ends_with(".gd") or f.ends_with(".cfg"): names.append(f)
	names.sort()
	var lines := ""
	for f in names: lines += "addon/%s %s\n" % [f, FileAccess.get_sha256(dir.path_join(f))]
	return lines.sha256_text().substr(0, 12)

func _reset_bucket():
	bucket = {"keys": 0, "shortcuts": 0, "clicks": 0, "drag_px": 0, "mouse_px": 0, "scrolls": 0, "text_edits": 0, "lines_delta": 0}

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed or event.alt_pressed or event.meta_pressed: bucket["shortcuts"] += 1
		else: bucket["keys"] += 1
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]: bucket["scrolls"] += 1
		else: bucket["clicks"] += 1
	elif event is InputEventMouseMotion:
		var d := int(event.relative.length())
		if event.button_mask != 0: bucket["drag_px"] += d
		else: bucket["mouse_px"] += d



func _project_id() -> String:
	var p := ProjectSettings.globalize_path("res://.godot/scenetime/project_id")
	if FileAccess.file_exists(p): return FileAccess.get_file_as_string(p).strip_edges()
	var id := Crypto.new().generate_random_bytes(8).hex_encode()
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f: f.store_string(id); f.close()
	return id

func _git_remote() -> String:
	var cfg := ProjectSettings.globalize_path("res://.git/config")
	if not FileAccess.file_exists(cfg): return ""
	var re := RegEx.new(); re.compile("\\[remote \"origin\"\\][^\\[]*?url\\s*=\\s*(\\S+)")
	var m := re.search(FileAccess.get_file_as_string(cfg))
	return m.get_string(1) if m else ""


enum { MENU_STATUS, MENU_LINK, MENU_UNINSTALL, MENU_UPDATE }
var menu: PopupMenu
func _build_menu() -> void:
	menu = PopupMenu.new()
	menu.add_item("Status", MENU_STATUS)
	menu.add_item("Check for updates", MENU_UPDATE)
	menu.add_item("Link account", MENU_LINK)
	menu.add_item("Uninstall Scenetime", MENU_UNINSTALL)
	menu.id_pressed.connect(_on_menu)
	add_tool_submenu_item(menu_label, menu)

	var tools := menu.get_parent() as PopupMenu
	tools.about_to_popup.connect(_refresh_label)
	if tools.get_parent() is PopupMenu: (tools.get_parent() as PopupMenu).about_to_popup.connect(_refresh_label)
	_refresh_label()

var menu_label := "Scenetime"
func _refresh_label() -> void:
	var tools := menu.get_parent() as PopupMenu
	var label := "Scenetime: %s tracked" % _dur(project_secs)
	for i in tools.item_count:
		if tools.get_item_text(i) == menu_label: tools.set_item_text(i, label)
	menu_label = label

func _dur(secs: int) -> String:
	var m := secs / 60
	return "%dm" % m if m < 60 else "%dh %dm" % [m / 60, m % 60]

func _save_times() -> void:
	var times = JSON.parse_string(FileAccess.get_file_as_string(times_path)) if FileAccess.file_exists(times_path) else null
	if not (times is Dictionary): times = {}
	times[project_id] = project_secs
	var f := FileAccess.open(times_path, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(times)); f.close()

func _on_menu(id: int) -> void:
	if id == MENU_STATUS: _show_status()
	elif id == MENU_LINK:
		if uploader.is_linked(): uploader.unlink()
		else: uploader.link_now()
	elif id == MENU_UNINSTALL: _confirm_uninstall()
	elif id == MENU_UPDATE: _check_updates()



func _check_updates() -> void:
	var u = uploader.check_for_updates()
	if u == null: _update_dialog(false, ""); return
	u.done.connect(_update_dialog, CONNECT_ONE_SHOT)

func _update_dialog(ok: bool, build: String) -> void:
	var d := AcceptDialog.new()
	d.title = "Scenetime"
	d.ok_button_text = "OK"
	if not ok: d.dialog_text = "Couldn't check for updates. Check your internet connection and try again."
	elif build == _build_id(): d.dialog_text = "Scenetime is up to date."
	else:
		d.dialog_text = "Scenetime has been updated to version %s. Restart Godot to apply the changes." % build
		d.ok_button_text = "Later"
		d.add_button("Restart now", false, "restart")
		d.custom_action.connect(func(_a): EditorInterface.restart_editor(true))
	d.visibility_changed.connect(func(): if not d.visible: d.queue_free())
	EditorInterface.get_base_control().add_child(d)
	d.popup_centered()


func _refresh_menu() -> void:
	if menu: menu.set_item_text(menu.get_item_index(MENU_LINK), "Unlink account" if uploader.is_linked() else "Link account")

func _add_timer(secs: float, cb: Callable):
	var t := Timer.new(); t.wait_time = secs; t.timeout.connect(cb); add_child(t); t.start()

func _on_script(sc):
	var path: String = sc.resource_path if sc else ""
	if path == last_script: return
	last_script = path
	emit_ev("script_focus", {"path": path})
	_hook_code_edit()

func _hook_code_edit():
	var ed := EditorInterface.get_script_editor().get_current_editor()
	var ce := ed.get_base_editor() if ed else null
	if ce == code_edit: return
	if code_edit and code_edit.text_changed.is_connected(_on_text_changed): code_edit.text_changed.disconnect(_on_text_changed)
	code_edit = ce as CodeEdit
	if code_edit:
		last_lines = code_edit.get_line_count()
		prev_text = code_edit.text
		_keyframe_text(last_script, prev_text, "open")
		code_edit.text_changed.connect(_on_text_changed)

func _on_text_changed():
	bucket["text_edits"] += 1
	var cur := code_edit.text
	_log_op(prev_text, cur)
	prev_text = cur
	var lines := code_edit.get_line_count()
	var delta := lines - last_lines
	last_lines = lines
	bucket["lines_delta"] += delta
	if abs(delta) >= 5:
		emit_ev("big_text_change", {"path": last_script, "lines_delta": delta, "lines": lines})

func _on_history():
	var ur := get_undo_redo()
	var ids := [EditorUndoRedoManager.GLOBAL_HISTORY]
	var root := EditorInterface.get_edited_scene_root()
	if root: ids.append(ur.get_object_history_id(root))
	for id in ids:
		var h: UndoRedo = ur.get_history_undo_redo(id)
		if h == null: continue
		var v := h.get_version()
		var prev: int = last_versions.get(id, -1)
		if v == prev and prev != -1:
			continue
		last_versions[id] = v
		var kind := "undo_action"
		if prev != -1 and v < prev: kind = "undo"
		elif prev != -1 and v > prev + 1: kind = "redo"
		if h.get_current_action_name() == "" and kind == "undo_action": continue
		emit_ev(kind, {"action": h.get_current_action_name(), "history": "global" if id == 0 else "scene", "version": v})


func _any_window_focused() -> bool:
	for w in DisplayServer.get_window_list():
		if DisplayServer.window_is_focused(w): return true
	return false

func _poll():
	var now := Time.get_unix_time_from_system()

	var playing := EditorInterface.is_playing_scene()
	if playing != was_playing:
		was_playing = playing
		emit_ev("play_start" if playing else "play_stop", {"scene": EditorInterface.get_playing_scene()})
		if playing:
			_screenshot("play")
			get_tree().create_timer(2.0).timeout.connect(_request_game_shot)



	var focused := _any_window_focused()
	var mouse := DisplayServer.mouse_get_position()
	var had_input := (focused or playing) and (mouse != last_mouse or Input.is_anything_pressed() or Input.get_last_mouse_velocity() != Vector2.ZERO)
	last_mouse = mouse
	if had_input:
		last_input_t = now
		bucket_active += 1
	bucket_ticks += 1
	if bucket_ticks >= ACTIVITY_BUCKET_SEC:
		if bucket_active > 0:
			var d := bucket.duplicate(); d["active_secs"] = bucket_active; d["of"] = bucket_ticks
			emit_ev("activity", d)
		bucket_active = 0; bucket_ticks = 0; _reset_bucket()
	var now_idle := now - last_input_t > IDLE_SEC
	if not now_idle or playing: session_secs += 1; project_secs += 1
	if now_idle != idle:
		idle = now_idle
		emit_ev("idle" if idle else "active", {"since": last_input_t if idle else null})

	var root := EditorInterface.get_edited_scene_root()
	var cur := {
		"focused": focused,
		"screen": main_screen,
		"scene": root.scene_file_path if root else "",
	}
	var diff := {}
	for k in cur:
		if state.get(k) != cur[k]: diff[k] = cur[k]
	if diff.size():
		state = cur
		emit_ev("state", diff)

func _request_game_shot():
	if not was_playing or dbg == null: return
	if not is_inside_tree(): return
	for sess in dbg.get_sessions():
		if is_instance_valid(sess) and sess.is_active():
			game_shot_seq += 1
			sess.send_message("scene:rq_screenshot", [game_shot_seq])

func _on_game_shot(w: int, h: int, png_path: String):
	var img := Image.load_from_file(png_path)
	DirAccess.remove_absolute(png_path)
	if img == null or img.is_empty(): return
	if w > SHOT_WIDTH: img.resize(SHOT_WIDTH, int(h * SHOT_WIDTH / float(w)), Image.INTERPOLATE_BILINEAR)
	var fpath := shot_dir.path_join("%d-game.webp" % int(Time.get_unix_time_from_system()))
	img.save_webp(fpath, true, SHOT_QUALITY)
	var id := "shot-" + FileAccess.get_sha256(fpath).substr(0, 40)
	emit_ev("screenshot", {"why": "game", "kind": "game", "file": fpath, "blob": id, "bytes": FileAccess.get_file_as_bytes(fpath).size(), "src": [w, h]})
	if uploader: uploader.enqueue_blob(fpath, id, "image/webp")

func _screenshot(why: String):
	if DisplayServer.get_name() == "headless": return
	var t0 := Time.get_ticks_usec()
	var img: Image = EditorInterface.get_base_control().get_viewport().get_texture().get_image()
	if img == null or img.is_empty(): return
	var src := img.get_size()
	if src.x > SHOT_WIDTH: img.resize(SHOT_WIDTH, int(src.y * SHOT_WIDTH / src.x), Image.INTERPOLATE_BILINEAR)
	var fname := "%d.webp" % int(Time.get_unix_time_from_system())
	var fpath := shot_dir.path_join(fname)
	img.save_webp(fpath, true, SHOT_QUALITY)
	var bytes := FileAccess.get_file_as_bytes(fpath).size()
	var id := "shot-" + FileAccess.get_sha256(fpath).substr(0, 40)
	emit_ev("screenshot", {"why": why, "file": fpath, "blob": id, "bytes": bytes, "src": [src.x, src.y], "ms": (Time.get_ticks_usec() - t0) / 1000.0})
	if uploader: uploader.enqueue_blob(fpath, id, "image/webp")



func _log_op(old: String, new: String):
	if old == new: return
	var ol := old.length(); var nl := new.length()
	var pre := 0
	var maxpre := mini(ol, nl)
	while pre < maxpre and old.unicode_at(pre) == new.unicode_at(pre): pre += 1
	var suf := 0
	var maxsuf := mini(ol, nl) - pre
	while suf < maxsuf and old.unicode_at(ol - 1 - suf) == new.unicode_at(nl - 1 - suf): suf += 1
	var ev := {"path": last_script, "pos": pre, "del": ol - pre - suf, "ins": new.substr(pre, nl - pre - suf), "line": code_edit.get_caret_line()}
	emit_ev("op", ev)

func _keyframe_file(res_path: String):
	if not FileAccess.file_exists(res_path): return
	_keyframe_text(res_path, FileAccess.get_file_as_string(res_path), "save")

func _keyframe_text(res_path: String, text: String, why: String):
	var h := text.sha1_text()
	if last_hash.get(res_path) == h: return
	last_hash[res_path] = h
	var fpath := key_dir.path_join(h + ".txt")
	if not FileAccess.file_exists(fpath):
		var f := FileAccess.open(fpath, FileAccess.WRITE); f.store_string(text); f.close()
	emit_ev("keyframe", {"path": res_path, "hash": h, "blob": "kf-" + h, "why": why, "bytes": text.length(), "lines": text.count("\n") + 1})
	if uploader: uploader.enqueue_blob(fpath, "kf-" + h, "text/plain")

func emit_ev(kind: String, data: Dictionary):
	data["t"] = Time.get_unix_time_from_system(); data["ev"] = kind

	var f := FileAccess.open(log_path, FileAccess.READ_WRITE)
	if f == null: return
	f.seek_end(); f.store_line(JSON.stringify(data)); f.close()

func _exit_tree():
	if menu: remove_tool_menu_item(menu_label)
	if dbg: remove_debugger_plugin(dbg)
	if uninstalling: return
	emit_ev("session_end", {})
	_save_times()
	if uploader: uploader.flush()




func _show_status() -> void:
	var es := EditorInterface.get_editor_settings()
	if not uploader.is_linked() or uploader.server == "": _status_dialog(es, null); return
	var http := HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(result, code, _h, body):
		http.queue_free()
		var who = null
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var j = JSON.parse_string(body.get_string_from_utf8())
			who = j.get("user") if j is Dictionary else null
			if who == null: who = {}
		_status_dialog(es, who), CONNECT_ONE_SHOT)
	if http.request(uploader.server + "/v1/ping", uploader._headers()) != OK: http.queue_free(); _status_dialog(es, null); return
	uploader.guard(http, 8.0)

func _status_dialog(es: EditorSettings, who) -> void:
	var get := func(k, d = null): return es.get_setting("scenetime/" + k) if es.has_setting("scenetime/" + k) else d
	var lines: Array[String] = []
	lines.append("Tracking: on in " + str(ProjectSettings.get_setting("application/config/name", "this project")))
	if not uploader.is_linked(): lines.append("Account: not linked (Project > Tools > Scenetime > Link account)")
	elif who == null: lines.append("Account: linked (couldn't reach the server to check which account)")
	elif who.is_empty(): lines.append("Account: this link isn't valid anymore; link again")
	else: lines.append("Account: linked as %s" % str(who.get("email", who.get("name", "?"))))
	var kb: float = uploader.pending_bytes() / 1024.0
	var files: int = uploader.blob_queue.size()
	if kb < 1 and files == 0: lines.append("Uploads: all caught up")
	else: lines.append("Uploads: %s waiting (%.0f KB of activity, %d files)" % ["still" if uploader.online else "offline,", kb, files])
	lines.append("Last upload: " + (_when(uploader.last_upload) if uploader.last_upload > 0 else "none yet this session"))
	lines.append("Session started: " + _when(float(session_id)))
	lines.append("Raw project time: " + _dur(project_secs))
	lines.append("Raw session time: " + _dur(session_secs))
	lines.append("These numbers are for internal & debugging use; they might not be accurate!")
	lines.append("")
	lines.append("Plugin version: " + _build_id())
	lines.append("Last updated: " + (_when(float(get.call("updated_at"))) if get.call("updated_at") != null else "not since install"))
	lines.append("Installer version: " + str(get.call("installer_version", "unknown")))
	lines.append("Installed: " + (_when(float(get.call("installed_at"))) if get.call("installed_at") != null else "unknown"))
	lines.append("Server: " + uploader.server)
	lines.append("Godot: %s on %s" % [Engine.get_version_info().string, OS.get_name()])
	lines.append("Install ID: " + str(uploader.install_id))
	lines.append("Data folder: " + data_dir)
	var recent := _recent_diag(5)
	if recent.size():
		lines.append("")
		lines.append("Recent messages:")
		for r in recent: lines.append("  " + r)
	var text := "\n".join(lines)

	var d := AcceptDialog.new()
	d.title = "Scenetime status"
	d.dialog_text = text
	d.ok_button_text = "Close"
	d.add_button("Copy to clipboard", false, "copy")
	d.custom_action.connect(func(_a):
		DisplayServer.clipboard_set("Scenetime status\n" + text)
		for b in d.get_ok_button().get_parent().get_children(): if b is Button and b.text == "Copy to clipboard": b.text = "Copied!")
	d.visibility_changed.connect(func(): if not d.visible: d.queue_free())
	EditorInterface.get_base_control().add_child(d)
	d.popup_centered()

func _when(t: float) -> String:
	var ago := Time.get_unix_time_from_system() - t
	var rel := "just now" if ago < 60 else ("%d min ago" % int(ago / 60) if ago < 3600 else ("%d h ago" % int(ago / 3600) if ago < 86400 else "%d days ago" % int(ago / 86400)))
	var local: float = t + Time.get_time_zone_from_system().get("bias", 0) * 60
	return "%s (%s)" % [Time.get_datetime_string_from_unix_time(int(local), true), rel]


func _recent_diag(n: int) -> Array[String]:
	var out: Array[String] = []
	var f := FileAccess.open(log_path, FileAccess.READ)
	if f == null: return out
	f.seek(maxi(0, f.get_length() - 65536))
	for line in f.get_buffer(65536).get_string_from_utf8().split("\n"):
		if not line.contains("\"diag\""): continue
		var e = JSON.parse_string(line)
		if e is Dictionary and e.get("ev") == "diag": out.append("%s  %s" % [_when(float(e["t"])).get_slice(" (", 0), str(e.get("msg", ""))])
	return out.slice(-n)


var uninstalling := false

func _confirm_uninstall() -> void:
	var d := ConfirmationDialog.new()
	d.title = "Uninstall Scenetime"
	d.ok_button_text = "Uninstall"
	var box := VBoxContainer.new()
	var msg := Label.new()
	msg.text = "Are you sure you want to uninstall Scenetime?"
	var del := CheckBox.new()
	del.text = "Also wipe Scenetime data on this computer (project info, time logged, etc)"
	del.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	del.custom_minimum_size = Vector2(460, 0)
	box.add_child(msg); box.add_child(del)
	d.add_child(box)
	d.confirmed.connect(func(): _uninstall(del.button_pressed))
	d.visibility_changed.connect(func(): if not d.visible: d.queue_free())
	EditorInterface.get_base_control().add_child(d)
	d.popup_centered()

func _uninstall(delete_data: bool) -> void:
	uninstalling = true
	for c in get_children(): if c is Timer: c.stop()
	var es := EditorInterface.get_editor_settings()
	var server: String = es.get_setting("scenetime/server") if es.has_setting("scenetime/server") else ""
	var token: String = es.get_setting("scenetime/token") if es.has_setting("scenetime/token") else ""
	if not delete_data: emit_ev("diag", {"level": "info", "msg": "uninstalled"})
	if uploader: remove_child(uploader); uploader.free(); uploader = null

	if server != "" and token != "":
		var r := HTTPRequest.new(); get_tree().root.add_child(r)
		r.request_completed.connect(func(_a, _b, _c, _d): r.queue_free())
		if r.request(server + "/v1/token/revoke", PackedStringArray(["Authorization: Bearer " + token]), HTTPClient.METHOD_POST, "") != OK: r.queue_free()

	for k in ["bootstrap", "token", "server", "install_id", "disabled", "notice_seen", "installer_version", "installed_at", "updated_at"]:
		if es.has_setting("scenetime/" + k): es.erase("scenetime/" + k)
	_rm_rf(EditorInterface.get_editor_paths().get_data_dir().path_join("scenetime"))
	if delete_data: _rm_rf(data_dir)
	print("scenetime: uninstalled%s." % (" and deleted its local data" if delete_data else ""))

	_turn_off.call_deferred(get_script().resource_path.get_base_dir().path_join("plugin.cfg"))

static func _turn_off(cfg: String) -> void:
	cfg = ProjectSettings.globalize_path(cfg) if cfg.begins_with("res://") else cfg
	var res_cfg := ProjectSettings.localize_path(cfg)
	var before = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	EditorInterface.set_plugin_enabled(res_cfg, false)

	ProjectSettings.set_setting("editor_plugins/enabled", before if before.size() else null)
	ProjectSettings.save()
	_rm_rf(cfg.get_base_dir())

static func _rm_rf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	for d in DirAccess.get_directories_at(path): _rm_rf(path.path_join(d))
	for f in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
