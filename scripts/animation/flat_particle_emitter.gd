extends Node2D
class_name FlatParticleEmitter
## Deterministic ELK sprite particles. Time is supplied by the parent FLAT,
## so seeking, skipped render frames and battle speed use the same particle ages.
var parameters: Dictionary
var track: Dictionary
var player: Node2D
var particles: Array[Dictionary] = []
var sprites: Array[Sprite2D] = []
var birth_ancestors: Dictionary = {}
var random := RandomNumberGenerator.new()
var previous_frame := -1

func configure(lib: Dictionary, source_track: Dictionary, source_player: Node2D) -> void:
	parameters = lib.emitter
	track = source_track
	player = source_player
	top_level = true
	var active := maxi(1, int(track.count) - int(parameters.particle_lifetime) + 1)
	var count := int(parameters.create_count)
	for birth: int in range(active):
		var births: int
		if active == 1:
			births = count
		elif count >= active:
			births = int((birth + 1) * float(count) / active) - int(birth * float(count) / active)
		elif birth == 0:
			births = mini(1, count)
		else:
			births = int(birth * float(count - 1) / (active - 1)) - int((birth - 1) * float(count - 1) / (active - 1))
		random.seed = int(parameters.rand_seed) * (birth + 1)
		for i: int in range(births):
			var p := {"birth": birth, "scale": [], "angles": []}
			for axis: String in ["scale", "x_scale", "y_scale"]:
				p.scale.append(_endpoints(axis, bool(parameters.sync_scale_rand)))
			p.origin = _spawn_position()
			for axis: String in ["x_angle", "y_angle", "z_angle"]:
				p.angles.append(_endpoints(axis, bool(parameters.sync_rotation_rand)))
			p.direction = _direction(p.origin, birth)
			p.variation = 1.0 - (random.randf() - 0.5) * float(parameters.move_rand) * 0.01
			particles.append(p)
	# Allocate only the maximum simultaneously visible sprites, not all births.
	var peak := 0
	for frame: int in range(int(track.count)):
		var living := 0
		for p: Dictionary in particles:
			if frame >= int(p.birth) and frame < int(p.birth) + int(parameters.particle_lifetime): living += 1
		peak = maxi(peak, living)
	for i: int in range(peak):
		var sprite := Sprite2D.new()
		sprite.centered = false
		var mat := ShaderMaterial.new()
		mat.shader = player.MIX_SHADER
		sprite.material = mat
		add_child(sprite)
		sprites.append(sprite)

func _endpoints(field: String, sync: bool) -> Vector2:
	var a := (random.randf() - 0.5) * float(parameters["begin_" + field + "_rand"])
	var b := (random.randf() - 0.5) * float(parameters["end_" + field + "_rand"])
	return Vector2(float(parameters["begin_" + field]) + a, float(parameters["end_" + field]) + (a if sync else b))

func _unit() -> Vector3:
	return Vector3(random.randf() - 0.5, random.randf() - 0.5, random.randf() - 0.5).normalized()

func _spawn_position() -> Vector3:
	var direction := Vector3.ZERO
	match int(parameters.create_pos_type):
		1: direction = _unit()
		2: direction = Vector3(random.randf() - 0.5, random.randf() - 0.5, 0).normalized()
		3: return Vector3((random.randf() - 0.5) * float(parameters.create_pos_length), (random.randf() - 0.5) * float(parameters.create_pos_length2), 0)
	return direction * lerpf(float(parameters.create_pos_length2), float(parameters.create_pos_length), random.randf())

