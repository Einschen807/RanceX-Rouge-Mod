extends Node2D
class_name OriginalFlatPlayer
signal frame_advanced(tick: int)
## Native nested timelines, sprite sequences, ELK particles and blend modes.
## Tilted planes are projected orthographically; no general 3D scene is needed.

@export_file("*.json") var animation_path: String = ""
@export var autoplay: bool = true
var playback_speed := 1.0
var project_tilt := false
var hidden_libraries: PackedStringArray = []
## Native status application replaces the placeholder icon without changing its timeline.
var texture_overrides: Dictionary = {}

const MIX_SHADER: Shader = preload("res://shaders/flat_mix.gdshader")
const ADD_SHADER: Shader = preload("res://shaders/flat_add.gdshader")
const MULTIPLY_SHADER: Shader = preload("res://shaders/flat_multiply.gdshader")
const SCREEN_SHADER: Shader = preload("res://shaders/flat_screen.gdshader")

class LayerState:
	extends RefCounted
	var tracks: Array = []
	var frame: int = 0
	var stopped: bool = false
	var nodes: Dictionary = {}
	var sprites: Dictionary = {}
	var children: Dictionary = {}
	var script_seen: Dictionary = {}
	var end_frame: int = 0
	var activated: bool = false

var fps: float = 30.0
var elapsed: float = 0.0
var ticks: int = 0
var _clock: float = 0.0
var _root: LayerState
var _data: Dictionary = {}
var _libraries: Dictionary = {}
var _textures: Dictionary = {}
var _reported_missing: Dictionary = {}

func _ready() -> void:
	if not animation_path.is_empty():
		load_animation(animation_path)

func load_animation(path: String) -> void:
	for child: Node in get_children():
		if child is CanvasItem:
			(child as CanvasItem).hide()
		child.queue_free()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "Invalid title animation data: " + path)
	_data = parsed as Dictionary
	assert(int(_data["version"]) in [13, 14, 15], "Unsupported title animation version")
	animation_path = path
	_libraries.clear()
	_textures.clear()
	_reported_missing.clear()
	for lib: Dictionary in _data["libraries"]:
		_libraries[String(lib["name"])] = lib
	for key: String in _data["textures"]:
		_textures[key] = load(String(_data["textures"][key])) as Texture2D
	for key: String in texture_overrides:
		_textures[key] = texture_overrides[key]
	fps = float(_data["fps"])
	elapsed = 0.0
	_clock = 0.0
	ticks = 0
	_root = _make_layer(_data["timelines"], self)
	_activate_layer(_root)
	_process_scripts(_root)
	_render_layer(_root, 1.0, Vector3.ONE, Vector3.ZERO, 0)

func _make_layer(tracks: Array, parent: Node2D) -> LayerState:
	var state: LayerState = LayerState.new()
	state.tracks = tracks
	# FLAT layers are listed front to back. Use reverse sibling insertion;
	# additive z_index on nested nodes would interleave separate subtrees.
	for i: int in range(tracks.size() - 1, -1, -1):
		var track: Dictionary = tracks[i]
		state.end_frame = maxi(state.end_frame, int(track["begin"]) + int(track["count"]) - 1)
		if int(track["type"]) != 3:
			continue
		var node: Node2D = Node2D.new()
		node.name = "Layer_%d" % i
		parent.add_child(node)
		state.nodes[i] = node
		var name_key: String = String(track["library"])
		var lib: Dictionary = _libraries.get(name_key, {})
		if int(lib.get("type", 2)) == 7:
			node.queue_free()
			if lib.has("emitter"):
				var emitter := FlatParticleEmitter.new()
				parent.add_child(emitter)
				emitter.configure(lib, track, self)
				state.nodes[i] = emitter
			else:
				state.nodes.erase(i)
			continue
		if int(lib.get("type", 2)) == 5:
			state.children[i] = _make_layer(lib["timelines"], node)
		else:
			var sprite: Sprite2D = Sprite2D.new()
			sprite.centered = false
			var material_instance: ShaderMaterial = ShaderMaterial.new()
			material_instance.shader = MIX_SHADER
			sprite.material = material_instance
			node.add_child(sprite)
			state.sprites[i] = sprite
	return state

