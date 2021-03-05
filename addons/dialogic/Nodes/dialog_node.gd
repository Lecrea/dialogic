tool
extends Control

var last_mouse_mode = null
var debug_mode = true
var input_next: String = 'ui_accept'
var dialog_index: int = 0
var finished: bool = false
var text_speed = 0.02 # Higher = lower speed
var waiting_for_answer: bool = false
var waiting_for_input: bool = false
var glossary_visible: bool = false
var glossary

var current_theme

#export(String) var timeline: String # Timeline-var-replace

export(String, "TimelineDropdown") var timeline: String
signal dialogic_signal(value)

var dialog_resource
var characters


onready var ChoiceButton = load("res://addons/dialogic/Nodes/ChoiceButton.tscn")
onready var Portrait = load("res://addons/dialogic/Nodes/Portrait.tscn")
var dialog_script = {}
var questions #for keeping track of the questions answered

func _ready():
	
	# Loading the glossary
	glossary = DialogicUtil.load_glossary()
	
	# Checking if the dialog should read the code from a external file
	if timeline != '':
		dialog_script = set_current_dialog('/' + timeline + '.json')
	
	# Connecting resize signal
	get_viewport().connect("size_changed", self, "resize_main")
	resize_main()
	
	# Setting everything up for the node to be default
	$TextBubble/NameLabel.text = ''
	$Background.visible = false
	$TextBubble/RichTextLabel.meta_underlined = false
	$GlossaryInfo.visible = false
	
	# Getting the character information
	characters = DialogicUtil.get_character_list()
	
	load_dialog()


func resize_main():
	if Engine.is_editor_hint() == false:
		set_global_position(Vector2(0,0))
		set_deferred('rect_size', get_viewport().size)


func set_current_dialog(dialog_path):
	var dialog_script = DialogicUtil.load_json(DialogicUtil.get_path('TIMELINE_DIR', dialog_path))
	# All this parse events should be happening in the same loop ideally
	# But until performance is not an issue I will probably stay lazy
	# And keep adding different functions for each parsing operation.
	dialog_script = parse_text_lines(dialog_script)
	dialog_script = parse_glossary(dialog_script)
	dialog_script = parse_branches(dialog_script)
	return dialog_script


func parse_text_lines(unparsed_dialog_script: Dictionary) -> Dictionary:
	var parsed_dialog: Dictionary = unparsed_dialog_script
	var new_events: Array = []
	
	# Return the same thing if it doesn't have events
	if unparsed_dialog_script.has('events') == false:
		return unparsed_dialog_script
			
	# Parsing
	for event in unparsed_dialog_script['events']:
		if event.has('text') and event.has('character') and event.has('portrait'):
			if '\n' in event['text']:
				var lines = event['text'].split('\n')
				var i = 0
				for line in lines:
					var _e = {
						'text': lines[i],
						'character': event['character'],
						'portrait': event['portrait']
					}
					new_events.append(_e)
					i += 1
			else:
				new_events.append(event)
		else:
			new_events.append(event)

	parsed_dialog['events'] = new_events

	return parsed_dialog


func parse_branches(dialog_script: Dictionary) -> Dictionary:
	questions = [] # Resetting the questions 

	# Return the same thing if it doesn't have events
	if dialog_script.has('events') == false:
		return dialog_script

	var parser_queue = [] # This saves the last question opened, and it gets removed once it was consumed by a endbranch event
	var event_id: int = 0 # The current id for jumping later on
	var question_id: int = 0 # identifying the questions to assign options to it
	for event in dialog_script['events']:
		if event.has('question'):
			event['event_id'] = event_id
			event['question_id'] = question_id
			event['answered'] = false
			question_id += 1
			questions.append(event)
			parser_queue.append(event)
		
		if event.has('condition'):
			event['event_id'] = event_id
			event['question_id'] = question_id
			event['answered'] = false
			question_id += 1
			questions.append(event)
			parser_queue.append(event)
		
		if event.has('choice'):
			var opened_branch = parser_queue.back()
			dialog_script['events'][opened_branch['event_id']]['options'].append({
				'question_id': opened_branch['question_id'],
				'label': event['choice'],
				'event_id': event_id,
				})
			event['question_id'] = opened_branch['question_id']
			
		if event.has('endbranch'):
			event['event_id'] = event_id
			var opened_branch = parser_queue.pop_back()
			event['end_branch_of'] = opened_branch['question_id']
			dialog_script['events'][opened_branch['event_id']]['end_id'] = event_id
		event_id += 1

	return dialog_script


