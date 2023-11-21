extends Node2D


var stone = preload("res://resources/stone.tscn")


func _input(event):
	if event is InputEventMouseButton and event.is_pressed():
		
		var s = stone.instantiate()
		
		s.initialize(get_global_mouse_position())
		
		get_tree().current_scene.add_child(s)
