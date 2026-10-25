extends RefCounted
class_name CurseCard
## Curse cards reuse the original item card layout on the 主人公 faction ground (下地／主人公所属).
const BACK := "res://assets/curses/card_back.png"
## Curses saved before curses.txt existed keep their text and show the original ？？？ item.
const UNKNOWN_ICON := "？？？"

static func make(held: Dictionary, card_scale := 1.0) -> RelicCard:
	var definition: Dictionary = CurseCatalog.shared().by_name.get(held.name, {})
	var card := RelicCard.new()
	card.name = "CurseCard"
	card.record = {"name": held.name, "icon": definition.get("icon", UNKNOWN_ICON), "description": definition.get("description", held.get("description", ""))}
	card.card_scale = card_scale
	card.back_path = BACK
	card.set_meta("curse", held.name)
	return card