func parse_glossary(dialog_script):
	var words = []
	for g in glossary:
		words.append(glossary[g]['name'])
	
	# I should use regex here, but this is way easier :)
	
	
	# TODO: Remake with new themes
	#if words.size() > 0:
	#	var index = 0
	#	for t in dialog_script['events']:
	#		if t.has('text') and t.has('character') and t.has('portrait'):
	#			for w in glossary:
	#				if glossary[w]['type'] == DialogicUtil.GLOSSARY_EXTRA:
	#					dialog_script['events'][index]['text'] = t['text'].replace(glossary[w]['name'],
	#						'[url=' + glossary[w]['name'] + ']' +
	#							'[color=' + settings['glossary_color'] + ']' + glossary[w]['name'] + '[/color]' +
	#						'[/url]'
	#					)
	#		index += 1
	return dialog_script


func _process(_delta):
	$TextBubble/NextIndicator.visible = finished
	if Engine.is_editor_hint() == false:
		# Multiple choices
		if waiting_for_answer:
			$Options.visible = finished
		else:
			$Options.visible = false
		
		if Input.is_action_just_pressed(input_next):
			if $TextBubble/Tween.is_active():
				# Skip to end if key is pressed during the text animation
				$TextBubble/Tween.seek(999)
				finished = true
			else:
				if waiting_for_answer == false and waiting_for_input == false:
					load_dialog()


func show_dialog():
	visible = true


func start_text_tween():
	# This will start the animation that makes the text appear letter by letter
	var tween_duration = text_speed * $TextBubble/RichTextLabel.get_total_character_count()
	$TextBubble/Tween.interpolate_property(
		$TextBubble/RichTextLabel, "percent_visible", 0, 1, tween_duration,
		Tween.TRANS_LINEAR, Tween.EASE_IN_OUT
	)
	$TextBubble/Tween.start()


func update_name(character, color='#FFFFFF'):
	if character.has('name'):
		var parsed_name = character['name']
		if character.has('display_name'):
			if character['display_name'] != '':
				parsed_name = character['display_name']
		if character.has('color'):
			color = '#' + character['color'].to_html()
		$TextBubble/NameLabel.bbcode_text = '[color=' + color + ']' + parsed_name + '[/color]'
	else:
		$TextBubble/NameLabel.bbcode_text = ''
	return true


func update_text(text):
	# Updating the text and starting the animation from 0
	$TextBubble/RichTextLabel.bbcode_text = text
	$TextBubble/RichTextLabel.percent_visible = 0
	
	# The call to this function needs to be deferred. 
	# More info: https://github.com/godotengine/godot/issues/36381
	call_deferred("start_text_tween")
	return true


func load_dialog(skip_add = false):
	# Hiding glossary
	glossary_visible = false
	$GlossaryInfo.visible = glossary_visible
	
	# This will load the next entry in the dialog_script array.
	if dialog_script.has('events'):
		if dialog_index < dialog_script['events'].size():
			event_handler(dialog_script['events'][dialog_index])
		else:
			if Engine.is_editor_hint() == false:
				queue_free()
	if skip_add == false:
		dialog_index += 1


func reset_dialog_extras():
	$TextBubble/NameLabel.bbcode_text = ''


func get_character(character_id):
	for c in characters:
		if c['file'] == character_id:
			return c
	return {}


