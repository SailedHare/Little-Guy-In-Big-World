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
extends Node




const UPLOAD_SEC := 20.0
const BATCH_LINES := 500
const DEFAULT_SERVER := ""
const PAIR_POLL_SEC := 3.0

var server := DEFAULT_SERVER
var token := ""
var install_id := ""
var project_id := ""
var data_dir: String
var state_path: String
var state := {"events_offset": 0, "blobs": {}}
var http_ev: HTTPRequest
var http_blob: HTTPRequest
var busy_ev := false
var busy_blob := false
var blob_queue: Array = []
var online := true
var pair := {}
var http_pair: HTTPRequest
var pair_dialog: AcceptDialog
var pair_timer: Timer

func _ready() -> void:
	data_dir = OS.get_data_dir().path_join("scenetime")
	state_path = data_dir.path_join("upload_state.json")
	_read_settings()
	_load_state()
	http_ev = HTTPRequest.new(); http_ev.timeout = 20; add_child(http_ev); http_ev.request_completed.connect(_on_events_done)
	http_blob = HTTPRequest.new(); http_blob.timeout = 60; add_child(http_blob); http_blob.request_completed.connect(_on_blob_done)
	var t := Timer.new(); t.wait_time = UPLOAD_SEC; t.timeout.connect(flush); add_child(t); t.start()
	_rescan_blobs()
	if server == "": return

	check_for_updates()
	var ut := Timer.new(); ut.wait_time = 3600.0; ut.timeout.connect(check_for_updates); add_child(ut); ut.start()
	if token == "":
		if Engine.is_editor_hint(): _start_pairing()
	else:
		flush()





class Watchdog extends Node:
	var left: float
	func _init(secs: float) -> void: left = secs
	func _process(delta: float) -> void:
		left -= minf(delta, 0.5)
		if left > 0: return
		var http := get_parent() as HTTPRequest
		queue_free()
		http.cancel_request()
		http.request_completed.emit(HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray())

static func guard(http: HTTPRequest, secs: float) -> void:
	http.timeout = 0
	var w := Watchdog.new(secs)
	http.add_child(w)
	http.request_completed.connect(func(_r, _c, _h, _b): if is_instance_valid(w): w.queue_free(), CONNECT_ONE_SHOT)


func pending_bytes() -> int:
	var path := data_dir.path_join("events.jsonl")
	if not FileAccess.file_exists(path): return 0
	var f := FileAccess.open(path, FileAccess.READ)
	return maxi(0, (f.get_length() if f else 0) - int(state.get("events_offset", 0)))


func check_for_updates() -> Node:
	if has_node("Updater"): return get_node("Updater")
	var path := (get_script() as Script).resource_path.get_base_dir().path_join("updater.gd")
	if not FileAccess.file_exists(path) or server == "": return null
	var updater = load(path).new(); updater.name = "Updater"; updater.server = server; add_child(updater)
	return updater



func diag(level: String, msg: String) -> void:
	if level == "info": print("scenetime: " + msg)
	else: push_warning("scenetime: " + msg)
	DirAccess.make_dir_recursive_absolute(data_dir)
	var path := data_dir.path_join("events.jsonl")
	var f := FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	if f == null: return
	f.seek_end(); f.store_line(JSON.stringify({"ev": "diag", "t": Time.get_unix_time_from_system(), "level": level, "msg": msg})); f.close()


var warned := {}
func _warn_once(key: String, msg: String) -> void:
	if warned.has(key): return
	warned[key] = true
	diag("warn", msg)



const TROUBLE_LOG_GAP := 600.0
var upload_trouble_logged := false
var last_trouble_log := -INF
func _server_error(result: int, code: int) -> void:
	online = false
	if upload_trouble_logged: return
	var now := Time.get_unix_time_from_system()
	if now - last_trouble_log < TROUBLE_LOG_GAP: return
	last_trouble_log = now; upload_trouble_logged = true
	if result != HTTPRequest.RESULT_SUCCESS:
		diag("warn", "can't reach %s right now. Tracking continues and uploads resume when it's back." % server)
	else:
		diag("warn", "the server answered HTTP %d. Tracking continues; uploads will keep retrying." % code)

var last_upload := 0.0
func _upload_ok() -> void:
	online = true
	last_upload = Time.get_unix_time_from_system()
	if upload_trouble_logged:
		upload_trouble_logged = false
		diag("info", "uploads are working again.")

func _read_settings() -> void:
	var es: EditorSettings = EditorInterface.get_editor_settings()
	if es:
		if es.has_setting("scenetime/server"): server = es.get_setting("scenetime/server")
		if es.has_setting("scenetime/token"): token = es.get_setting("scenetime/token")
		if es.has_setting("scenetime/install_id"): install_id = es.get_setting("scenetime/install_id")
		else:
			install_id = _uuid(); es.set_setting("scenetime/install_id", install_id)
	if install_id == "": install_id = "unknown"
	if server == "": diag("warn", "no server configured; run the installer again"); set_process(false)

