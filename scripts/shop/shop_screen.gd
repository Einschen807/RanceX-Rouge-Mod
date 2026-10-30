extends Control
class_name ShopScreen
signal close_requested
var troop: TroopState
var stock: Dictionary
var item_layer: Control
var cards: Array[CardWidget] = []
var detail_mode := 0
var preview_upgrades := false
var money: Label
var status: Label
var tip: RelicTooltip
var merchant: OriginalFlatPlayer
var display: Control
var _entering := true

func _ready() -> void:
	name = "ShopScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group("modal_overlay")
	_build_backdrop()
	var keeper := _build_keeper()
	display = Control.new()
	display.name = "CarpetDisplay"
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.position = Vector2(0, -1080)
	add_child(display)
	_build_display()
	item_layer = Control.new()
	item_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.add_child(item_layer)
	move_child(keeper, get_child_count() - 1)
	money = _build_wallet()
	status = BattleArt.label(self, "", Vector2(600, 910), Vector2(1000, 48), 25, FormationArt.GOLD)
	_build_controls()
	tip = RelicTooltip.new()
	add_child(tip)
	tip.hide()
	troop.changed.connect(_refresh)
	_refresh()
	_slide_in.call_deferred()

# Themed shops (scripts/shop/milli_shop_screen.gd) replace these three pieces.

func _build_backdrop() -> void:
	if get_tree().get_nodes_in_group("run_map_screen").is_empty():
		var map := MapPaper.new()
		map.name = "MapBackground"
		map.size = Vector2(1920, 1080)
		add_child(map)

## The shopkeeper, kept above the display; returns its root node.
func _build_keeper() -> Control:
	var keeper := Control.new()
	keeper.name = "Keeper"
	keeper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(keeper)
	merchant = OriginalFlatPlayer.new()
	merchant.animation_path = "res://assets/shop/native/merchant/animation.json"
	merchant.scale = Vector2(0.88, 0.88)
	keeper.add_child(merchant)
	var bargain := NativeSettingsArt.button(keeper, "请商人降价", Vector2(70, 978), func() -> void: pass)
	bargain.name = "AskDiscount"
	return keeper

## Stylized goods display drawn by shaders/shop_display.gdshader (replaced the woven carpet photo).
func _build_display() -> void:
	var panel := ColorRect.new()
	panel.name = "Carpet"
	# Starts below the shell counter so the frame never runs under it.
	panel.position = Vector2(540, 100)
	panel.size = Vector2(1350, 836)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/shop_display.gdshader")
	material.set_shader_parameter("size", panel.size)
	panel.material = material
	display.add_child(panel)

func _price_color(affordable: bool) -> Color:
	return Color.WHITE if affordable else Color("ff7d72")

## Price under an item; `at` is the item's bottom-left corner.
func _price_tag(offer: Dictionary, index: int, at: Vector2) -> void:
	var cost := ShopInventory.price(offer, troop)
	ShopArt.shell(item_layer, at + Vector2(28, 6), Vector2(32, 32))
	var price_label := BattleArt.label(item_layer, str(cost), at + Vector2(68, 3), Vector2(110, 40), 27, _price_color(troop.gold >= cost))
	price_label.name = "Price%d" % index

## Top-right balance; returns the label _refresh updates.
func _build_wallet() -> Label:
	var label := ShopArt.money(self, Vector2(1510, 18))
	label.name = "Gold"
	return label

func _refresh_wallet() -> void:
	money.text = str(troop.gold)

