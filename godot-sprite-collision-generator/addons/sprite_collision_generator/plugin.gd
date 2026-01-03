@tool
extends EditorPlugin

var dock_scene: Control
var collision_generator: Node

func _enter_tree():
	# Load the CollisionGenerator script
	var generator_script = load("res://addons/sprite_collision_generator/collision_generator.gd")
	collision_generator = generator_script.new()
	add_child(collision_generator)

	print("CollisionGenerator created: ", collision_generator)

	dock_scene = preload("res://addons/sprite_collision_generator/collision_dock.tscn").instantiate()
	dock_scene.collision_generator = collision_generator
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock_scene)

	print("Sprite Collision Generator plugin enabled")
	print("Dock scene collision_generator: ", dock_scene.collision_generator)

func _exit_tree():
	if dock_scene:
		remove_control_from_docks(dock_scene)
		dock_scene.queue_free()

	if collision_generator:
		collision_generator.queue_free()

	print("Sprite Collision Generator plugin disabled")
