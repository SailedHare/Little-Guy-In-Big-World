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







var server := ""
var payload := ""
var http: HTTPRequest
var todo: Array = []
var fetched := {}
var build := ""
signal done(ok: bool, build: String)
var finished := false

func _ready() -> void:
	payload = EditorInterface.get_editor_paths().get_data_dir().path_join("scenetime")
	if server == "": return
	http = HTTPRequest.new(); http.timeout = 30; add_child(http)

	_start.call_deferred()

func _start() -> void:
	http.request_completed.connect(_on_manifest, CONNECT_ONE_SHOT)
	if http.request(server + "/v1/plugin") != OK: _finish(false); return
	get_parent().guard(http, 30.0)

func _on_manifest(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200: _finish(false); return
	var j = JSON.parse_string(body.get_string_from_utf8())
	if not (j is Dictionary) or not (j.get("files") is Dictionary): _finish(false); return
	build = str(j.get("build", ""))
	for rel in j["files"]:
		if not _allowed(rel): continue
		var local := payload.path_join(rel)
		if not FileAccess.file_exists(local) or FileAccess.get_sha256(local) != j["files"][rel]:
			todo.append([rel, j["files"][rel]])
	_next()


func _allowed(rel: String) -> bool:
	return rel == "bootstrap.gd" or RegEx.create_from_string("^addon/[a-z_]+\\.(gd|cfg)$").search(rel) != null

func _next() -> void:
	if todo.is_empty():
		_finish(fetched.is_empty() or _apply()); return
	http.request_completed.connect(_on_file, CONNECT_ONE_SHOT)
	if http.request(server + "/dl/plugin/" + todo[0][0]) != OK: _fail("couldn't request " + todo[0][0]); return
	get_parent().guard(http, 30.0)

func _on_file(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var item: Array = todo.pop_front()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200: _finish(false); return
	var ctx := HashingContext.new(); ctx.start(HashingContext.HASH_SHA256); ctx.update(body)
	if ctx.finish().hex_encode() != item[1]: _fail(item[0] + " didn't match its hash"); return
	if item[0].ends_with(".gd"):
		var s := GDScript.new(); s.source_code = body.get_string_from_utf8()
		if s.reload() != OK: _fail(item[0] + " doesn't parse"); return
	fetched[item[0]] = body
	_next()

func _apply() -> bool:
	for rel in fetched:
		var dst := payload.path_join(rel)
		DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
		var f := FileAccess.open(dst + ".tmp", FileAccess.WRITE)
		if f == null: _fail("can't write " + dst); return false
		f.store_buffer(fetched[rel]); f.close()
		DirAccess.rename_absolute(dst + ".tmp", dst)
		if rel == "bootstrap.gd":
			var s := GDScript.new(); s.source_code = fetched[rel].get_string_from_utf8(); s.reload()
			EditorInterface.get_editor_settings().set_setting("scenetime/bootstrap", s)
	EditorInterface.get_editor_settings().set_setting("scenetime/updated_at", Time.get_unix_time_from_system())
	get_parent().diag("info", "updated to build %s. It takes effect the next time a project opens." % build)
	return true

func _fail(why: String) -> void:
	get_parent().diag("warn", "skipped an update (%s). Keeping the current version." % why)
	_finish(false)

func _finish(ok: bool) -> void:
	if finished: return
	finished = true
	done.emit(ok, build)
	queue_free()
