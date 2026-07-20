@tool
class_name GameVocalAPIClient
extends Node

# Handles HTTP communication with the GameVocal API
# Ensure credentials are sent securely and paths are sanitized.

signal request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)
signal error_occurred(message: String)

var _http_request: HTTPRequest
var _base_url: String = "https://api.gamevocal.com"

func _ready():
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)

func request(endpoint: String, method: int = HTTPClient.METHOD_GET, payload: String = ""):
	var api_key = GameVocalSettingsStore.get_api_key()
	if api_key.is_empty():
		error_occurred.emit("API Key is missing.")
		return
		
	var headers = [
		"Authorization: Bearer " + api_key,
		"Content-Type: application/json",
		"Accept: application/json"
	]
	
	var url = _base_url + endpoint
	if not url.begins_with("http"):
		error_occurred.emit("Invalid API URL: " + url)
		return
		
	var err = _http_request.request(url, headers, method, payload)
	if err != OK:
		error_occurred.emit("Failed to initiate HTTP request.")

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	request_completed.emit(result, response_code, headers, body)
