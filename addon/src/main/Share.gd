#
# © 2024-present https://github.com/cengiz-pz
#

@tool
@icon("icon.png")
class_name Share extends Node

const PLUGIN_SINGLETON_NAME: String = "@pluginName@"

# -- Signals -------------------------------------------------------------------

## Emitted when an outgoing share completes. [param activity_type] is the short
## component name of the app the user chose, or [code]"UnknownActivity"[/code] when
## the chooser callback did not identify it.
signal share_completed(activity_type: String)

## Emitted when the outgoing share fails before the chooser is shown.
## [param error_message] describes the cause.
signal share_failed(error_message: String)

## Emitted when the user opens the share chooser and then dismisses it without
## selecting a target app.
signal share_canceled

## Emitted when another Android app shares data [b]to[/b] this app (share-target mode).[br][br]
##
## [b]Cold-start timing is handled automatically.[/b] When the app is launched directly
## by a share action, [method _ready] detects the pending payload and re-emits this
## signal one frame later via [code]call_deferred[/code], so all [code]@onready[/code]
## variables in parent nodes are already initialised when the handler runs.[br][br]
## [codeblock]
## # Just connect the signal – no extra _ready() boilerplate required.
##
## func _ready() -> void:
##     $Share.share_received.connect(_on_share_received)
##     $Share.set_share_target(true)  # restore persisted preference here
##
## func _on_share_received(data: ReceivedSharedData) -> void:
##     if data.has_files():
##         for path in data.get_file_paths():
##             print("received file: ", path)
##     if data.has_text():
##         print("received text: ", data.get_text())
## [/codeblock]
signal share_received(received_data: ReceivedSharedData)

# -- MIME type helpers ---------------------------------------------------------

const MIME_TYPE_TEXT: String = "text/plain"
const MIME_TYPE_IMAGE: String = "image/*"

# -- Internal signal name constants --------------------------------------------

const SIGNAL_NAME_SHARE_COMPLETED: String = "share_completed"
const SIGNAL_NAME_SHARE_FAILED: String = "share_failed"
const SIGNAL_NAME_SHARE_CANCELED: String = "share_canceled"
const SIGNAL_NAME_SHARE_RECEIVED: String = "share_received"

# -- Private fields ------------------------------------------------------------

@onready var _temp_image_path: String = OS.get_user_data_dir() + "/tmp_share_img_path.png"

var _plugin_singleton: Object

# ==============================================================================
# Lifecycle
# ==============================================================================


func _ready() -> void:
	_update_plugin()
	# If the app was cold-started by a share intent, SharePlugin.onMainResume() fires
	# before any GDScript _ready() runs, so the Java share_received signal is emitted
	# into the void.  The plugin stores the payload in lastReceivedData; retrieve it here
	# and re-emit the GDScript signal.
	#
	# call_deferred postpones the emission by one frame so that parent nodes' _ready()
	# callbacks (and their @onready variable assignments) have all completed before any
	# share_received handler tries to access scene nodes.
	var __pending: ReceivedSharedData = get_received_data()
	if __pending != null:
		call_deferred(&"_emit_share_received_deferred", __pending)


func _notification(a_what: int) -> void:
	if a_what == NOTIFICATION_APPLICATION_RESUMED:
		_update_plugin()
		# On iOS, UIScene.openURLContexts is populated before the app resumes.
		# However, security-scoped files (from the Files app) can delay URL delivery
		# by a few milliseconds. We delay our check slightly to ensure it arrives.
		if OS.has_feature("ios"):
			print("iOS app resumed! Waiting for potential URL contexts...")
			get_tree().create_timer(0.2).timeout.connect(_check_ios_pending_data)


# Add this new helper function below _notification:
func _check_ios_pending_data() -> void:
	var __pending: ReceivedSharedData = get_received_data()
	if __pending != null:
		print("iOS app resumed with data!!")
		call_deferred(&"_emit_share_received_deferred", __pending)


func _update_plugin() -> void:
	if _plugin_singleton == null:
		if Engine.has_singleton(PLUGIN_SINGLETON_NAME):
			_plugin_singleton = Engine.get_singleton(PLUGIN_SINGLETON_NAME)
			_connect_signals()
		elif not OS.has_feature("editor_hint"):
			GmpLogger.log_error("%s singleton not found!" % PLUGIN_SINGLETON_NAME)


func _connect_signals() -> void:
	_plugin_singleton.connect(SIGNAL_NAME_SHARE_COMPLETED, _on_share_completed)
	_plugin_singleton.connect(SIGNAL_NAME_SHARE_FAILED, _on_share_failed)
	_plugin_singleton.connect(SIGNAL_NAME_SHARE_CANCELED, _on_share_canceled)
	_plugin_singleton.connect(SIGNAL_NAME_SHARE_RECEIVED, _on_share_received)


# ==============================================================================
# Outgoing share API (unchanged)
# ==============================================================================