func event_handler(event: Dictionary):
	# Handling an event and updating the available nodes accordingly. 
	reset_dialog_extras()
	dprint('[D] Current Event: ', event)
	match event:
		{'text', 'character', 'portrait'}:
			show_dialog()
			finished = false
			var character_data = get_character(event['character'])
			update_name(character_data)
			grab_portrait_focus(character_data, event)
			update_text(event['text'])
		{'question', 'question_id', 'options', ..}:
			show_dialog()
			finished = false
			waiting_for_answer = true
			if event.has('name'):
				update_name(event['name'])
			update_text(event['question'])
			if event.has('options'):
				for o in event['options']:
					add_choice_button(o)
		{'choice', 'question_id'}:
			for q in questions:
				if q['question_id'] == event['question_id']:
					if q['answered']:
						# If the option is for an answered question, skip to the end of it.
						dialog_index = q['end_id']
						load_dialog(true)
			# It should never get here, but if it does, go to the next place.
			#go_to_next_event()
		{'input', ..}:
			show_dialog()
			finished = false
			waiting_for_input = true
			update_text(event['input'])
			$TextInputDialog.window_title = event['window_title']
			$TextInputDialog.popup_centered()
			$TextInputDialog.connect("confirmed", self, "_on_input_set", [event['variable']])
		{'action', ..}:
			if event['action'] == 'leaveall':
				if event['character'] == '[All]':
					for p in $Portraits.get_children():
						p.fade_out()
				else:
					for p in $Portraits.get_children():
						if p.character_data['file'] == event['character']:
							p.fade_out()
					
				go_to_next_event()
			elif event['action'] == 'join':
				if event['character'] == '':
					go_to_next_event()
				else:
					var character_data = get_character(event['character'])
					var exists = grab_portrait_focus(character_data)
					if exists == false:
						var p = Portrait.instance()
						var char_portrait = event['portrait']
						if char_portrait == '':
							char_portrait = 'Default'
						p.character_data = character_data
						p.init(char_portrait, get_character_position(event['position']))
						$Portraits.add_child(p)
						p.fade_in()
				go_to_next_event()
		{'scene'}:
			get_tree().change_scene(event['scene'])
		{'background'}:
			$Background.visible = true
			$Background.texture = load(event['background'])
			dialog_index += 1
			load_dialog(true)
		{'audio'}, {'audio', 'file'}:
			if event['audio'] == 'play':
				$FX/AudioStreamPlayer.stream = load(event['file'])
				$FX/AudioStreamPlayer.play()
			# Todo: audio stop
			go_to_next_event()
		{'endbranch', ..}:
			go_to_next_event()
		{'change_scene'}:
			get_tree().change_scene(event['change_scene'])
		{'emit_signal', ..}:
			print('[!] Emitting signal: dialogic_signal(', event['emit_signal'], ')')
			emit_signal("dialogic_signal", event['emit_signal'])
			go_to_next_event()
		{'close_dialog'}:
			queue_free()
		{'wait_seconds'}:
			wait_seconds(event['wait_seconds'])
		{'change_timeline'}:
			dialog_script = set_current_dialog('/' + event['change_timeline'])
			dialog_index = -1
			go_to_next_event()
		{'condition', 'glossary', 'value', 'question_id', ..}:
			# Treating this conditional as an option on a regular question event
			var current_question = questions[event['question_id']]
			#var g_var = DialogicUtil.get_glossary_by_file(event['glossary'])
			var g_var = glossary[event['glossary'].replace('.json', '')]
			
			if g_var.has('type'):
				if g_var['type'] == DialogicUtil.GLOSSARY_STRING:
					if g_var['string'] == event['value']:
						pass
					else:
						current_question['answered'] = true # This will abort the current conditional branch
				if g_var['type'] == DialogicUtil.GLOSSARY_NUMBER:
					if g_var['number'] == event['value']:
						pass
					else:
						current_question['answered'] = true # This will abort the current conditional branch
			
			
			if current_question['answered']:
				# If the option is for an answered question, skip to the end of it.
				dialog_index = current_question['end_id']
				load_dialog(true)
			else:
				# It should never get here, but if it does, go to the next place.
				go_to_next_event()
		{'set_value', 'glossary'}:
			glossary = DialogicUtil.set_var_by_id(event['glossary'], event['set_value'], glossary)
			print(glossary)
			go_to_next_event()
		_:
			visible = false
			dprint('Other event. ', event)


func _on_input_set(variable):
	var input_value = $TextInputDialog/LineEdit.text
	if input_value == '':
		$TextInputDialog.popup_centered()
	else:
		dialog_resource.custom_variables[variable] = input_value
		waiting_for_input = false
		$TextInputDialog/LineEdit.text = ''
		$TextInputDialog.disconnect("confirmed", self, '_on_input_set')
		$TextInputDialog.visible = false
		load_dialog()
		dprint('[!] Input selected: ', input_value)
		dprint('[!] dialog variables: ', dialog_resource.custom_variables)


func reset_options():
	# Clearing out the options after one was selected.
	for option in $Options.get_children():
		option.queue_free()


