extends CharacterBody3D

const GRAVITY: float = -1
var vel: Vector3 = Vector3()
const MAX_SPEED: float = 5
const ACCEL: float = 4.5

var dir: Vector3 = Vector3()

const DEACCEL: float = 16
const MAX_SLOPE_ANGLE: float = 40

var camera: Camera3D
var rotation_helper: Node3D

var MOUSE_SENSITIVITY: float = 0.05
const ZOOMED_FOV: float = 40
const ZOOM_SPEED: float = 200
var DEFAULT_FOV: float

func _ready() -> void:
	camera = $RotationHelper/Camera3D
	rotation_helper = $RotationHelper
	DEFAULT_FOV = camera.fov

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	process_input(delta)
	process_movement(delta)

func process_input(delta: float) -> void:
	dir = Vector3()
	var cam_xform = camera.get_global_transform()

	var input_movement_vector = Vector2()

	if Input.is_action_pressed("movement_forward"):
		input_movement_vector.y += 1
		print("we goin forward")
	if Input.is_action_pressed("movement_backward"):
		input_movement_vector.y -= 1
		print("we goin back")
	if Input.is_action_pressed("movement_left"):
		input_movement_vector.x -= 1
	if Input.is_action_pressed("movement_right"):
		input_movement_vector.x += 1

	if Input.is_action_pressed("aim_weapon") and camera.fov > ZOOMED_FOV:
		camera.fov -= ZOOM_SPEED * delta
	if !Input.is_action_pressed("aim_weapon") and camera.fov < DEFAULT_FOV:
		camera.fov += ZOOM_SPEED * delta

	input_movement_vector = input_movement_vector.normalized()

	dir += -cam_xform.basis.z * input_movement_vector.y
	dir += cam_xform.basis.x * input_movement_vector.x

	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func process_movement(delta: float) -> void:
	dir.y = 0
	dir = dir.normalized()

	vel.y += delta * GRAVITY

	var hvel: Vector3 = vel
	hvel.y = 0

	var target: Vector3 = dir
	target *= MAX_SPEED

	var accel: float
	if dir.dot(hvel) > 0:
		accel = ACCEL
	else:
		accel = DEACCEL

	hvel = hvel.lerp(target, accel * delta)
	vel.x = hvel.x
	vel.z = hvel.z
	velocity = vel
	print(velocity)
	move_and_slide()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_helper.rotate_x(deg_to_rad(-event.relative.y * MOUSE_SENSITIVITY))
		self.rotate_y(deg_to_rad(-event.relative.x * MOUSE_SENSITIVITY))
		var camera_rot: Vector3 = rotation_helper.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -70, 70)
		rotation_helper.rotation_degrees = camera_rot
