extends Node3D

class_name Room

# Cost of this room type
@export var room_cost: int = 10
# The size of the room in xyz dimensions
@export var room_size: Vector3 = Vector3(10.0, 5.0, 10.0)

# Array of door data
var doors: Array[DoorData] = []
# Position in the dungeon grid
var grid_position: Vector3i
# Reference to connected rooms
var connected_rooms: Dictionary = {}

func _ready():
	find_doors()

func find_doors():
	# Clear existing doors array
	doors.clear()
	# Look for door nodes in the scene
	for child in get_children():
		find_doors_recursive(child)
	
	if doors.is_empty():
		push_warning("No doors found in room: " + name)

func find_doors_recursive(node: Node):
	if node.name.begins_with("Door"):
		# Create door data for this node
		var door_data = DoorData.new(node)
		doors.append(door_data)
	
	# Continue searching children
	for child in node.get_children():
		find_doors_recursive(child)

func get_room_size() -> Vector3:
	return room_size

func connect_room(other_room: Room, my_door_index: int, other_door_index: int):
	connected_rooms[my_door_index] = {
		"room": other_room,
		"door": other_door_index
	}

# Inner class for Door data
class DoorData:
	var node: Node3D
	var direction: Vector3
	var center: Vector3
	
	func _init(door_node: Node3D):
		node = door_node
		center = door_node.global_position
		# Determine direction based on position in room
		var pos = door_node.position
		var max_coord = max(abs(pos.x), abs(pos.z))
		
		if abs(pos.x) == max_coord:
			# Door is on east/west wall
			direction = Vector3.RIGHT if pos.x > 0 else Vector3.LEFT
		else:
			# Door is on north/south wall
			direction = Vector3.BACK if pos.z > 0 else Vector3.FORWARD
