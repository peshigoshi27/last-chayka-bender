extends Node
var pool: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var enabled := true
var next_voice := 0

func _exit_tree() -> void:
	for player in pool:
		player.stop()
		player.stream = null
	sounds.clear()

func _ready() -> void:
	for n in range(10):
		var player := AudioStreamPlayer.new()
		player.volume_db = -15
		add_child(player)
		pool.append(player)
	var specs := {"shoot":[740,210,0.13], "pump":[180,480,0.12], "hit":[1100,180,0.08],
		"kill":[520,900,0.20], "wave":[240,780,0.55], "taunt":[190,80,0.5],
		"block":[900,600,0.12], "clap":[240,40,0.38], "damage":[120,45,0.3],
		"menu":[330,660,0.45], "victory":[440,1100,0.85], "defeat":[350,60,0.85],
		"overheat":[1000,650,0.4], "cooled":[260,600,0.2], "intro_stroke":[280,420,0.12], "title":[110,440,1.5]}
	for key in specs:
		var s: Array = specs[key]
		sounds[key] = synth(s[0],s[1],s[2],key in ["shoot","clap","hit"])

func synth(start: float, finish: float, duration: float, noisy: bool) -> AudioStreamWAV:
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var count := int(duration * 22050)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase := 0.0
	var random := RandomNumberGenerator.new()
	random.seed = 531
	for n in range(count):
		var t := float(n)/count
		phase += TAU * lerpf(start,finish,t)/22050.0
		var envelope := minf(t*30,1.0)*pow(1.0-t,1.6)
		var value := (sin(phase)*0.65 + sin(phase*1.5)*0.15)
		if noisy:
			value += random.randf_range(-0.2,0.2)
		bytes.encode_s16(n*2,int(value*envelope*22000))
	wave.data = bytes
	return wave

func play(cue: String) -> void:
	if not enabled or not sounds.has(cue):
		return
	var player: AudioStreamPlayer = pool[next_voice % pool.size()]
	next_voice += 1
	player.stream = sounds[cue]
	player.play()
