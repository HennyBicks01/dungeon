extends Node3D

class_name DungeonGenerator

# Array of room scene paths
@export var room_scenes: Array[PackedScene] = []
# Total cost budget for the dungeon
@export var total_cost_budget: int = 100
# Minimum number of rooms (optional safety check)
@export var min_rooms: int = 2

# Dictionary to store rooms by their grid position
var rooms: Dictionary = {}
# Array to store available doors
var available_doors: Array = []
# Current total cost
var current_cost: int = 0

func _ready():
	generate_dungeon()

func generate_dungeon():
	print("\nStarting dungeon generation...")
	# Start with the first room at the center
	var start_room = spawn_random_room(Vector3i.ZERO)
	current_cost += start_room.room_cost
	rooms[Vector3i.ZERO] = start_room
	update_available_doors(start_room)
	print("Spawned start room with %s doors. Available doors: %s" % [start_room.doors.size(), available_doors.size()])
	
	# Keep generating rooms until we run out of budget or doors
	while current_cost < total_cost_budget and not available_doors.is_empty():
		# Pick a random available door
		var door_info = available_doors.pick_random()
		var current_room = door_info["room"]
		var door_index = door_info["door_index"]
		
		print("\nTrying to spawn room from door %s of room at %s" % [door_index, current_room.grid_position])
		print("Current cost: %s/%s" % [current_cost, total_cost_budget])
		
		# Try to spawn a new room that fits our budget
		var success = try_spawn_connected_room(current_room, door_index)
		print("Spawn attempt %s" % ["succeeded" if success else "failed"])
		
		# Remove the used door regardless of success
		available_doors.erase(door_info)
		print("Remaining available doors: %s" % available_doors.size())
		
		# Break if we have at least minimum rooms
		if rooms.size() >= min_rooms:
			print("Reached minimum room count")
			break

func try_spawn_connected_room(current_room: Room, door_index: int) -> bool:
	var door_data = current_room.doors[door_index]
	print("Trying to connect from door at %s facing %s" % [door_data.center, door_data.direction])
	var door_position = door_data.center
	var door_direction = door_data.direction
	
	# Try each room type until we find one that fits our budget
	var valid_scenes = room_scenes.duplicate()
	while not valid_scenes.is_empty():
		var room_scene = valid_scenes.pick_random()
		var test_room = room_scene.instantiate() as Room
		add_child(test_room)
		test_room.find_doors()
		
		# Check if we can afford this room
		if current_cost + test_room.room_cost > total_cost_budget:
			print("Can't afford room (cost: %s)" % test_room.room_cost)
			test_room.queue_free()
			valid_scenes.erase(room_scene)
			continue
		
		print("Testing room with %s doors" % test_room.doors.size())
		# Find a suitable door in the new room
		for new_door_index in test_room.doors.size():
			var new_door = test_room.doors[new_door_index]
			print("Testing door %s at %s facing %s" % [new_door_index, new_door.center, new_door.direction])
			
			# First, reset the room's rotation
			test_room.rotation = Vector3.ZERO
			
			# Calculate rotation needed to face doors opposite each other
			# We want new_door to face the opposite direction of door_direction
			var target_direction = -door_direction
			var current_direction = new_door.direction
			var angle = atan2(target_direction.x, target_direction.z) - atan2(current_direction.x, current_direction.z)
			
			# Apply rotation
			test_room.rotate_y(angle)
			
			# Update door position after rotation
			test_room.find_doors() # Refresh door positions after rotation
			new_door = test_room.doors[new_door_index] # Get updated door data
			
			# Calculate the offset needed to align doors
			# We want new_door.center to match door_position
			var offset = door_position - new_door.center
			test_room.global_position = offset
			
			var grid_pos = get_grid_position(test_room.global_position)
			print("Testing position %s" % grid_pos)
			
			# Check if position is available
			if not rooms.has(grid_pos):
				print("Position available, placing room")
				test_room.grid_position = grid_pos
				rooms[grid_pos] = test_room
				current_cost += test_room.room_cost
				
				# Connect rooms
				connect_rooms(current_room, test_room, door_index)
				update_available_doors(test_room)
				return true
			
			print("Position occupied, trying next door")
		
		# If no doors worked, remove and free the room
		remove_child(test_room)
		test_room.queue_free()
		valid_scenes.erase(room_scene)
	
	print("No valid room placement found")
	return false

func spawn_random_room(grid_pos: Vector3i) -> Room:
	print("\nSpawning new room...")
	var room_scene = room_scenes.pick_random()
	var room_instance = room_scene.instantiate() as Room
	add_child(room_instance)
	room_instance.grid_position = grid_pos
	room_instance.position = Vector3(grid_pos)
	
	# Find doors immediately after spawning
	room_instance.find_doors()
	print("Room spawned with %d doors" % room_instance.doors.size())
	for i in room_instance.doors.size():
		var door = room_instance.doors[i]
		print("Door %d position: %s direction: %s" % [i, door.center, door.direction])
	
	return room_instance

func connect_rooms(room1: Room, room2: Room, door1_index: int):
	# Find the door in room2 that's closest to and facing room1's door
	var door1 = room1.doors[door1_index]
	var door1_pos = door1.center
	var door1_dir = door1.direction
	var closest_door_index = -1
	var closest_distance = INF
	
	for i in room2.doors.size():
		if room2.connected_rooms.has(i):
			continue
		var door2 = room2.doors[i]
		var door2_pos = door2.center
		var door2_dir = door2.direction
		var distance = door1_pos.distance_to(door2_pos)
		
		# Check if doors are facing opposite directions (within a tolerance)
		if door1_dir.dot(-door2_dir) > 0.9 and distance < closest_distance:
			closest_distance = distance
			closest_door_index = i
	
	if closest_door_index != -1:
		room1.connect_room(room2, door1_index, closest_door_index)
		room2.connect_room(room1, closest_door_index, door1_index)

func update_available_doors(room: Room):
	var new_doors = 0
	for i in room.doors.size():
		if not room.connected_rooms.has(i):
			available_doors.append({
				"room": room,
				"door_index": i
			})
			new_doors += 1

func get_grid_position(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		round(world_pos.x),
		round(world_pos.y),
		round(world_pos.z)
	)