func add_choice_button(option):
	var theme = current_theme
	
	var button = ChoiceButton.instance()
	button.text = option['label']
	# Text
	button.set('custom_fonts/font', load(theme.get_value('text', 'font', "res://addons/dialogic/Fonts/DefaultFont.tres")))
	
	var text_color = Color(theme.get_value('text', 'color', "#ffffffff"))
	button.set('custom_colors/font_color', text_color)
	button.set('custom_colors/font_color_hover', text_color)
	button.set('custom_colors/font_color_pressed', text_color)
	
	if theme.get_value('buttons', 'text_color_enabled', true):
		var button_text_color = Color(theme.get_value('buttons', 'text_color', "#ffffffff"))
		button.set('custom_colors/font_color', button_text_color)
		button.set('custom_colors/font_color_hover', button_text_color)
		button.set('custom_colors/font_color_pressed', button_text_color)

	# Background
	button.get_node('ColorRect').color = Color(theme.get_value('buttons', 'background_color', '#ff000000'))
	button.get_node('ColorRect').visible = theme.get_value('buttons', 'use_background_color', false)

	button.get_node('TextureRect').visible = theme.get_value('buttons', 'use_image', true)
	if theme.get_value('buttons', 'use_image', true):
		button.get_node('TextureRect').texture = load(theme.get_value('buttons', 'image', "res://addons/dialogic/Images/background/background-2.png"))
	
	var padding = theme.get_value('buttons', 'padding', Vector2(5,5))
	button.get_node('ColorRect').set('margin_left', -1 * padding.x)
	button.get_node('ColorRect').set('margin_right',  padding.x)
	button.get_node('ColorRect').set('margin_top', -1 * padding.y)
	button.get_node('ColorRect').set('margin_bottom', padding.y)
	
	button.get_node('TextureRect').set('margin_left', -1 * padding.x)
	button.get_node('TextureRect').set('margin_right',  padding.x)
	button.get_node('TextureRect').set('margin_top', -1 * padding.y)
	button.get_node('TextureRect').set('margin_bottom', padding.y)
	
	$Options.set('custom_constants/separation', theme.get_value('buttons', 'gap', 20) + (padding.y*2))

	button.connect("pressed", self, "answer_question", [button, option['event_id'], option['question_id']])
	
	$Options.add_child(button)

	if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		last_mouse_mode = Input.get_mouse_mode()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) # Make sure the cursor is visible for the options selection


func answer_question(i, event_id, question_id):
	dprint('[!] Going to ', event_id + 1, i, 'question_id:', question_id)
	dprint('')
	waiting_for_answer = false
	dialog_index = event_id + 1
	questions[question_id]['answered'] = true
	dprint('    dialog_index = ', dialog_index)
	reset_options()
	load_dialog()
	if last_mouse_mode != null:
		Input.set_mouse_mode(last_mouse_mode) # Revert to last mouse mode when selection is done
		last_mouse_mode = null


func _on_option_selected(option, variable, value):
	dialog_resource.custom_variables[variable] = value
	waiting_for_answer = false
	reset_options()
	load_dialog()
	#print(dialog_resource.custom_variables)
	dprint('[!] Option selected: ', option.text, ' value= ' , value)


func _on_Tween_tween_completed(object, key):
	#$TextBubble/RichTextLabel.meta_underlined = true
	finished = true


func _on_TextInputDialog_confirmed():
	pass # Replace with function body.


func go_to_next_event():
	# The entire event reading system should be refactored... but not today!
	dialog_index += 1
	load_dialog(true)


func grab_portrait_focus(character_data, event: Dictionary = {}) -> bool:
	var exists = false
	for portrait in $Portraits.get_children():
		if portrait.character_data == character_data:
			exists = true
			portrait.focus()
			if event.has('portrait'):
				if event['portrait'] != '':
					portrait.set_portrait(event['portrait'])
		else:
			portrait.focusout()
	return exists


func get_character_position(positions):
	if positions['0']:
		return 'left'
	if positions['1']:
		return 'center_left'
	if positions['2']:
		return 'center'
	if positions['3']:
		return 'center_right'
	if positions['4']:
		return 'right'
	return 