func _process(delta: float) -> void:
	if _root == null or not autoplay:
		return
	elapsed += delta * playback_speed
	_clock += minf(delta, 0.5) * playback_speed
	var step: float = 1.0 / fps
	while _clock >= step:
		_clock -= step
		_tick_layer(_root)
		ticks += 1
	_render_layer(_root, 1.0, Vector3.ONE, Vector3.ZERO, 0)
	frame_advanced.emit(ticks)

func _tick_layer(state: LayerState) -> void:
	if not state.stopped:
		state.frame = mini(state.frame + 1, state.end_frame)
	_process_scripts(state)
	# A stopped parent still has running child timelines in the original title.
	for index: int in state.children:
		var track: Dictionary = state.tracks[index]
		var local: int = state.frame - int(track["begin"])
		if local >= 0 and local < int(track["count"]):
			var child: LayerState = state.children[index] as LayerState
			if not child.activated:
				_activate_layer(child)
			else:
				_tick_layer(child)
		else:
			_reset_layer(state.children[index] as LayerState)

func _activate_layer(state: LayerState) -> void:
	state.activated = true
	_process_scripts(state)
	for index: int in state.children:
		var track: Dictionary = state.tracks[index]
		if state.frame >= int(track["begin"]) and state.frame < int(track["begin"]) + int(track["count"]):
			_activate_layer(state.children[index] as LayerState)

func _reset_layer(state: LayerState) -> void:
	if not state.activated:
		return
	state.frame = 0
	state.stopped = false
	state.activated = false
	state.script_seen.clear()
	for child: LayerState in state.children.values():
		_reset_layer(child)

func is_finished() -> bool:
	return _root != null and not _has_running_layer(_root)

func is_root_finished() -> bool:
	if _data.has("play_duration"):
		return elapsed >= float(_data.play_duration)
	return _root != null and _root.frame >= _root.end_frame

func _has_running_layer(state: LayerState) -> bool:
	if not state.stopped and state.frame < state.end_frame:
		return true
	for child: LayerState in state.children.values():
		if child.activated and _has_running_layer(child):
			return true
	return false

func _process_scripts(state: LayerState) -> void:
	for safety: int in range(8):
		var jumped: bool = false
		for i: int in range(state.tracks.size()):
			var track: Dictionary = state.tracks[i]
			if int(track["type"]) != 5:
				continue
			var events: Array = track["script"]
			var matched: int = -1
			for j: int in range(events.size()):
				if int(events[j]["frame"]) <= state.frame:
					matched = j
			if matched == int(state.script_seen.get(i, -2)):
				continue
			state.script_seen[i] = matched
			if matched < 0:
				continue
			for op: Array in events[matched]["ops"]:
				if String(op[0]) == "stop":
					state.stopped = true
				elif String(op[0]) == "jump":
					state.frame = clampi(int(op[1]), 0, state.end_frame)
					jumped = true
		if not jumped:
			break

