extends Node

# internal parameters
var _baseUri := StringName("https://preview-events.quickscope.tech")
var _enabled := false
var _project_id: String
var _user: String
var _verbose := true
var _sdk_version: String
var _sdk_initiated := false
var _logging_function := func(msg): print(msg)

# http request utilities
signal http_request_completed(success: bool)
const HTTP_TIMEOUT := 0.5
const HTTP_CONNECTION_FAILURE_COUNT := 3
const HTTP_CONNECTION_FAILURE_FALLOFF_MULTIPLIER := 2.0
const HTTP_MAX_CONNECTIONS := 3

var _http_connection_count := 0
var _http_reconnect_timeout := 1.0
var _http_reconnect_timer := 0.0
var _http_pool: Array[HTTPRequest] = []
var _http_request_queue: Array[Dictionary] = []

# session configurations
var app_version: String
var platform: String
var platform_version: String
var default_level := "none"
var auto_session_events := true

# event buffer
var _event_buffer: Array[_Event] = []
var _event_buffer_timeout_seconds := 10.0
var _event_buffer_max_count := 25
var _event_buffer_timer := 0.0

# failure handling
var _connected := true
var _retries := 0
var _network_failures := 0

class _Event:
	var name: String
	var level: String
	var metadata: Dictionary
	var metrics: Dictionary
	var ts: String

func init(project_id: String, app_version := "", user_id := "", session_events := true) -> void:
	if self._sdk_initiated:
		self._log("init called even though SDK is already initiated.")
		return
	
	var sdk_config = ConfigFile.new()
	var err = sdk_config.load("res://addons/quickscope_sdk/plugin.cfg")
	if err != OK:
		self._sdk_version = "unknown"

	self._sdk_version = sdk_config.get_value('plugin', 'version', 'unknown')
	
	self._project_id = project_id
	
	if app_version.is_empty():
		self.app_version = ProjectSettings.get_setting("application/config/version")
	
	if user_id.is_empty():
		self._user = OS.get_unique_id()
	
	self.platform = OS.get_name()
	self.platform_version = OS.get_version()
	
	self._event_buffer_timer = self._event_buffer_timeout_seconds
	
	self.enable()
	
	self._log("Init v%s" % [self._sdk_version])
	
	self._sdk_initiated = true
	
	self.auto_session_events = session_events
	if self.auto_session_events:
		self.event("session_started")

func enable() -> void:
	self._enabled = true
	self.set_physics_process(true)
	
func disable() -> void:
	self._enabled = false
	self.set_physics_process(false)

func set_logger(log_func):
	self._logging_function = log_func

func _physics_process(delta):
	if not self._enabled:
		return
	
	if not _connected:
		self._http_reconnect_timer -= delta
		if self._http_reconnect_timer <= 0.0:
			self._connected = true
	
	self._event_buffer_timer -= delta
	if self._event_buffer_timer <= 0.0:
		self._process_event_queue()
		self._event_buffer_timer = self._event_buffer_timeout_seconds
	
	if not self._http_request_queue.is_empty():
		# limiting this to one new http request per physics frame incase
		# there is a large number of backlogged requests
		self._make_next_request()
		
func event(name: String, metadata: Dictionary = {}, metrics: Dictionary = {}, level: String = "", ts: String = "") -> void:
	
	if not self._enabled:
		return
	
	var e = _Event.new()
	
	if level.is_empty():
		level = default_level
	
	if ts.is_empty():
		ts = Time.get_datetime_string_from_system(true)
	
	e.name = name
	e.level = level
	e.metadata = metadata
	e.metrics = metrics
	e.ts = ts
	
	self._queue_event(e)

func _queue_event(e: _Event) -> void:
	_event_buffer.append(e)
	if len(_event_buffer) > _event_buffer_max_count:
		_process_event_queue()

func _process_event_queue() -> void:
	if not self._enabled:
		return
	if _event_buffer.is_empty():
		return
	self._log("Processing Event Queue ...", true)

	var payload = {"events": []}
	for e in _event_buffer:
		payload["events"].append(self._format_event_for_request(e))
	
	_clear_event_buffer()
	_http_request_queue.append(payload)

func _clear_event_buffer():
	_event_buffer.clear()

