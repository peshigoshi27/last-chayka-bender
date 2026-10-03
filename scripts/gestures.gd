extends RefCounted
## Spatial gestures operate in XR-origin metres. No controller input.
## Pumping uses only right-hand height; palm orientation and left hand are irrelevant.
const STROKE_DISTANCE := 0.04

const TIP := [10, 15, 20, 25]
const BASE := [7, 12, 17, 22]
const MID := [8, 13, 18, 23]
var last_projection := 0.0
var extreme := 0.0
var direction := 0
var active := false
var stroke_age := 0.0
var half_strokes := 0
var cycle_age := 0.0
var middle_hold := 0.0
var middle_latched := false
var clap_armed := false
var clap_cooldown := 0.0
var pinch_latch := [false, false]

static func classify(points: Array, palm_basis: Basis = Basis.IDENTITY) -> Dictionary:
	if points.size() != 26:
		return {"valid": false}
	var extended: Array[bool] = []
	for f in range(4):
		var a: Vector3 = points[MID[f]] - points[BASE[f]]
		var b: Vector3 = points[TIP[f]] - points[MID[f]]
		var straight: bool = a.normalized().dot(b.normalized()) > 0.62
		var reaches: bool = points[TIP[f]].distance_to(points[1]) > points[MID[f]].distance_to(points[1]) + 0.012
		extended.append(straight and reaches)
	var reach: Vector3 = points[12] - points[1]
	if reach.length() < 0.025:
		return {"valid": false}
	var aim: Vector3 = palm_basis.y.normalized()
	if aim.dot(reach.normalized()) < 0.5:
		aim = reach.normalized()
	return {"valid": true, "palm": points[0], "wrist": points[1],
		"axis": aim, "normal": palm_basis.z.normalized(),
		"fist": extended.count(false) >= 3 and not extended[1],
		"open": extended[0] and extended[1] and extended[2] and extended[3],
		"middle": not extended[0] and extended[1] and not extended[2] and not extended[3],
		"pinch_distance": points[5].distance_to(points[10]), "points": points}

func reset_motion() -> void:
	active = false
	direction = 0
	stroke_age = 0.0
	half_strokes = 0
	cycle_age = 0.0
	middle_hold = 0.0
	middle_latched = false
	clap_armed = false
	pinch_latch = [false, false]

func update(left: Dictionary, right: Dictionary, delta: float) -> Dictionary:
	var result := {"stroke": false, "taunt": false, "clap": false, "shield": false,
		"pinch_left": false, "pinch_right": false, "pinching": false, "stroke_interval": 0.0}
	clap_cooldown = maxf(0.0, clap_cooldown - delta)
	stroke_age += delta
	cycle_age += delta
	if not right.get("valid", false):
		reset_motion()
		return result
	var hands: Array = [left, right]
	var hold: Dictionary = right
	var scrub: Dictionary = left
	for h in range(2):
		if not hands[h].get("valid", false):
			pinch_latch[h] = false
			continue
		var d: float = hands[h].get("pinch_distance", 1.0)
		if d < 0.025 and not pinch_latch[h]:
			result["pinch_left" if h == 0 else "pinch_right"] = true
			pinch_latch[h] = true
		elif d > 0.040:
			pinch_latch[h] = false
	result.pinching = pinch_latch[1]
	var projected: float = right.palm.y
	var gripping: bool = right.get("fist", false) and not right.get("middle", false)
	if gripping:
		if not active:
			active = true
			extreme = projected
			last_projection = projected
			direction = 0
			cycle_age = 0.0
		elif absf(projected - last_projection) > 0.12:
			# Tracking teleports must start a fresh trajectory.
			extreme = projected
			direction = 0
			stroke_age = 0.0
			half_strokes = 0
			cycle_age = 0.0
		else:
			var movement: float = projected - extreme
			if direction == 0 and absf(movement) >= STROKE_DISTANCE:
				direction = 1 if movement > 0 else -1
				extreme = projected
				if stroke_age >= 0.12:
					result.stroke = true
					result.stroke_interval = stroke_age
					stroke_age = 0.0
			elif direction != 0:
				if movement * direction > 0:
					extreme = projected
				elif absf(movement) >= STROKE_DISTANCE:
					if stroke_age >= 0.12:
						result.stroke = true
						result.stroke_interval = stroke_age
						stroke_age = 0.0
					direction *= -1
					extreme = projected
		last_projection = projected
	else:
		active = false
		direction = 0
		half_strokes = 0
		cycle_age = 0.0
	if result.stroke:
		half_strokes += 1
		result.stroke = half_strokes >= 2
		if result.stroke:
			result.stroke_interval = cycle_age
			half_strokes = 0
			cycle_age = 0.0
	var middle: bool = left.get("valid", false) and left.get("middle", false) or right.get("middle", false)
	if middle:
		middle_hold += delta
		if middle_hold >= 0.45 and not middle_latched:
			result.taunt = true
			middle_latched = true
	else:
		middle_hold = 0.0
		middle_latched = false
	result.shield = scrub.get("valid", false) and scrub.get("open", false) and not hold.get("open", false)
	if not left.get("valid", false):
		clap_armed = false
		return result
	var distance: float = left.palm.distance_to(right.palm)
	if left.open and right.open:
		if distance > 0.35:
			clap_armed = true
		elif distance < 0.13 and clap_armed and clap_cooldown <= 0.0:
			result.clap = true
			clap_armed = false
			clap_cooldown = 1.0
	else:
		clap_armed = false
	return result