func _render_layer(state: LayerState, alpha: float, multiply: Vector3, added: Vector3, inherited_filter: int, ancestors: Array = [], parent_3d: Transform3D = Transform3D.IDENTITY) -> void:
	for index: int in state.nodes:
		var node: Node2D = state.nodes[index] as Node2D
		var track: Dictionary = state.tracks[index]
		var local: int = state.frame - int(track["begin"])
		node.visible = local >= 0 and local < int(track["count"]) and String(track["library"]) not in hidden_libraries
		if not node.visible:
			continue
		if node is FlatParticleEmitter:
			node.render_frame(local, ancestors)
			continue
		var keys: Array = track["frames"][local]
		assert(keys.size() <= 1, "Imported title tracks contain at most one key per frame")
		if keys.is_empty():
			node.hide()
			continue
		var key: Dictionary = keys[0]
		var scaling: Vector2 = Vector2(float(key["sx"]), float(key["sy"]))
		var transform_3d := parent_3d
		if project_tilt:
			# Compose in 3D before projecting. Projecting each ancestor separately
			# collapses planes turned 90 degrees even if their child rotates back.
			transform_3d *= FlatParticleEmitter.key_transform(key)
			node.top_level = true
			node.global_transform = global_transform * Transform2D(Vector2(transform_3d.basis.x.x, transform_3d.basis.x.y), Vector2(transform_3d.basis.y.x, transform_3d.basis.y.y), Vector2(transform_3d.origin.x, transform_3d.origin.y))
		else:
			assert(is_zero_approx(float(key["rx"])) and is_zero_approx(float(key["ry"])), "3D rotation requires battle plane projection")
			node.rotation = deg_to_rad(float(key["rz"]))
			node.scale = scaling
			var origin: Vector2 = Vector2(float(key["ox"]), float(key["oy"]))
			node.position = Vector2(float(key["x"]), float(key["y"])) - (origin * scaling).rotated(node.rotation)
		var current_alpha: float = alpha * float(key["alpha"]) / 255.0
		var current_mul: Vector3 = multiply * Vector3(float(key["mul_r"]), float(key["mul_g"]), float(key["mul_b"])) / 255.0
		var current_add: Vector3 = added + Vector3(float(key["add_r"]), float(key["add_g"]), float(key["add_b"])) / 255.0
		var draw_filter: int = int(key["filter"]) if int(key["filter"]) != 0 else inherited_filter
		if state.children.has(index):
			_render_layer(state.children[index] as LayerState, current_alpha, current_mul, current_add, draw_filter, ancestors + [key], transform_3d)
			continue
		var texture_name: String = String(track["library"])
		var lib: Dictionary = _libraries.get(texture_name, {})
		if int(lib.get("type", 2)) == 6:
			var sequence: Array = lib["sequence"]
			var frame_index: int = int(float(local) / maxi(int(lib["span"]), 1))
			match int(lib["loop"]):
				0: frame_index = mini(frame_index, sequence.size() - 1)
				1: frame_index %= sequence.size()
				2:
					var period: int = maxi(1, sequence.size() * 2 - 2)
					frame_index %= period
					if frame_index >= sequence.size():
						frame_index = period - frame_index
			texture_name = String(sequence[frame_index])
		var sprite: Sprite2D = state.sprites[index] as Sprite2D
		var texture: Texture2D = _textures.get(texture_name) as Texture2D
		if texture == null:
			sprite.hide()
			if not _reported_missing.has(texture_name):
				push_error("Missing title texture: " + texture_name)
				_reported_missing[texture_name] = true
			continue
		sprite.show()
		sprite.texture = texture
		var alignment: int = clampi(int(key.get("align", 1)) - 1, 0, 8)
		var ratio: Vector2 = Vector2(float(alignment % 3) * 0.5, float(int(alignment / 3.0)) * 0.5)
		sprite.flip_h = not project_tilt and bool(key["flip_x"])
		sprite.flip_v = not project_tilt and bool(key["flip_y"])
		sprite.region_enabled = int(key["clip_w"]) > 0 and int(key["clip_h"]) > 0
		if sprite.region_enabled:
			sprite.region_rect = Rect2(float(key["clip_x"]), float(key["clip_y"]), float(key["clip_w"]), float(key["clip_h"]))
		var drawn_size: Vector2 = sprite.region_rect.size if sprite.region_enabled else texture.get_size()
		sprite.position = -drawn_size * ratio
		var mat: ShaderMaterial = sprite.material as ShaderMaterial
		mat.shader = shader_for_filter(draw_filter)
		mat.set_shader_parameter("layer_alpha", current_alpha)
		mat.set_shader_parameter("multiply_color", current_mul)
		mat.set_shader_parameter("add_color", current_add)

func shader_for_filter(filter: int) -> Shader:
	match filter:
		1: return ADD_SHADER
		2: return MULTIPLY_SHADER
		3: return SCREEN_SHADER
	return MIX_SHADER

func sequence_texture(library: String, frame: int) -> String:
	var lib: Dictionary = _libraries.get(library, {})
	if int(lib.get("type", 2)) != 6: return library
	var sequence: Array = lib.sequence
	var index := int(float(frame) / maxi(int(lib.span), 1))
	match int(lib.loop):
		0: index = mini(index, sequence.size() - 1)
		1: index %= sequence.size()
		2:
			var period := maxi(1, sequence.size() * 2 - 2)
			index %= period
			if index >= sequence.size(): index = period - index
	return str(sequence[index])

func debug_state() -> Dictionary:
	var child_frames: Array = []
	if _root != null:
		for child: LayerState in _root.children.values():
			child_frames.append(child.frame)
	return {"path": animation_path, "ticks": ticks, "root_frame": _root.frame if _root != null else -1, "child_frames": child_frames, "missing_textures": _reported_missing.keys()}