func _uuid() -> String:
	var c := Crypto.new(); var b := c.generate_random_bytes(16)
	return b.hex_encode()

func _load_state() -> void:
	if FileAccess.file_exists(state_path):
		var j = JSON.parse_string(FileAccess.get_file_as_string(state_path))
		if j is Dictionary: state = j
func _save_state() -> void:
	var f := FileAccess.open(state_path, FileAccess.WRITE); f.store_string(JSON.stringify(state)); f.close()

func _headers(extra: PackedStringArray = []) -> PackedStringArray:
	var h := PackedStringArray(["Authorization: Bearer " + token])
	h.append_array(extra); return h


func flush() -> void:
	if not is_inside_tree(): return
	_send_events()
	_send_next_blob()

func _send_events() -> void:
	if busy_ev or token == "": return
	var path := data_dir.path_join("events.jsonl")
	if not FileAccess.file_exists(path): return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return
	var size := f.get_length()
	var offset: int = int(state.get("events_offset", 0))
	if offset > size: offset = 0
	if offset >= size: return
	f.seek(offset)
	var chunk := f.get_buffer(mini(size - offset, 512 * 1024)).get_string_from_utf8()
	f.close()
	var parts := chunk.split("\n")
	var complete := chunk.ends_with("\n")
	var lines: Array = []
	var bytes := 0
	for i in parts.size():
		var l := parts[i]
		if i == parts.size() - 1 and (not complete or l == ""): break
		if lines.size() >= BATCH_LINES: break
		lines.append(l); bytes += l.to_utf8_buffer().size() + 1
	if lines.is_empty(): return
	busy_ev = true
	http_ev.set_meta("bytes", bytes)
	var body := JSON.stringify({"install_id": install_id, "project_id": project_id, "plugin": 1, "lines": lines})
	var err := http_ev.request(server + "/v1/events", _headers(["Content-Type: application/json"]), HTTPClient.METHOD_POST, body)
	if err == OK: guard(http_ev, 20.0)
	else: busy_ev = false

