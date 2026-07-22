@tool
extends Control

var api_input: LineEdit
var connect_btn: Button
var project_dropdown: OptionButton
var status_lbl: Label
var sync_btn: Button

var api_client: GameVocalAPIClient
var download_manager: GameVocalDownloadManager
var current_manifest: GameVocalProjectManifest

var project_map: Array = []
var _current_request_type: String = ""

var live_sync_toggle: CheckButton
var auto_sync_timer: Timer
var status_api_client: GameVocalAPIClient

func _ready():
	_build_ui()
	
	api_client = GameVocalAPIClient.new()
	add_child(api_client)
	api_client.request_completed.connect(_on_api_response)
	api_client.error_occurred.connect(_on_api_error)
	
	download_manager = GameVocalDownloadManager.new()
	add_child(download_manager)
	download_manager.all_downloads_completed.connect(_on_all_downloads_completed)
	download_manager.download_failed.connect(_on_download_failed)
	
	status_api_client = GameVocalAPIClient.new()
	add_child(status_api_client)
	status_api_client.request_completed.connect(_on_status_api_response)
	
	auto_sync_timer = Timer.new()
	auto_sync_timer.wait_time = 3.0
	auto_sync_timer.one_shot = false
	auto_sync_timer.timeout.connect(_on_auto_sync_timer_timeout)
	add_child(auto_sync_timer)
	
	_update_ui_state()

func _build_ui():
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	
	var main_margin = MarginContainer.new()
	main_margin.size_flags_horizontal = SIZE_EXPAND_FILL
	main_margin.size_flags_vertical = SIZE_EXPAND_FILL
	main_margin.add_theme_constant_override("margin_top", 16)
	main_margin.add_theme_constant_override("margin_bottom", 16)
	main_margin.add_theme_constant_override("margin_left", 16)
	main_margin.add_theme_constant_override("margin_right", 16)
	scroll.add_child(main_margin)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 24)
	main_margin.add_child(vbox)
	
	# Header
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(header_hbox)
	
	var logo_rect = TextureRect.new()
	if ResourceLoader.exists("res://addons/gamevocal/icons/gamevocal.svg"):
		logo_rect.texture = load("res://addons/gamevocal/icons/gamevocal.svg")
		logo_rect.custom_minimum_size = Vector2(160, 48)
		logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header_hbox.add_child(logo_rect)
	
	# Settings Section
	var settings_panel = PanelContainer.new()
	vbox.add_child(settings_panel)
	var settings_margin = MarginContainer.new()
	settings_margin.add_theme_constant_override("margin_top", 12)
	settings_margin.add_theme_constant_override("margin_bottom", 12)
	settings_margin.add_theme_constant_override("margin_left", 12)
	settings_margin.add_theme_constant_override("margin_right", 12)
	settings_panel.add_child(settings_margin)
	
	var settings_vbox = VBoxContainer.new()
	settings_vbox.add_theme_constant_override("separation", 8)
	settings_margin.add_child(settings_vbox)
	
	var auth_lbl = Label.new()
	auth_lbl.text = "AUTHENTICATION"
	auth_lbl.add_theme_font_size_override("font_size", 11)
	auth_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	settings_vbox.add_child(auth_lbl)
	
	api_input = LineEdit.new()
	api_input.placeholder_text = "Enter API Key..."
	api_input.secret = true
	settings_vbox.add_child(api_input)
	
	connect_btn = Button.new()
	connect_btn.text = "Save Key"
	connect_btn.pressed.connect(_on_connect_pressed)
	settings_vbox.add_child(connect_btn)
	
	# Project Sync Section
	var project_panel = PanelContainer.new()
	vbox.add_child(project_panel)
	var project_margin = MarginContainer.new()
	project_margin.add_theme_constant_override("margin_top", 12)
	project_margin.add_theme_constant_override("margin_bottom", 12)
	project_margin.add_theme_constant_override("margin_left", 12)
	project_margin.add_theme_constant_override("margin_right", 12)
	project_panel.add_child(project_margin)
	
	var project_vbox = VBoxContainer.new()
	project_vbox.add_theme_constant_override("separation", 8)
	project_margin.add_child(project_vbox)
	
	var proj_lbl = Label.new()
	proj_lbl.text = "CLOUD PROJECT"
	proj_lbl.add_theme_font_size_override("font_size", 11)
	proj_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	project_vbox.add_child(proj_lbl)
	
	project_dropdown = OptionButton.new()
	project_dropdown.disabled = true
	project_dropdown.custom_minimum_size = Vector2(0, 32)
	project_vbox.add_child(project_dropdown)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)
	
	# Big Sync Button
	sync_btn = Button.new()
	sync_btn.text = "Sync Assets"
	sync_btn.custom_minimum_size = Vector2(0, 48)
	sync_btn.add_theme_font_size_override("font_size", 16)
	
	# High contrast black text for the bright green button
	sync_btn.add_theme_color_override("font_color", Color(0, 0, 0, 0.85))
	sync_btn.add_theme_color_override("font_hover_color", Color(0, 0, 0, 1.0))
	sync_btn.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 1.0))
	sync_btn.add_theme_color_override("font_focus_color", Color(0, 0, 0, 0.85))
	sync_btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6))
	var sync_style = StyleBoxFlat.new()
	sync_style.bg_color = Color("90d12e") # Vibrant app theme green
	sync_style.corner_radius_top_left = 6
	sync_style.corner_radius_top_right = 6
	sync_style.corner_radius_bottom_left = 6
	sync_style.corner_radius_bottom_right = 6
	sync_btn.add_theme_stylebox_override("normal", sync_style)
	
	var sync_style_hover = sync_style.duplicate()
	sync_style_hover.bg_color = Color("a6e344") # Slightly brighter for hover
	sync_btn.add_theme_stylebox_override("hover", sync_style_hover)
	
	var sync_style_pressed = sync_style.duplicate()
	sync_style_pressed.bg_color = Color("7ab522") # Slightly darker for pressed
	sync_btn.add_theme_stylebox_override("pressed", sync_style_pressed)
	
	var sync_style_disabled = sync_style.duplicate()
	sync_style_disabled.bg_color = Color(0.3, 0.3, 0.3, 0.5)
	sync_btn.add_theme_stylebox_override("disabled", sync_style_disabled)
	
	sync_btn.pressed.connect(_on_sync_pressed)
	
	var sync_controls_vbox = VBoxContainer.new()
	sync_controls_vbox.add_theme_constant_override("separation", 12)
	vbox.add_child(sync_controls_vbox)
	
	var live_sync_hbox = HBoxContainer.new()
	live_sync_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var live_lbl = Label.new()
	live_lbl.text = "Live Dialogue Sync"
	live_lbl.add_theme_font_size_override("font_size", 13)
	live_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	live_sync_hbox.add_child(live_lbl)
	
	live_sync_toggle = CheckButton.new()
	var green_color = Color("90d12e")
	live_sync_toggle.add_theme_color_override("checked", green_color)
	live_sync_toggle.add_theme_color_override("icon_pressed_color", green_color)
	live_sync_toggle.add_theme_color_override("icon_hover_pressed_color", green_color)
	live_sync_toggle.toggled.connect(_on_live_sync_toggled)
	live_sync_hbox.add_child(live_sync_toggle)
	sync_controls_vbox.add_child(live_sync_hbox)
	
	sync_controls_vbox.add_child(sync_btn)
	
	# Status Label
	status_lbl = Label.new()
	status_lbl.text = "Ready to sync."
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 13)
	status_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(status_lbl)

