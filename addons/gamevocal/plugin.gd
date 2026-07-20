@tool
extends EditorPlugin

var dock: Control

func _enter_tree():
	# Initialization of the plugin goes here.
	dock = preload("res://addons/gamevocal/ui/gamevocal_dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)

func _exit_tree():
	# Clean-up of the plugin goes here.
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
