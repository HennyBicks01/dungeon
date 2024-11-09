extends Camera3D

@export var mouse_sensitivity = 0.05
@export var camera_speed = 20.0

var camera_rotation = Vector3.ZERO

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion:
		# Update camera rotation
		camera_rotation.y -= event.relative.x * mouse_sensitivity * 0.01
		camera_rotation.x -= event.relative.y * mouse_sensitivity * 0.01
		camera_rotation.x = clamp(camera_rotation.x, deg_to_rad(-90), deg_to_rad(90))
		
		# Apply rotation to camera
		rotation = camera_rotation
	
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	var input_dir = Vector3.ZERO
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.z = Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	input_dir.y = Input.get_action_strength("move_up") - Input.get_action_strength("move_down")
	
	# Transform input direction based on camera orientation
	var movement = global_transform.basis * input_dir.normalized() * camera_speed * delta
	global_translate(movement)