func _set_status(msg: String, color: Color = Color(0.7, 0.7, 0.7)):
	status_lbl.text = msg
	status_lbl.add_theme_color_override("font_color", color)

func _update_ui_state():
	var key = GameVocalSettingsStore.get_api_key()
	
	if key.is_empty():
		api_input.text = ""
		api_input.editable = true
		connect_btn.text = "Save API Key"
		_set_status("Waiting for API Key...", Color(0.7, 0.7, 0.7))
		project_dropdown.disabled = true
		project_dropdown.clear()
		sync_btn.disabled = true
	else:
		api_input.text = "••••••••••••••••"
		api_input.editable = false
		connect_btn.text = "Clear API Key"
		_set_status("Fetching projects...", Color(0.7, 0.7, 0.7))
		project_dropdown.disabled = true
		sync_btn.disabled = true
		_current_request_type = "projects"
		api_client.request("/api/v1/projects/")

func _on_connect_pressed():
	if GameVocalSettingsStore.get_api_key().is_empty():
		var key = api_input.text.strip_edges()
		if not key.is_empty():
			GameVocalSettingsStore.set_api_key(key)
			_update_ui_state()
	else:
		GameVocalSettingsStore.clear_credentials()
		_update_ui_state()

func _on_sync_pressed():
	if project_map.is_empty() or project_dropdown.selected < 0 or project_dropdown.selected >= project_map.size():
		return
	var project_id = project_map[project_dropdown.selected]
	_set_status("Syncing...", Color(0.4, 0.8, 1.0))
	sync_btn.disabled = true
	project_dropdown.disabled = true
	_current_request_type = "manifest"
	api_client.request("/api/v1/projects/" + project_id + "/manifest")

