extends SceneTree

func _init() -> void:
	run.call_deferred()

func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.save_scores = false
	main.start_game()
	main.rules.spawn_clock = 999
	main.rules.remaining_spawns = 99
	main.rules.set_aim(Vector3(0,1.5,0),Vector3(0,0.1,-1).normalized())
	for n in range(10):
		main.rules.stroke(1.0)
	for n in range(75):
		main.rules.tick(1.0/90)
	main._sync_game(0.0)
	main.toast_label.text = ""
	main.tracking_label.text = ""
	main.camera.position = Vector3(3.6,2.6,-0.6)
	main.camera.look_at(Vector3(0,0.9,-2.9))
	main.camera.fov = 65
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/liquid-stream.png")
	main.queue_free()
	await process_frame
	quit()
