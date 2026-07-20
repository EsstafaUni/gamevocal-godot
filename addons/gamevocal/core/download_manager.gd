@tool
class_name GameVocalDownloadManager
extends Node

# Handles safe downloading of files.
# Downloads to temp file, and moves atomically on success.

signal all_downloads_completed
signal download_failed(file_path: String, reason: String)

var _queue: Array[Dictionary] = []
var _is_downloading: bool = false
var _http_request: HTTPRequest

func _ready():
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)

func queue_download(url: String, target_path: String):
	_queue.append({
		"url": url,
		"target_path": target_path,
		"temp_path": "user://gamevocal_temp_" + str(randi()) + ".tmp"
	})
	
	if not _is_downloading:
		_process_next()

func _process_next():
	if _queue.is_empty():
		_is_downloading = false
		all_downloads_completed.emit()
		return
		
	_is_downloading = true
	var item = _queue[0]
	
	_http_request.download_file = item["temp_path"]
	
	var headers = []
	var api_key = GameVocalSettingsStore.get_api_key()
	# AWS S3 / R2 presigned URLs reject requests that also provide an Authorization header
	if not api_key.is_empty() and not "X-Amz-Signature" in item["url"]:
		headers.append("Authorization: Bearer " + api_key)
		
	var err = _http_request.request(item["url"], headers)
	
	if err != OK:
		download_failed.emit(item["target_path"], "Failed to start request.")
		_queue.pop_front()
		_process_next()

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var item = _queue.pop_front()
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		_move_atomic(item["temp_path"], item["target_path"])
	else:
		download_failed.emit(item["target_path"], "HTTP Error: " + str(response_code))
		var da = DirAccess.open("user://")
		if da and da.file_exists(item["temp_path"]):
			da.remove(item["temp_path"])
			
	_process_next()

func _move_atomic(temp_path: String, final_path: String):
	var base_dir = final_path.get_base_dir()
	
	if not DirAccess.dir_exists_absolute(base_dir):
		var err_dir = DirAccess.make_dir_recursive_absolute(base_dir)
		if err_dir != OK:
			print("[GameVocal] Error creating directory ", base_dir, ": ", err_dir)
		
	var err = DirAccess.copy_absolute(temp_path, final_path)
	if err == OK:
		DirAccess.remove_absolute(temp_path)
	else:
		print("[GameVocal] Error copying file from ", temp_path, " to ", final_path, " with error code: ", err)