func load_theme(filename) -> void:
	var theme = DialogicUtil.get_theme(filename) 
	current_theme = theme
	
	var theme_font = load(theme.get_value('text', 'font', 'res://addons/dialogic/Fonts/DefaultFont.tres'))
	$TextBubble/RichTextLabel.set('custom_fonts/normal_font', theme_font)
	$TextBubble/NameLabel.set('custom_fonts/normal_font', theme_font)
	
	var text_color = Color(theme.get_value('text', 'color', '#ffffffff'))
	$TextBubble/RichTextLabel.set('custom_colors/default_color', text_color)
	$TextBubble/NameLabel.set('custom_colors/default_color', text_color)
	
	$TextBubble/RichTextLabel.set('custom_colors/font_color_shadow', Color('#00ffffff'))
	$TextBubble/NameLabel.set('custom_colors/font_color_shadow', Color('#00ffffff'))
	
	if theme.get_value('text', 'shadow', false):
		var text_shadow_color = Color(theme.get_value('text', 'shadow_color', '#9e000000'))
		$TextBubble/RichTextLabel.set('custom_colors/font_color_shadow', text_shadow_color)
		$TextBubble/NameLabel.set('custom_colors/font_color_shadow', text_shadow_color)
	
	var shadow_offset = theme.get_value('text', 'shadow_offset', Vector2(2,2))
	$TextBubble/RichTextLabel.set('custom_constants/shadow_offset_x', shadow_offset.x)
	$TextBubble/NameLabel.set('custom_constants/shadow_offset_x', shadow_offset.x)
	$TextBubble/RichTextLabel.set('custom_constants/shadow_offset_y', shadow_offset.y)
	$TextBubble/NameLabel.set('custom_constants/shadow_offset_y', shadow_offset.y)
	
	# Text speed
	text_speed = theme.get_value('text','speed', 2) * 0.01
	
	# Margin
	var text_margin = theme.get_value('text', 'margin', Vector2(20, 10))
	$TextBubble/RichTextLabel.set('margin_left', text_margin.x)
	$TextBubble/RichTextLabel.set('margin_right', text_margin.x * -1)
	$TextBubble/RichTextLabel.set('margin_top', text_margin.y)
	$TextBubble/RichTextLabel.set('margin_bottom', text_margin.y * -1)
	
	# Backgrounds
	$TextBubble/TextureRect.texture = load(theme.get_value('background','image', "res://addons/dialogic/Images/background/background-2.png"))
	$TextBubble/ColorRect.color = Color(theme.get_value('background','color', "#ff000000"))
	
	$TextBubble/ColorRect.visible = theme.get_value('background', 'use_color', false)
	$TextBubble/TextureRect.visible = theme.get_value('background', 'use_image', true)
	
	# Next image
	$TextBubble/NextIndicator.texture = load(theme.get_value('next_indicator', 'image', 'res://addons/dialogic/Images/next-indicator.png'))
	input_next = theme.get_value('settings', 'action_key', 'ui_accept')
	
	# Glossary
	var definitions_font = load(theme.get_value('definitions', 'font', 'res://addons/dialogic/Fonts/GlossaryFont.tres'))
	$GlossaryInfo/VBoxContainer/Title.set('custom_fonts/normal_font', definitions_font)
	$GlossaryInfo/VBoxContainer/Content.set('custom_fonts/normal_font', definitions_font)
	$GlossaryInfo/VBoxContainer/Extra.set('custom_fonts/normal_font', definitions_font)


func _on_RichTextLabel_meta_hover_started(meta):
	var correct_type = false
	for g in glossary:
		if glossary[g]['name'] == meta:
			$GlossaryInfo.load_preview(glossary[g])
			if glossary[g]['type'] == DialogicUtil.GLOSSARY_EXTRA:
				correct_type = true

	if correct_type:
		glossary_visible = true
		$GlossaryInfo.visible = glossary_visible
		# Adding a timer to avoid a graphical glitch
		$GlossaryInfo/Timer.stop()
	

func _on_RichTextLabel_meta_hover_ended(meta):
	# Adding a timer to avoid a graphical glitch
	
	$GlossaryInfo/Timer.start(0.1)


func _on_Glossary_Timer_timeout():
	# Adding a timer to avoid a graphical glitch
	glossary_visible = false
	$GlossaryInfo.visible = glossary_visible


func wait_seconds(seconds):
	$WaitSeconds.start(seconds)
	$TextBubble.visible = false


func _on_WaitSeconds_timeout():
	$WaitSeconds.stop()
	$TextBubble.visible = true
	load_dialog()


func dprint(string, arg1='', arg2='', arg3='', arg4='' ):
	# HAHAHA if you are here wondering what this is... 
	# I ask myself the same question :')
	if debug_mode:
		print(str(string) + str(arg1) + str(arg2) + str(arg3) + str(arg4))
