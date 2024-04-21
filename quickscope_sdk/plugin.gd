@tool
extends EditorPlugin

const AUTOLOAD_NAME = "QuickScopeSDK"

func _enter_tree():
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/quickscope_sdk/quickscope_sdk.tscn")

func _exit_tree():
	remove_autoload_singleton(AUTOLOAD_NAME)
