extends RefCounted
class_name SkillElements
## Effect 48 adds distinct digits to the actor's native element.
static func valid(value: int) -> bool:
	if value < 0: return false
	for digit: String in str(value):
		if int(digit) not in range(0, 6): return false
	return true

static func resolve(skill: Dictionary, native_element: int) -> Array[int]:
	var result: Array[int] = []
	if native_element > 0: result.append(native_element)
	for slot: int in range(1, 4):
		if int(skill.get("effect%d" % slot, 0)) != 48: continue
		for digit: String in str(int(skill.get("value%d" % slot, 0))):
			var element := int(digit)
			if element > 0 and element not in result: result.append(element)
	result.sort()
	if result.is_empty(): result.append(0)
	return result
