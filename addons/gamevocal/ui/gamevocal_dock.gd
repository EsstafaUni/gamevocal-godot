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
	
	_update_ui_state()

func _build_ui():
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)
	
	api_input = LineEdit.new()
	api_input.placeholder_text = "Enter API Key..."
	api_input.secret = true
	vbox.add_child(api_input)
	
	connect_btn = Button.new()
	connect_btn.text = "Save Key"
	connect_btn.pressed.connect(_on_connect_pressed)
	vbox.add_child(connect_btn)
	
	vbox.add_child(HSeparator.new())
	
	project_dropdown = OptionButton.new()
	project_dropdown.disabled = true
	vbox.add_child(project_dropdown)
	
	status_lbl = Label.new()
	status_lbl.text = "Status: Disconnected"
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(status_lbl)
	
	sync_btn = Button.new()
	sync_btn.text = "Sync Project"
	sync_btn.pressed.connect(_on_sync_pressed)
	vbox.add_child(sync_btn)

func _update_ui_state():
	var key = GameVocalSettingsStore.get_api_key()
	
	if key.is_empty():
		api_input.text = ""
		api_input.editable = true
		connect_btn.text = "Save API Key"
		status_lbl.text = "Status: Waiting for API Key"
		project_dropdown.disabled = true
		project_dropdown.clear()
		sync_btn.disabled = true
	else:
		api_input.text = "••••••••••••••••"
		api_input.editable = false
		connect_btn.text = "Clear API Key"
		status_lbl.text = "Status: Fetching projects..."
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
	status_lbl.text = "Status: Syncing..."
	sync_btn.disabled = true
	project_dropdown.disabled = true
	_current_request_type = "manifest"
	api_client.request("/api/v1/projects/" + project_id + "/manifest")

func _on_api_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if response_code != 200:
		sync_btn.disabled = false
		if not project_map.is_empty():
			project_dropdown.disabled = false
		status_lbl.text = "Status: HTTP Error " + str(response_code)
		return
		
	var json = JSON.new()
	var parse_err = json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		sync_btn.disabled = false
		if not project_map.is_empty():
			project_dropdown.disabled = false
		status_lbl.text = "Status: JSON Parse Error"
		return
		
	var data = json.data
	
	if _current_request_type == "projects":
		_handle_projects_response(data)
	elif _current_request_type == "manifest":
		_handle_manifest_response(data)

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
		status_lbl.text = "Status: No projects found."
		project_dropdown.disabled = true
		sync_btn.disabled = true
	else:
		status_lbl.text = "Status: Ready"
		project_dropdown.disabled = false
		sync_btn.disabled = false

func _handle_manifest_response(data):
	if typeof(data) != TYPE_DICTIONARY or not data.has("files"):
		sync_btn.disabled = false
		project_dropdown.disabled = false
		status_lbl.text = "Status: Invalid manifest format"
		return
	
	current_manifest = GameVocalProjectManifest.load_manifest()
	if data.has("project_id"):
		current_manifest.project_id = data["project_id"]
	if data.has("last_sync"):
		current_manifest.last_sync = data["last_sync"]
		
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
		status_lbl.text = "Status: Downloading " + str(files_to_download) + " files..."
	else:
		_on_all_downloads_completed()

func _on_all_downloads_completed():
	if current_manifest:
		current_manifest.save_manifest()
		
	GameVocalImportManager.scan_and_import()
	status_lbl.text = "Status: Sync Complete!"
	sync_btn.disabled = false
	if not project_map.is_empty():
		project_dropdown.disabled = false

func _on_download_failed(file_path: String, reason: String):
	print("[GameVocal] Failed to download ", file_path, " - ", reason)

func _on_api_error(msg: String):
	sync_btn.disabled = false
	if not project_map.is_empty():
		project_dropdown.disabled = false
	status_lbl.text = "Status: Error - " + msg