func _on_api_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if response_code != 200:
		sync_btn.disabled = false
		if not project_map.is_empty():
			project_dropdown.disabled = false
		_set_status("HTTP Error " + str(response_code), Color(0.9, 0.3, 0.3))
		return
		
	var json = JSON.new()
	var parse_err = json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		sync_btn.disabled = false
		if not project_map.is_empty():
			project_dropdown.disabled = false
		_set_status("JSON Parse Error", Color(0.9, 0.3, 0.3))
		return
		
	var data = json.data
	
	if _current_request_type == "projects":
		_handle_projects_response(data)
	elif _current_request_type == "manifest":
		_handle_manifest_response(data)

func _on_live_sync_toggled(button_pressed: bool):
	if button_pressed:
		if project_dropdown.selected >= 0 and not project_map.is_empty():
			auto_sync_timer.start()
			_set_status("Live Sync Enabled", Color(0.4, 0.8, 1.0))
		else:
			live_sync_toggle.button_pressed = false
			_set_status("Please select a project first.", Color(0.9, 0.3, 0.3))
	else:
		auto_sync_timer.stop()
		_set_status("Ready to sync.", Color(0.7, 0.7, 0.7))

func _on_auto_sync_timer_timeout():
	if project_map.is_empty() or project_dropdown.selected < 0 or project_dropdown.selected >= project_map.size():
		return
	if sync_btn.disabled: # Don't poll while already syncing
		return
		
	var project_id = project_map[project_dropdown.selected]
	status_api_client.request("/api/v1/projects/" + project_id + "/sync-status")

func _on_status_api_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if response_code != 200 or sync_btn.disabled:
		return
	
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return
		
	if typeof(json.data) == TYPE_DICTIONARY and json.data.has("version"):
		var remote_version = json.data["version"]
		if current_manifest == null:
			current_manifest = GameVocalProjectManifest.load_manifest()
			
		var local_version = current_manifest.get("last_sync_version") if current_manifest.get("last_sync_version") != null else ""
		if remote_version != local_version:
			print("[GameVocal] Detected changes. Auto-syncing...")
			_on_sync_pressed()

func _handle_projects_response(data):
	project_dropdown.clear()
	project_map.clear()
	
	if typeof(data) == TYPE_ARRAY:
		for p in data:
			var p_id = p.get("id", "")
			var p_name = p.get("name", "Unnamed Project")
			if not p_id.is_empty():
				project_dropdown.add_item(p_name)
				project_map.append(p_id)
				
	if project_map.is_empty():
		_set_status("No projects found.", Color(0.8, 0.6, 0.2))
		project_dropdown.disabled = true
		sync_btn.disabled = true
	else:
		_set_status("Ready to sync.", Color(0.7, 0.7, 0.7))
		project_dropdown.disabled = false
		sync_btn.disabled = false

func _handle_manifest_response(data):
	if typeof(data) != TYPE_DICTIONARY or not data.has("files"):
		sync_btn.disabled = false
		project_dropdown.disabled = false
		_set_status("Invalid manifest format", Color(0.9, 0.3, 0.3))
		return
	
	current_manifest = GameVocalProjectManifest.load_manifest()
	if data.has("project_id"):
		current_manifest.project_id = data["project_id"]
	if data.has("last_sync"):
		current_manifest.last_sync = data["last_sync"]
	if data.has("version"):
		current_manifest.set("last_sync_version", data["version"])
		
	var files_to_download = 0
	var new_files_dict = {}
	
	for file_entry in data["files"]:
		var logical_path = file_entry.get("logical_path", "")
		var url = file_entry.get("url", "")
		var checksum = file_entry.get("checksum", "")
		
		if logical_path.is_empty() or url.is_empty():
			continue
			
		new_files_dict[logical_path] = checksum
		
		var target_path = GameVocalPathUtils.get_absolute_path(logical_path)
		var needs_download = true
		
		if current_manifest.files.has(logical_path):
			if current_manifest.files[logical_path] == checksum:
				# Ensure it wasn't manually deleted by the user!
				if FileAccess.file_exists(target_path):
					needs_download = false
				
		if needs_download:
			download_manager.queue_download(url, target_path)
			files_to_download += 1
			
	current_manifest.files = new_files_dict
	
	if files_to_download > 0:
		_set_status("Downloading " + str(files_to_download) + " files...", Color(0.4, 0.8, 1.0))
	else:
		_on_all_downloads_completed()

func _on_all_downloads_completed():
	if current_manifest:
		current_manifest.save_manifest()
		
	GameVocalImportManager.scan_and_import()
	_set_status("Sync Complete!", Color(0.3, 0.8, 0.4))
	sync_btn.disabled = false
	if not project_map.is_empty():
		project_dropdown.disabled = false

func _on_download_failed(file_path: String, reason: String):
	print("[GameVocal] Failed to download ", file_path, " - ", reason)

func _on_api_error(msg: String):
	sync_btn.disabled = false
	if not project_map.is_empty():
		project_dropdown.disabled = false
	_set_status("Error - " + msg, Color(0.9, 0.3, 0.3))