func _on_events_done(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	busy_ev = false
	if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
		_upload_ok()
		state["events_offset"] = int(state.get("events_offset", 0)) + int(http_ev.get_meta("bytes"))
		_save_state()
		_send_events()
	elif result == HTTPRequest.RESULT_SUCCESS and code == 401:
		_token_rejected()
	else:
		_server_error(result, code)


func enqueue_blob(path: String, id: String, mime: String) -> void:
	if state["blobs"].has(path): return
	for q in blob_queue: if q[0] == path: return
	blob_queue.append([path, id, mime])
	_send_next_blob()

func _rescan_blobs() -> void:


	if DirAccess.dir_exists_absolute(data_dir.path_join("keyframes")):
		for kf in DirAccess.get_files_at(data_dir.path_join("keyframes")):
			var p := data_dir.path_join("keyframes").path_join(kf)
			enqueue_blob(p, "kf-" + kf.get_basename(), "text/plain")
	var shots := data_dir.path_join("shots")
	if not DirAccess.dir_exists_absolute(shots): return
	for sess in DirAccess.get_directories_at(shots):
		for img in DirAccess.get_files_at(shots.path_join(sess)):
			var p := shots.path_join(sess).path_join(img)
			enqueue_blob(p, "shot-" + FileAccess.get_sha256(p).substr(0, 40), "image/webp")

func _send_next_blob() -> void:
	if busy_blob or blob_queue.is_empty() or not online or token == "": return
	var item: Array = blob_queue[0]
	var bytes := FileAccess.get_file_as_bytes(item[0])
	if bytes.is_empty(): blob_queue.pop_front(); _send_next_blob(); return
	busy_blob = true
	var err := http_blob.request_raw(server + "/v1/blob/" + item[1], _headers(["Content-Type: " + item[2]]), HTTPClient.METHOD_PUT, bytes)
	if err == OK: guard(http_blob, 60.0)
	else: busy_blob = false

func _on_blob_done(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	busy_blob = false
	if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
		_upload_ok()
		var item: Array = blob_queue.pop_front()
		state["blobs"][item[0]] = true
		_save_state()
		_send_next_blob()
	elif result == HTTPRequest.RESULT_SUCCESS and code in [400, 413]:

		var item: Array = blob_queue.pop_front()
		state["blobs"][item[0]] = true
		_save_state()
		_send_next_blob()
	elif result == HTTPRequest.RESULT_SUCCESS and code == 401:
		_token_rejected()
	else:
		_server_error(result, code)


func is_linked() -> bool: return token != ""

func link_now() -> void:
	if token != "":
		diag("info", "already linked.")
		linked_changed.emit()
		return
	if not pair.is_empty():
		if pair_dialog: pair_dialog.popup_centered()
		else: _show_pair_dialog(pair["code"])
	else:

		if http_pair:
			http_pair.cancel_request(); http_pair.queue_free(); http_pair = null
		pairing_started = false
		diag("info", "starting sign-in...")
		_start_pairing()

func unlink() -> void:
	if token == "": return
	var r := HTTPRequest.new(); add_child(r)
	r.request_completed.connect(func(_a, _b, _c, _d): r.queue_free())
	r.request(server + "/v1/token/revoke", _headers(), HTTPClient.METHOD_POST, "")
	_forget_token()

var relink_reason := ""
func _token_rejected() -> void:
	relink_reason = "The link between this computer and your Hack Club account stopped working (it was unlinked, or tracking moved to a new server). Your time is still being recorded here; sign in again to upload it.\n\n"
	_warn_once("401", "this computer's link was rejected by the server. Sign in again (Project > Tools) to keep uploading.")
	_forget_token()

func _forget_token() -> void:
	token = ""
	var es := EditorInterface.get_editor_settings()
	if es and es.has_setting("scenetime/token"): es.erase("scenetime/token")
	linked_changed.emit()
	if Engine.is_editor_hint(): _start_pairing()

signal linked_changed


var pairing_started := false
func _start_pairing() -> void:
	if token != "" or pairing_started: return
	pairing_started = true
	http_pair = HTTPRequest.new(); http_pair.timeout = 15; add_child(http_pair)
	http_pair.request_completed.connect(_on_pair_start)
	var label := OS.get_environment("COMPUTERNAME") if OS.get_name() == "Windows" else OS.get_environment("HOSTNAME")
	if label == "": label = OS.get_name()
	var body := JSON.stringify({"install_id": install_id, "label": label})
	if http_pair.request(server + "/v1/pair/start", PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, body) != OK:
		_pair_retry("couldn't send the sign-in request")
	else: guard(http_pair, 15.0)

func _on_pair_start(result: int, code: int, _h: PackedStringArray, b: PackedByteArray) -> void:
	http_pair.request_completed.disconnect(_on_pair_start)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:

		_pair_retry("can't reach " + server if result != HTTPRequest.RESULT_SUCCESS else "HTTP %d" % code); return
	var j = JSON.parse_string(b.get_string_from_utf8())
	if not (j is Dictionary) or not j.has("code"):
		_pair_retry("unexpected reply from " + server); return
	pair = {"code": j["code"], "secret": j["secret"]}
	http_pair.request_completed.connect(_on_pair_poll)
	pair_timer = Timer.new(); pair_timer.wait_time = PAIR_POLL_SEC; pair_timer.timeout.connect(_poll_pair); add_child(pair_timer); pair_timer.start()
	if DisplayServer.get_name() != "headless": _show_pair_dialog(j["code"])
	else: print("scenetime: pair at ", _link_url())

func _pair_retry(why: String) -> void:
	_warn_once("pair", "couldn't start sign-in (%s). Retrying every minute; Project > Tools > Link account retries now." % why)
	pairing_started = false
	if http_pair: http_pair.queue_free(); http_pair = null
	get_tree().create_timer(60.0).timeout.connect(_start_pairing)

func _link_url() -> String:
	return server + "/link?code=" + str(pair.get("code", ""))

func _show_pair_dialog(code: String) -> void:
	pair_dialog = AcceptDialog.new()
	pair_dialog.title = "Scenetime"
	pair_dialog.dialog_text = relink_reason + "Sign in with Hack Club to start tracking your game dev time.\n\nLink your account at %s/link.\nYour Code: %s\nOr, click the button below.\n\nScenetime collects code snapshots and screenshots of the Godot editor. By continuing, you consent to that!" % [server.trim_prefix("https://").trim_prefix("http://"), code]


	pair_dialog.ok_button_text = "Open browser"
	pair_dialog.dialog_hide_on_ok = false
	pair_dialog.confirmed.connect(func(): OS.shell_open(_link_url()))

	pair_dialog.add_button("Later", true, "later")
	pair_dialog.custom_action.connect(func(a): if a == "later": pair_dialog.hide())
	EditorInterface.get_base_control().add_child(pair_dialog)
	pair_dialog.popup_centered()

func _poll_pair() -> void:
	if pair.is_empty() or http_pair.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED: return
	if http_pair.request(server + "/v1/pair/poll?code=%s&secret=%s" % [pair["code"], pair["secret"]]) == OK: guard(http_pair, 15.0)

func _on_pair_poll(result: int, code: int, _h: PackedStringArray, b: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS: return
	var j = JSON.parse_string(b.get_string_from_utf8())
	if not (j is Dictionary): return
	match j.get("status", ""):
		"paired":
			token = j["token"]
			EditorInterface.get_editor_settings().set_setting("scenetime/token", token)
			linked_changed.emit()
			pair = {}; pair_timer.stop(); pairing_started = false; relink_reason = ""
			if pair_dialog: pair_dialog.hide(); pair_dialog.queue_free(); pair_dialog = null
			flush()
		"expired", "unknown":
			pair = {}; pair_timer.stop(); pairing_started = false
			if pair_dialog: pair_dialog.queue_free(); pair_dialog = null
			get_tree().create_timer(30.0).timeout.connect(_start_pairing)
