extends Node
## Wave mutators + combo callouts (desktop overlay; CanvasLayer is not shown in the headset).

const MUTATORS := {
	"moon":      {"name": "МЪНЕНА ГРАВИТАЦИЯ", "gravity": 0.05},
	"bighead":   {"name": "ГОЛЕМИ ГЛАВИ",      "enemy_scale": 1.6},
	"fast":      {"name": "ДВОЙНА СКОРОСТ",    "enemy_speed": 2.0},
	"tiny":      {"name": "МИНИ НАШЕСТВЕНИЦИ", "enemy_scale": 0.6},
	"wind":      {"name": "ВЯТЪР!",            "wind": Vector3(8.0, 0, 0)},
}

var current: Dictionary = {}
var pinned := ""   # "" = random each wave, "none" = off, else a mutator key
var current_key := ""
var last_wave := 1
var enabled := DisplayServer.get_name() != "headless"
const NOT_WIRED_YET := []
var combo := 0
var _combo_timer := 0.0
var _banner: Label
var _callout: Label

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_banner = _make_label(layer, 64, Vector2(0, 40))
	_callout = _make_label(layer, 96, Vector2(0, 200))
	if enabled:
		_build_panel()

func _make_label(parent: Node, size: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.position = pos
	l.modulate.a = 0.0
	parent.add_child(l)
	return l

func roll(wave: int) -> void:
	if not enabled: return
	last_wave = wave
	if pinned == "none":
		current = {}
		current_key = ""
		_refresh()
		return
	var pool := MUTATORS.keys().filter(func(k): return not NOT_WIRED_YET.has(k))
	var key: String = pinned if pinned != "" else pool.pick_random()
	current = MUTATORS[key]
	current_key = key
	_show(_banner, "Вълна %d: %s" % [wave, current.name], 2.5)
	_refresh()

func clear() -> void:
	current = {}
	combo = 0

func mod(key: String, default: Variant) -> Variant:
	return current.get(key, default) if enabled else default

func on_hit() -> void:
	if not enabled: return
	combo += 1
	_combo_timer = 2.0
	if combo >= 3:
		_show(_callout, "%dx ПЯНА!" % combo, 0.8)
		_callout.pivot_offset = _callout.size / 2
		_callout.scale = Vector2.ONE * 1.5
		create_tween().tween_property(_callout, "scale", Vector2.ONE, 0.2)

func break_combo() -> void:
	combo = 0

func _process(delta: float) -> void:
	if combo > 0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			combo = 0

func _show(label: Label, text: String, secs: float) -> void:
	label.text = text
	label.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(secs)
	t.tween_property(label, "modulate:a", 0.0, 0.4)

var _panel: PanelContainer
var _status: Label
var _keys: Array = []

func _label_for(k: String) -> String:
	if k == "random": return "Случаен всяка вълна"
	if k == "none": return "Без мутатор"
	return MUTATORS[k].name

func _build_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 101
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.position = Vector2(20, 260)
	_panel.visible = false
	layer.add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	var title := Label.new()
	title.text = "DEBUG   (F12 затваря, клавиши 0-%d)" % (MUTATORS.size() + 1)
	box.add_child(title)
	_status = Label.new()
	box.add_child(_status)
	_keys = ["random", "none"] + MUTATORS.keys()
	for i in _keys.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = "%d   %s" % [i, _label_for(_keys[i])]
		b.pressed.connect(_pick.bind(_keys[i]))
		box.add_child(b)
	var hit := Button.new()
	hit.focus_mode = Control.FOCUS_NONE
	hit.text = "F2   +1 комбо"
	hit.pressed.connect(on_hit)
	box.add_child(hit)
	_refresh()

func _pick(k: String) -> void:
	if k == "random":
		pinned = ""
		roll(last_wave)
	elif k == "none":
		pinned = "none"
		current = {}
		current_key = ""
		_show(_banner, "БЕЗ МУТАТОР", 1.5)
	else:
		pinned = k
		current = MUTATORS[k]
		current_key = k
		_show(_banner, "Вълна %d: %s" % [last_wave, current.name], 2.5)
	_refresh()

func _refresh() -> void:
	if _status == null: return
	var mode := "случаен" if pinned == "" else _label_for(pinned)
	_status.text = "Режим: %s\nАктивен: %s" % [mode, current.get("name", "-")]

func _input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo or _panel == null:
		return
	if k.keycode == KEY_F12:
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_F1:
		roll(last_wave)
	elif k.keycode == KEY_F2:
		on_hit()
	elif _panel.visible and k.keycode >= KEY_0 and k.keycode < KEY_0 + _keys.size():
		_pick(_keys[k.keycode - KEY_0])
		get_viewport().set_input_as_handled()