func _slide_in() -> void:
	await get_tree().process_frame
	if not is_inside_tree(): return
	var tween := create_tween()
	tween.tween_property(display, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	_entering = false

func _build_controls() -> void:
	var details := OriginalUiButton.make(self, "square", Vector2(610, 978), Vector2(92, 92), _cycle_details)
	details.name = "Details"
	FormationArt.picture(details.content, "details_icon", Vector2(11, 11), Vector2(64, 64))
	var upgrades := OriginalUiButton.make(self, "square", Vector2(718, 978), Vector2(92, 92), func() -> void: pass)
	upgrades.name = "ViewUpgrades"
	upgrades.toggle_mode = true
	var mark := TextureRect.new()
	mark.name = "CheckMark"
	mark.texture = preload("res://assets/formation/upgrade_unchecked.svg")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.position = Vector2(27, 18)
	mark.size = Vector2(32, 32)
	upgrades.content.add_child(mark)
	FormationArt.label(upgrades.content, "查看升级", Vector2(7, 50), Vector2(72, 24), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	upgrades.toggled.connect(func(value: bool) -> void:
		preview_upgrades = value
		upgrades.selected = value
		mark.texture = preload("res://assets/formation/upgrade_checked.svg") if value else preload("res://assets/formation/upgrade_unchecked.svg")
		_refresh())
	var leave := NativeSettingsArt.button(self, "离开商店", Vector2(1500, 978), close_requested.emit)
	leave.name = "Leave"

func _refresh() -> void:
	if item_layer == null: return
	_refresh_wallet()
	if tip != null: tip.hide()
	BattleArt.clear(item_layer)
	cards.clear()
	for index: int in range(stock.items.size()):
		var offer: Dictionary = stock.items[index]
		# A bought item leaves its place empty: no goods, price or "sold" label.
		if offer.sold: continue
		var at: Vector2
		if index < 8:
			at = Vector2(610 + (index if index < 5 else index - 5) * 244, 140 if index < 5 else 510)
		else:
			at = Vector2(1360 + (index - 8) * 155, 515)
		var button: Button
		var dimensions := Vector2(150, 150)
		if offer.kind == "card":
			dimensions = Vector2(208, 312)
			var widget := CardWidget.new()
			widget.setup(troop.catalog.find_name(offer.id), troop, false, detail_mode, preview_upgrades)
			widget.card_clicked.connect(func(_name: String, _leader: bool) -> void: _buy(index, at + dimensions * 0.5))
			button = widget
			cards.append(widget)
		elif offer.kind == "relic" and not offer.id.is_empty():
			var database := RelicCatalog.new()
			database.load_catalog()
			var icon := RelicIcon.new()
			icon.record = database.by_name[offer.id]
			button = icon
			icon.mouse_entered.connect(func() -> void: tip.show_record(icon.record, at + Vector2(-260, 160)))
			icon.mouse_exited.connect(tip.hide)
			icon.pressed.connect(_buy.bind(index, at + dimensions * 0.5))
		else:
			button = Button.new()
			for style: String in ["normal", "hover", "pressed", "disabled", "focus"]: button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		button.name = "Item%d" % index
		button.position = at
		button.size = dimensions
		button.disabled = offer.unavailable or (offer.kind == "relic" and offer.id in troop.relics)
		if button.disabled: button.modulate = Color(0.48, 0.48, 0.48)
		item_layer.add_child(button)
		get_node("/root/UIAudio").bind_button(button)
		if not offer.unavailable:
			_price_tag(offer, index, at + Vector2(0, dimensions.y))
		else:
			BattleArt.label(item_layer, "暂无遗物", at + Vector2(0, dimensions.y + 3), Vector2(dimensions.x, 40), 24, FormationArt.GOLD, HORIZONTAL_ALIGNMENT_CENTER)

func _buy(index: int, at: Vector2) -> void:
	if _entering: return
	if get_node("/root/DebugConsole").panel.visible or is_instance_valid(get_node("/root/Settings").panel): return
	status.text = ShopInventory.buy(stock, index, troop, at)

func _cycle_details() -> void:
	if cards.any(func(card: CardWidget) -> bool: return card.flipping): return
	detail_mode = (detail_mode + 1) % 3
	for card: CardWidget in cards: card.flip_to(detail_mode)

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"): return
	if get_node("/root/DebugConsole").panel.visible or is_instance_valid(get_node("/root/Settings").panel): return
	get_viewport().set_input_as_handled()
	close_requested.emit()