func _direction(origin: Vector3, birth: int) -> Vector3:
	var direction := Vector3(float(parameters.direction_x), float(parameters.direction_y), float(parameters.direction_z))
	match int(parameters.direction_type):
		0: direction = _unit()
		2, 3:
			var a: Dictionary = track.frames[maxi(0, birth - 1)][0]
			var b: Dictionary = track.frames[mini(int(track.count) - 1, birth + (1 if birth == 0 else 0))][0]
			direction = Vector3(float(b.x) - float(a.x), float(b.y) - float(a.y), 0)
			if int(parameters.direction_type) == 3: direction = -direction
		4:
			var normal := direction.normalized() if not direction.is_zero_approx() else Vector3.BACK
			var tangent := normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()
			direction = tangent.rotated(normal, random.randf() * TAU)
		5:
			# Radial ELK emitters (sparks, inward arrows, suction).
			direction = origin.normalized()
			if direction.is_zero_approx(): direction = _unit()
	if int(parameters.end_pos_type) == 1:
		direction = Vector3(float(parameters.end_pos_x), float(parameters.end_pos_y), float(parameters.end_pos_z)) - origin
	var angle := deg_to_rad(float(parameters.direction_angle)) * 0.5 * random.randf()
	direction = direction.normalized()
	if angle > 0.0:
		var tangent := direction.cross(Vector3.UP if absf(direction.y) < 0.9 else Vector3.RIGHT).normalized()
		direction = direction.rotated(tangent.rotated(direction, random.randf() * TAU), angle)
	return direction

static func key_transform(key: Dictionary, rotate := true, scaling := true, origin := true, flip_x := true, flip_y := true) -> Transform3D:
	var basis := Basis.IDENTITY
	if rotate:
		basis = Basis(Vector3.BACK, deg_to_rad(float(key.rz))) * Basis(Vector3.RIGHT, -deg_to_rad(float(key.rx))) * Basis(Vector3.UP, deg_to_rad(float(key.ry)))
	if scaling: basis = basis.scaled_local(Vector3(float(key.sx), float(key.sy), 1))
	var position := Vector3(float(key.x), float(key.y), 0)
	if origin: position -= basis * Vector3(float(key.ox), float(key.oy), 0)
	basis = basis.scaled_local(Vector3(-1 if flip_x and bool(key.flip_x) else 1, -1 if flip_y and bool(key.flip_y) else 1, 1))
	return Transform3D(basis, position)

func _inherited_transform(key: Dictionary) -> Transform3D:
	var connected := int(parameters.parent_key_mode) != 0
	return key_transform(key, connected or bool(parameters.inherit_rotation), connected or bool(parameters.inherit_scale), connected, connected or bool(parameters.inherit_reverse_lr), connected or bool(parameters.inherit_reverse_tb))