func _format_event_for_request(e: _Event) -> Dictionary:
	return {
		"uid": self._user,
		"name": e.name,
		"lvl": e.level,
		"app_v": self.app_version,
		"platform": self.platform,
		"platform_v": self.platform_version,
		"metadata": JSON.stringify(e.metadata),
		"metrics": JSON.stringify(e.metrics),
		"ts": e.ts,
	}

func _log(message: String, is_verbose := false) -> void:
	if (is_verbose && !self._verbose):
		return
	self._logging_function.call("[QuickScopeSDK] %s" % message)

func _get_http_request() -> HTTPRequest:
	var http_request: HTTPRequest
	if _http_pool.is_empty():
		http_request = HTTPRequest.new()
		http_request.timeout = HTTP_TIMEOUT
		http_request.use_threads = true
	else:
		http_request = _http_pool.pop_back()
	add_child(http_request)
	return http_request

func _return_http_request(http_request: HTTPRequest) -> void:
	if is_instance_valid(http_request) and http_request.get_parent() == self:
		self._log("Returning HTTP Request Node to pool", true)
		remove_child(http_request)
		_http_pool.append(http_request)
	else:
		push_warning("Invalid HTTP Request tried to be added to http pool.")
		self._log("Invalid HTTP Request tried to be added to http pool.", true)
		http_request.queue_free()
		

func _make_next_request() -> void:
	if not self._enabled or not self._connected:
		return
	
	if self._http_connection_count >= HTTP_MAX_CONNECTIONS:
		return
	
	var payload := self._http_request_queue.pop_back()
	
	var http_request = _get_http_request()
	var json_payload = JSON.new().stringify(payload)
	
	if self._verbose:
		self._log("Making Event Request: %s" % json_payload, true)

	self._http_connection_count += 1
	var error = http_request.request(self._baseUri, [], HTTPClient.METHOD_POST, json_payload)
	if error != OK:
		self._http_connection_count -= 1
		self._return_http_request(http_request)
		self._handle_failed_request(payload, error)
		return

	var http_response: Array = await http_request.request_completed
	
	self._http_connection_count -= 1
	
	var result: int = http_response[0]
	var response_code: int = http_response[1]
	var headers: PackedStringArray = http_response[2]
	var response_body: PackedByteArray = http_response[3]
	
	if result != OK or response_code != 201:
		self._return_http_request(http_request)
		self._handle_failed_request(payload, result, response_code, headers)
		return

	if self._verbose:
		self._log(response_body.get_string_from_utf8(), true)
	
	# reset network failure count
	self._handle_successful_request()
	
	emit_signal("http_request_completed", true)
	self._return_http_request(http_request)

func _handle_successful_request():
	_http_reconnect_timeout = 1.0
	_network_failures = 0
	_connected = true

func _handle_failed_request(payload: Dictionary, reason: int, response_code: int = 0, headers: PackedStringArray = []):
	self._log("Failed HTTP Request: %s" % reason, true)

	if reason == OK:
		# request failed due to something on the server, check response code and headers
		# todo handle rate limiting and rejection here.
		
		return
	
	# put payload back into request queue
	_http_request_queue.append(payload)
		
	# request failed due to something outside the servers control, probably network connectivity
	_network_failures += 1
	
	if _network_failures >= HTTP_CONNECTION_FAILURE_COUNT:
		# we probably aren't connected to the internet or are just unable to reach the endpoint
		self._disconnected()
		
	emit_signal("http_request_completed", false)
		
func _disconnected():
	self._log("Unable to connect to QuickScope servers, retrying in %s seconds." % self._http_reconnect_timeout)
	# add exponential backoff for retries
	self._http_reconnect_timeout *= HTTP_CONNECTION_FAILURE_FALLOFF_MULTIPLIER
	self._http_reconnect_timer = self._http_reconnect_timeout
	# set connected to false for now
	self._connected = false

func _exit_tree():
	if not self._enabled:
		return
	
	if self.auto_session_events:
		self.event("session_ended")
	
	self._process_event_queue()
	
	# if we're connected, wait until one last http request is finished
	if self._connected:
		await self.http_request_completed
	
	# todo if there are any pending http requests, write them to disk
