extends SceneTree
const Enemy = preload("res://scripts/enemy_model.gd")
const Art = preload("res://scripts/art.gd")
var stage: Node3D
var camera: Camera3D

func _init() -> void:
	run.call_deferred()

func run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	root.size = Vector2i(1440,900)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("14262d")
	stage.add_child(world)
	Art.box(stage,Vector3(20,0.05,20),Vector3(0,-0.04,0),Color("688376"))
	for type in range(3):
		var model := Enemy.new()
		stage.add_child(model)
		model.setup(type)
		model.position.x = (type-1)*1.75
		model.rotation.y = -0.25 if type==1 else 0.0
		model.animate(0.2,false,0.0)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(2.7,2.5,6.2)
	camera.look_at(Vector3(0,0.8,0))
	camera.current = true
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/enemies-3d.png")
	stage.queue_free()
	await process_frame
	Enemy.cache.clear()
	quit()