## Shares plain text via Android's system share sheet.
func share_text(a_title: String, a_subject: String, a_content: String) -> void:
	if _plugin_singleton != null:
		_plugin_singleton.share(
			(
				SharedData
				. new()
				. set_title(a_title)
				. set_subject(a_subject)
				. set_content(a_content)
				. set_mime_type(MIME_TYPE_TEXT)
				. get_raw_data()
			)
		)
	else:
		GmpLogger.log_error("%s plugin not initialized" % PLUGIN_SINGLETON_NAME)


## Shares an image file (by path) via Android's system share sheet.
func share_image(a_path: String, a_title: String, a_subject: String, a_content: String) -> void:
	share_file(a_path, MIME_TYPE_IMAGE, a_title, a_subject, a_content)


## Renders [param a_texture] to a temporary PNG and shares it via Android's share sheet.
func share_texture(a_texture: Texture2D, a_title: String, a_subject: String, a_content: String) -> void:
	var __image: Image = a_texture.get_image()
	__image.save_png(_temp_image_path)
	share_file(_temp_image_path, MIME_TYPE_IMAGE, a_title, a_subject, a_content)


## Renders [param a_viewport]'s current frame to a temporary PNG and shares it.
func share_viewport(
	a_viewport: Viewport, a_title: String, a_subject: String, a_content: String, a_flip_y: bool = false
) -> void:
	var __image: Image = a_viewport.get_texture().get_image()
	if a_flip_y:
		__image.flip_y()
	__image.save_png(_temp_image_path)
	share_file(_temp_image_path, MIME_TYPE_IMAGE, a_title, a_subject, a_content)


## Shares a file at [param a_path] with the given MIME type via Android's share sheet.
func share_file(a_path: String, a_mime_type: String, a_title: String, a_subject: String, a_content: String) -> void:
	if _plugin_singleton != null:
		_plugin_singleton.share(
			(
				SharedData
				. new()
				. set_title(a_title)
				. set_subject(a_subject)
				. set_content(a_content)
				. set_mime_type(a_mime_type)
				. set_file_path(a_path)
				. get_raw_data()
			)
		)
	else:
		GmpLogger.log_error("%s plugin not initialized" % PLUGIN_SINGLETON_NAME)


# ==============================================================================
# Share-target API (new)
# ==============================================================================


## Registers or unregisters this app as a share-target in Android's share sheet.[br][br]
## Internally toggles the [code]ShareTargetAlias[/code] [code]activity-alias[/code] component
## declared in the app manifest (injected automatically by the export plugin).[br][br]
## The change takes effect for share dialogs opened [i]after[/i] this call.
## Persist the user preference across launches and call this method on startup.[br][br]
## [b]Example[/b] – persist the preference in a settings save:[br]
## [codeblock]
## func _on_share_target_toggled(enabled: bool) -> void:
##     $Share.set_share_target(enabled)
##     save_setting("share_target_enabled", enabled)
##
## func _ready() -> void:
##     $Share.set_share_target(load_setting("share_target_enabled", false))
## [/codeblock]
func set_share_target(a_enabled: bool) -> void:
	if _plugin_singleton != null:
		_plugin_singleton.set_share_target(a_enabled)
	else:
		GmpLogger.log_error("%s plugin not initialized" % PLUGIN_SINGLETON_NAME)


## Returns [code]true[/code] when this app is currently registered as a share-target
## (i.e. [code]ShareTargetAlias[/code] component is explicitly enabled).
func is_share_target() -> bool:
	if _plugin_singleton != null:
		return _plugin_singleton.is_share_target()
	return false


## Consumes and returns the most recently received share payload as a [ReceivedSharedData],
## or [code]null[/code] when no share has been received since the last call.[br][br]
## [b]You do not normally need to call this directly.[/b] [method _ready] retrieves and
## defers any pending cold-start data automatically via [signal share_received].[br][br]
## Call this explicitly only if you need the payload before the deferred emission fires,
## or as an alternative to connecting [signal share_received].
func get_received_data() -> ReceivedSharedData:
	if _plugin_singleton != null:
		var raw: Dictionary = _plugin_singleton.get_received_data()
		if not raw.is_empty():
			return ReceivedSharedData.new(raw)
	return null


# ==============================================================================
# Private helpers
# ==============================================================================


## Called one frame after [method _ready] when a pending cold-start share is detected.
## The one-frame deferral guarantees that parent nodes' [code]_ready()[/code] has run
## and all [code]@onready[/code] variables are initialised before any handler fires.
func _emit_share_received_deferred(a_data: ReceivedSharedData) -> void:
	emit_signal(SIGNAL_NAME_SHARE_RECEIVED, a_data)


# Private signal handlers
# ==============================================================================


func _on_share_completed(a_activity_type: String) -> void:
	emit_signal(SIGNAL_NAME_SHARE_COMPLETED, a_activity_type)


func _on_share_failed(a_error_message: String) -> void:
	emit_signal(SIGNAL_NAME_SHARE_FAILED, a_error_message)


func _on_share_canceled() -> void:
	emit_signal(SIGNAL_NAME_SHARE_CANCELED)


func _on_share_received(a_data: Dictionary) -> void:
	emit_signal(SIGNAL_NAME_SHARE_RECEIVED, ReceivedSharedData.new(a_data))
