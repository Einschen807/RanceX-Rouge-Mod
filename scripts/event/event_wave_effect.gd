@tool
extends RichTextEffect
class_name EventWaveEffect
## Water-like ripple for 〖〗 spans: characters rise and fall one after another, left to right.
var bbcode := "event_wave"
const HEIGHT := 5.0
## Delay between neighbouring characters, single rise-and-fall time, and full cycle length.
const STEP := 0.055
const BUMP := 0.5
const PERIOD := 2.6

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var t := fposmod(char_fx.elapsed_time - char_fx.relative_index * STEP, PERIOD)
	if t < BUMP: char_fx.offset.y = -HEIGHT * sin(t / BUMP * PI)
	return true
