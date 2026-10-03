extends Node3D
const Gestures = preload("res://scripts/gestures.gd")
const Art = preload("res://scripts/art.gd")
const LINKS := [[1,2],[2,3],[3,4],[4,5],[1,6],[6,7],[7,8],[8,9],[9,10],
	[1,11],[11,12],[12,13],[13,14],[14,15],[1,16],[16,17],[17,18],[18,19],[19,20],
	[1,21],[21,22],[22,23],[23,24],[24,25]]
var origin: XROrigin3D
var clouds: Array[MultiMeshInstance3D] = []
var bones: Array[MultiMeshInstance3D] = []
var palms: Array[MeshInstance3D] = []
var samples: Array[Dictionary] = [{"valid":false},{"valid":false}]

func _ready() -> void:
	for h in range(2):
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 1.0
		cylinder.bottom_radius = 1.0
		cylinder.height = 1.0
		cylinder.radial_segments = 7
		clouds.append(make_batch(sphere, 26, Art.YELLOW))
		bones.append(make_batch(cylinder, LINKS.size(), Color("e8c850")))
		var palm := Art.box(self, Vector3(0.073,0.084,0.032),Vector3.ZERO,Art.YELLOW)
		palms.append(palm)

func make_batch(mesh: Mesh, count: int, color: Color) -> MultiMeshInstance3D:
	var visual := MultiMeshInstance3D.new()
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = count
	visual.multimesh = batch
	visual.material_override = Art.material(color)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	return visual

func sample() -> Array[Dictionary]:
	for h in range(2):
		samples[h] = sample_hand(h)
		visualize(h, samples[h])
	return samples

func sample_hand(h: int) -> Dictionary:
	var side := "left" if h == 0 else "right"
	var tracker: XRHandTracker = XRServer.get_tracker("/user/hand_tracker/" + side) as XRHandTracker
	if tracker == null or not tracker.has_tracking_data or tracker.hand_tracking_source == XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER:
		return {"valid":false}
	var flags: int = tracker.get_hand_joint_flags(XRHandTracker.HAND_JOINT_PALM)
	if (flags & XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED) == 0:
		return {"valid":false}
	var world: Transform3D = origin.global_transform * XRServer.get_reference_frame()
	var points: Array = []
	for j in range(26):
		if (tracker.get_hand_joint_flags(j) & XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID) == 0:
			return {"valid":false}
		var p: Vector3 = world * tracker.get_hand_joint_transform(j).origin
		if not p.is_finite() or p.length() > 1000:
			return {"valid":false}
		points.append(p)
	var palm: Transform3D = world * tracker.get_hand_joint_transform(0)
	var data: Dictionary = Gestures.classify(points, palm.basis)
	data["basis"] = palm.basis
	var aim_tracker: XRPositionalTracker = XRServer.get_tracker("/user/fbhandaim/"+side) as XRPositionalTracker
	if aim_tracker:
		var pose := aim_tracker.get_pose("default")
		if pose and pose.has_tracking_data:
			var aim: Transform3D = world * pose.transform
			data["ray_origin"] = aim.origin
			data["ray_direction"] = -aim.basis.z
	if not data.has("ray_origin") and data.get("valid", false):
		data["ray_origin"] = points[0]
		data["ray_direction"] = data.axis
	return data

func visualize(h: int, data: Dictionary) -> void:
	var valid: bool = data.get("valid", false)
	clouds[h].visible = valid
	bones[h].visible = valid
	palms[h].visible = valid
	if not valid:
		return
	var points: Array = data.points
	for j in range(26):
		var radius := 0.010 if j > 1 else 0.015
		clouds[h].multimesh.set_instance_transform(j, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*radius), points[j]))
	for k in range(LINKS.size()):
		var a: Vector3 = points[LINKS[k][0]]
		var b: Vector3 = points[LINKS[k][1]]
		var diff := b-a
		var basis := Basis(Quaternion(Vector3.UP, diff.normalized())) if diff.length() > 0.001 else Basis.IDENTITY
		bones[h].multimesh.set_instance_transform(k, Transform3D(basis.scaled(Vector3(0.009,maxf(diff.length(),0.001),0.009)),(a+b)/2))
	palms[h].transform = Transform3D(data.get("basis", Basis.IDENTITY), data.palm)