func render_frame(frame: int, ancestors: Array) -> void:
	if frame < previous_frame: birth_ancestors.clear()
	previous_frame = frame
	# Particle coordinates include the original ancestor chain. Cancel the Node2D chain.
	global_transform = player.global_transform
	var used := 0
	var life := int(parameters.particle_lifetime)
	var ppm := float(player._data.view_size[0]) / float(player._data.meter)
	for p: Dictionary in particles:
		var age := frame - int(p.birth)
		if age < 0 or age >= life: continue
		if not birth_ancestors.has(p.birth): birth_ancestors[p.birth] = ancestors.duplicate(true)
		var t := float(age) / life
		var fade := 1.0
		if int(parameters.fade_in_frame) > 0: fade = minf(fade, float(age) / float(parameters.fade_in_frame))
		if int(parameters.fade_out_frame) > 0: fade = minf(fade, float(life - age) / float(parameters.fade_out_frame))
		var source_frame := frame if int(parameters.pos_track_mode) == 1 else int(p.birth)
		var key: Dictionary = track.frames[source_frame][0]
		var chain: Array = birth_ancestors[p.birth] if int(parameters.parent_key_mode) == 2 else ancestors
		var transform_3d := Transform3D.IDENTITY
		var tint := Vector3.ONE
		var added := Vector3.ZERO
		var alpha := fade
		var filter := 0
		for inherited: Dictionary in chain + [key]:
			transform_3d *= _inherited_transform(inherited)
			if bool(parameters.inherit_alpha): alpha *= float(inherited.alpha) / 255.0
			if bool(parameters.inherit_mul_color): tint *= Vector3(inherited.mul_r, inherited.mul_g, inherited.mul_b) / 255.0
			if bool(parameters.inherit_add_color): added += Vector3(inherited.add_r, inherited.add_g, inherited.add_b) / 255.0
			if bool(parameters.inherit_draw_filter) and int(inherited.filter) != 0: filter = int(inherited.filter)
		if int(parameters.draw_filter) != 0: filter = int(parameters.draw_filter)
		var seconds: float = float(age) / float(player.fps)
		var acceleration := float(parameters.acceleration) * float(p.variation)
		var speed := float(parameters.speed) * float(p.variation)
		var moving_time: float = seconds
		if acceleration < 0 and speed != 0: moving_time = minf(seconds, absf(speed / acceleration))
		var curve := float(parameters.move_curve) * float(p.variation)
		var progress := pow(t, curve) if curve > 1 else (1 - pow(1 - t, -curve) if curve < -1 else t)
		var distance: float = speed * moving_time + 0.5 * acceleration * moving_time * moving_time + float(parameters.move_length) * float(p.variation) * progress
		var point: Vector3 = p.origin + p.direction * distance
		if int(parameters.end_pos_type) == 1:
			point = (p.origin as Vector3).lerp(Vector3(parameters.end_pos_x, parameters.end_pos_y, parameters.end_pos_z), progress)
		if bool(parameters.is_fall):
			var drag := float(parameters.air_resistance) / float(parameters.width) if float(parameters.width) != 0 else 0.0
			point.y += 9.8 * (seconds - (1.0 - exp(-drag * seconds)) / drag) / drag if drag > 0 else 4.9 * seconds * seconds
		var overall := lerpf(p.scale[0].x, p.scale[0].y, t)
		var scaling := Vector3(lerpf(p.scale[1].x, p.scale[1].y, t), lerpf(p.scale[2].x, p.scale[2].y, t), 1) * Vector3(overall, overall, 1)
		var angles := Vector3(lerpf(p.angles[0].x, p.angles[0].y, t), lerpf(p.angles[1].x, p.angles[1].y, t), lerpf(p.angles[2].x, p.angles[2].y, t))
		if bool(parameters.align_to_direction): angles.z += rad_to_deg(atan2(p.direction.y, p.direction.x)) + 90.0
		var basis := Basis(Vector3.BACK, deg_to_rad(angles.z)) * Basis(Vector3.RIGHT, -deg_to_rad(angles.x)) * Basis(Vector3.UP, deg_to_rad(angles.y))
		transform_3d *= Transform3D(basis.scaled_local(scaling), point * ppm)
		var sprite := sprites[used]
		used += 1
		var texture_name: String = player.sequence_texture(str(parameters.library_name), age)
		sprite.texture = player._textures.get(texture_name)
		if sprite.texture == null:
			sprite.hide()
			continue
		var align := clampi(int(parameters.particle_align) - 1, 0, 8)
		var offset := -sprite.texture.get_size() * Vector2(float(align % 3) * 0.5, float(align / 3) * 0.5)
		transform_3d.origin += transform_3d.basis * Vector3(offset.x, offset.y, 0)
		sprite.transform = Transform2D(Vector2(transform_3d.basis.x.x, transform_3d.basis.x.y), Vector2(transform_3d.basis.y.x, transform_3d.basis.y.y), Vector2(transform_3d.origin.x, transform_3d.origin.y))
		var mat: ShaderMaterial = sprite.material
		mat.shader = player.shader_for_filter(filter)
		mat.set_shader_parameter("layer_alpha", alpha)
		mat.set_shader_parameter("multiply_color", tint)
		mat.set_shader_parameter("add_color", added)
		sprite.show()
	for i: int in range(used, sprites.size()): sprites[i].hide()
