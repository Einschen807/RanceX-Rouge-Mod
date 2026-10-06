extends RefCounted
class_name SkillCutInCatalog
## Named, optional presentation scenes. Combat values remain in BattleState.
const ROOT := "res://assets/cut_ins/"
const ANIMATION := &"cut_in"

static func path_for(asset: String) -> String:
	var name := asset.strip_edges().trim_suffix(".tscn")
	if name.is_empty() or name in [".", ".."] or "/" in name or "\\" in name:
		return ""
	return ROOT + name + ".tscn"

static func instantiate(asset: String) -> Control:
	if asset.strip_edges().is_empty(): return null
	var path := path_for(asset)
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		push_warning("必杀技演出不存在，跳过演出：" + asset)
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("必杀技演出不是有效场景，跳过演出：" + asset)
		return null
	var node := scene.instantiate()
	var control := node as Control
	var player := node.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if control == null or player == null or not player.has_animation(ANIMATION):
		push_warning("必杀技演出需要Control根节点与AnimationPlayer/cut_in动画，跳过演出：" + asset)
		node.free()
		return null
	var animation := player.get_animation(ANIMATION)
	if animation.loop_mode != Animation.LOOP_NONE or animation.length <= 0.0:
		push_warning("必杀技演出cut_in动画必须有时长且不循环，跳过演出：" + asset)
		node.free()
		return null
	_prepare_nodes(control)
	return control

static func _prepare_nodes(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_NONE
	if node is AudioStreamPlayer:
		node.bus = &"Voice"
	for child: Node in node.get_children():
		_prepare_nodes(child)
