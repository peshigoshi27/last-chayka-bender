extends RefCounted
## Desktop stand-in for OpenXR hand tracking (run with `-- --play`).
## Mouse + keyboard drive synthetic 26-joint hands that go through the same
## Gestures.classify() path as real tracked hands, so all game logic is unchanged.
##
##   Mouse           aim the stream / point at menu buttons
##   Left click     pinch (menu buttons, pause button after hovering 0.75 s)
##   Space           one pump cycle (hold to keep pumping)
##   F or Right btn  open left palm = shield
##   C               clap = blast (needs 55 foam)
##   T (hold)        middle finger taunt
const Gestures = preload("res://scripts/gestures.gd")
const PUMP_TIME := 0.55
const PUMP_HEIGHT := 0.10
const CLAP_TIME := 0.55
const TARGET_DISTANCE := 6.0
const RIGHT_REST := Vector3(0.22, 1.20, -0.55)
const LEFT_REST := Vector3(-0.24, 1.22, -0.58)

var pump_t := -1.0
var clap_t := -1.0

func update(delta: float, camera: Camera3D, viewport: Viewport) -> Array[Dictionary]:
	var mouse: Vector2 = viewport.get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse)
	var ray_dir: Vector3 = camera.project_ray_normal(mouse)

	# Pump: a smooth up-and-down bump of the right fist (one full cycle = one stroke).
	if pump_t >= 0.0:
		pump_t += delta
		if pump_t >= PUMP_TIME:
			pump_t = -1.0
	if pump_t < 0.0 and Input.is_key_pressed(KEY_SPACE):
		pump_t = 0.0
	var lift: float = 0.0
	if pump_t >= 0.0:
		lift = PUMP_HEIGHT * 0.5 * (1.0 - cos(TAU * pump_t / PUMP_TIME))

	# Clap: both open palms start apart (arms the detector), then meet.
	if clap_t >= 0.0:
		clap_t += delta
		if clap_t >= CLAP_TIME:
			clap_t = -1.0
	if clap_t < 0.0 and Input.is_key_pressed(KEY_C):
		clap_t = 0.0
	var clapping: bool = clap_t >= 0.0
	var meet: float = clampf((clap_t - 0.2) / 0.15, 0.0, 1.0)

	var shield: bool = Input.is_key_pressed(KEY_F) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var taunt: bool = Input.is_key_pressed(KEY_T)
	var pinch: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	# Right hand: rests low-right, fist, tilted so the stream converges on the cursor.
	var right_pos: Vector3 = RIGHT_REST + Vector3(0, lift, 0)
	var right_axis: Vector3 = (ray_origin + ray_dir * TARGET_DISTANCE - right_pos).normalized()
	var right_fingers: Array = [false, false, false, false]
	if clapping:
		right_fingers = [true, true, true, true]
		right_pos = Vector3(lerpf(0.30, 0.03, meet), 1.20, -0.58)
		right_axis = Vector3(0, 0, -1)
	var right: Dictionary = _hand(1, right_pos, right_axis, right_fingers, pinch and not clapping)
	# Menus and the pause button use an exact camera ray so the pointer lands under the cursor.
	right["ray_origin"] = ray_origin
	right["ray_direction"] = ray_dir

	# Left hand only exists while a gesture needs it.
	var left: Dictionary = {"valid": false}
	if clapping:
		left = _hand(0, Vector3(lerpf(-0.30, -0.03, meet), 1.20, -0.58), Vector3(0, 0, -1), [true, true, true, true], false)
	elif shield:
		left = _hand(0, LEFT_REST, Vector3(0, 0, -1), [true, true, true, true], false)
	elif taunt:
		left = _hand(0, LEFT_REST, Vector3(0, 0, -1), [false, true, false, false], false)
	if left.get("valid", false):
		left["ray_origin"] = left.palm
		left["ray_direction"] = left.axis
	var output: Array[Dictionary] = [left, right]
	return output

## Builds one synthetic hand. `extended` = [index, middle, ring, little].
func _hand(h: int, p: Vector3, axis: Vector3, extended: Array, pinch: bool) -> Dictionary:
	var y: Vector3 = axis.normalized()
	var up: Vector3 = Vector3.UP
	if absf(y.dot(up)) > 0.95:
		up = Vector3(0, 0, 1)
	var z: Vector3 = (up - y * up.dot(y)).normalized()
	var x: Vector3 = y.cross(z)
	var palm_basis := Basis(x, y, z)
	var sign_x: float = 1.0 if h == 0 else -1.0
	var points: Array = []
	points.resize(26)
	points.fill(p)
	points[1] = p + palm_basis * Vector3(0, -0.042, 0)
	for j in range(2, 6):
		points[j] = p + palm_basis * Vector3(sign_x * (0.025 + (j - 2) * 0.009), -0.026 + (j - 2) * 0.015, 0.009)
	for finger in range(4):
		var fx: float = (finger - 1.5) * 0.019 * sign_x
		var first: int = 6 + finger * 5
		points[first] = p + palm_basis * Vector3(fx, -0.012, 0)
		points[first + 1] = p + palm_basis * Vector3(fx, 0.029, 0)
		if extended[finger]:
			points[first + 2] = p + palm_basis * Vector3(fx, 0.062, 0)
			points[first + 3] = p + palm_basis * Vector3(fx, 0.083, 0)
			points[first + 4] = p + palm_basis * Vector3(fx, 0.100, 0)
		else:
			points[first + 2] = p + palm_basis * Vector3(fx, 0.056, 0.004)
			points[first + 3] = p + palm_basis * Vector3(fx, 0.050, 0.026)
			points[first + 4] = p + palm_basis * Vector3(fx, 0.024, 0.030)
	if pinch:
		points[5] = points[10] + palm_basis * Vector3(0.004, 0, 0)
	var data: Dictionary = Gestures.classify(points, palm_basis)
	data["basis"] = palm_basis
	return data
