extends Node

## Exposed and safe to use methods for Dialogic
## See documentation here:
## https://github.com/coppolaemilio/dialogic

## ### /!\ ###
## Do not use methods from other classes as it could break the plugin's integrity
## ### /!\ ###
##
## Trying to follow this documentation convention: https://github.com/godotengine/godot/pull/41095
class_name Dialogic


## Adds the dialogic node as a child of the given node
## The parent node must be of type control
## To start the timeline, use the start method from the returned node
##
## @param parent				The parent to add the dialogic node to.
## @param dialog_scene_path		If you made a custom Dialog scene or moved it from its default path, you can specify its new path here.
## @returns						The Dialog node or null if the parent was invalid.
static func add_as_child_of(parent: Node, dialog_scene_path: String="res://addons/dialogic/Dialog.tscn") -> DialogicNode:
	if parent is Control:
		var dialog_node = get_instance(dialog_scene_path)
		parent.add_child(dialog_node)
		return dialog_node
	else:
		printerr("[Dialogic] Node's parent should be a Control")
		return null

## Adds the dialogic node as a child of the given node, and below the given node
## The parent node must be of type control
## To start the timeline, use the start method from the returned node
##
## @param parent				The parent to add the dialogic node to.
## @param node					The node to add dialogic below.
## @param dialog_scene_path		If you made a custom Dialog scene or moved it from its default path, you can specify its new path here.
## @returns						The Dialog node or null if the parent was invalid.
static func add_as_child_of_below_node(parent: Node, node: Node, dialog_scene_path: String="res://addons/dialogic/Dialog.tscn") -> DialogicNode:
	if parent is Control:
		var dialog_node = get_instance(dialog_scene_path)
		parent.add_child_below_node(node, dialog_node)
		return dialog_node
	else:
		printerr("[Dialogic] Node's parent should be a Control")
		return null


## Gets a DialogicNode instance to be added to the tree
## This instance can then be added to the tree using add_child()
## To start the timeline, use the start method from the returned node
##
## @param dialog_scene_path		If you made a custom Dialog scene or moved it from its default path, you can specify its new path here.
## @returns						A Dialog node to be added into the scene tree.
static func get_instance(dialog_scene_path: String="res://addons/dialogic/Dialog.tscn") -> DialogicNode:
	var dialog : = load(dialog_scene_path)
	return dialog.instance()


## Gets default values for definitions.
## 
## @returns						Dictionary in the format {'variables': [], 'glossary': []}
static func get_default_definitions() -> Dictionary:
	return DialogicSingleton.get_default_definitions()


## Gets currently saved values for definitions.
## 
## @returns						Dictionary in the format {'variables': [], 'glossary': []}
static func get_definitions() -> Dictionary:
	return DialogicSingleton.get_definitions()


## Save current definitions to the filesystem.
## Definitions are automatically saved on timeline start/end
## 
## @returns						Error status, OK if all went well
static func save_definitions():
	return DialogicSingleton.save_definitions()


## Resets data to default values. This is the same as calling start with reset_saves to true
static func reset_saves():
	DialogicSingleton.init(true)


## Gets the value for the variable with the given name.
## The returned value is a String but can be easily converted into a number 
## using Godot built-in methods: 
## [`is_valid_float`](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string-method-is-valid-float)
## [`float()`](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float-method-float).
##
## @param name					The name of the variable to find.
## @returns						The variable's value as string, or an empty string if not found.
static func get_variable(name: String) -> String:
	return DialogicSingleton.get_variable(name)


## Sets the value for the variable with the given name.
## The given value will be converted to string using the 
## [`str()`](https://docs.godotengine.org/en/stable/classes/class_string.html) function.
##
## @param name					The name of the variable to edit.
## @param value					The value to set the variable to.
static func set_variable(name: String, value) -> void:
	DialogicSingleton.set_variable(name, value)


## Gets the glossary data for the definition with the given name.
## Returned format:
## { title': '', 'text' : '', 'extra': '' }
##
## @param name					The name of the glossary to find.
## @returns						The glossary data as a Dictionary.
## 								A structure with empty strings is returned if the glossary was not found. 
static func get_glossary(name: String) -> Dictionary:
	return DialogicSingleton.get_glossary(name)


## Sets the data for the glossary of the given name.
## 
## @param name					The name of the glossary to edit.
## @param title					The title to show in the information box.
## @param text					The text to show in the information box.
## @param extra					The extra information at the bottom of the box.
static func set_glossary(name: String, title: String, text: String, extra: String) -> void:
	DialogicSingleton.set_glossary(name, title, text, extra)


## Gets the currently saved timeline.
## Timeline saves are set on timeline start, and cleared on end.
## This means you can keep track of timeline changes and detect when the dialog ends.
##
## @returns						The current timeline filename, or an empty string if none was saved.
static func get_current_timeline() -> String:
	return DialogicSingleton.get_current_timeline()


## ************************************************************
## 					DEPRECATED FUNCTIONS
##		These functions will be removed in future versions
##					Use at your own risk
## ************************************************************


## /!\ DEPRECATED /!\
## Use get_instance() instead
##
## Starts the dialog for the given timeline and returns a Dialog node.
## You must then add it manually to the scene to display the dialog.
##
## Example:
## var new_dialog = Dialogic.start('Your Timeline Name Here')
## add_child(new_dialog)
##
## This is exactly the same as using the editor:
## you can drag and drop the scene located at /addons/dialogic/Dialog.tscn 
## and set the current timeline via the inspector.
##
## @param timeline				The timeline to load. You can provide the timeline name or the filename.
## @param reset_saves			True to reset dialogic saved data such as definitions.
## @param dialog_scene_path		If you made a custom Dialog scene or moved it from its default path, you can specify its new path here.
## @param debug_mode			Debug is disabled by default but can be enabled if needed.
## @returns						A Dialog node to be added into the scene tree.
static func start(timeline: String, reset_saves: bool=true, dialog_scene_path: String="res://addons/dialogic/Dialog.tscn", debug_mode: bool=false) -> DialogicNode:

	var dialog:  = load(dialog_scene_path)
	var d = dialog.instance()
	d.reset_saves = reset_saves
	d.debug_mode = debug_mode
	if not timeline.empty():
		for t in DialogicUtil.get_timeline_list():
			if t['name'] == timeline or t['file'] == timeline:
				d.timeline = t['file']
				return d
		d.dialog_script = {
			"events":[{"character":"","portrait":"",
			"text":"[Dialogic Error] Loading dialog [color=red]" + timeline + "[/color]. It seems like the timeline doesn't exists. Maybe the name is wrong?"}]
		}
	return d


## /!\ DEPRECATED /!\
## Use get_instance() instead
##
## Same as the start method above, but using the last timeline saved.
## 
## @param initial_timeline		The timeline to load in case no save is found.
## @param dialog_scene_path		If you made a custom Dialog scene or moved it from its default path, you can specify its new path here.
## @param debug_mode			Debug is disabled by default but can be enabled if needed.
## @returns						A Dialog node to be added into the scene tree.
static func start_from_save(initial_timeline: String, dialog_scene_path: String="res://addons/dialogic/Dialog.tscn", debug_mode: bool=false) -> DialogicNode:
	var current := get_current_timeline()
	if current.empty():
		current = initial_timeline
	return start(current, false, dialog_scene_path, debug_mode)
