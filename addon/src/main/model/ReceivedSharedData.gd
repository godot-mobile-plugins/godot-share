#
# © 2024-present https://github.com/cengiz-pz
#

## Wraps the Dictionary payload emitted by the [code]share_received[/code] signal (or returned by
## [method Share.get_received_data]) into a typed, readable API.[br][br]
##
## [b]Dictionary keys[/b] (all present even when empty):[br]
## [code]mime_type[/code]  – MIME type string reported by the sender (e.g. [code]"image/jpeg"[/code]).[br]
## [code]text[/code]       – Plain-text content (EXTRA_TEXT), may be empty.[br]
## [code]subject[/code]    – Subject line (EXTRA_SUBJECT), may be empty.[br]
## [code]file_paths[/code] – [PackedStringArray] of absolute paths inside the app's cache directory
##                           where the received files have been copied.[br]
## [code]is_multiple[/code]– [code]true[/code] when the sender used ACTION_SEND_MULTIPLE.[br]
class_name ReceivedSharedData extends RefCounted

const KEY_MIME_TYPE := &"mime_type"
const KEY_TEXT := &"text"
const KEY_SUBJECT := &"subject"
const KEY_FILE_PATHS := &"file_paths"
const KEY_IS_MULTIPLE := &"is_multiple"

var _data: Dictionary


func _init(a_data: Dictionary) -> void:
	_data = a_data


## Returns the MIME type string reported by the sending app (e.g. [code]"text/plain"[/code],
## [code]"image/jpeg"[/code]). Empty string when the sender did not specify a type.
func get_mime_type() -> String:
	return str(_data.get(KEY_MIME_TYPE, ""))


## Returns the plain-text payload (Android's [code]EXTRA_TEXT[/code]).
## Empty string when no text was included in the share.
func get_text() -> String:
	return str(_data.get(KEY_TEXT, ""))


## Returns the subject line (Android's [code]EXTRA_SUBJECT[/code]).
## Empty string when no subject was included.
func get_subject() -> String:
	return str(_data.get(KEY_SUBJECT, ""))


## Returns the absolute filesystem paths of all files that were copied from the
## sender's content URIs into this app's cache directory ([code]getCacheDir()/share_received/[/code]).
## Empty array when no files were shared.
func get_file_paths() -> PackedStringArray:
	var raw = _data.get(KEY_FILE_PATHS, PackedStringArray())
	if raw is PackedStringArray:
		return raw as PackedStringArray
	return PackedStringArray()


## Returns [code]true[/code] when the sender used [code]ACTION_SEND_MULTIPLE[/code]
## (i.e. more than one file may be present in [method get_file_paths]).
func is_multiple() -> bool:
	return bool(_data.get(KEY_IS_MULTIPLE, false))


## Returns [code]true[/code] when the share includes a non-empty text payload.
func has_text() -> bool:
	return not get_text().is_empty()


## Returns [code]true[/code] when the share includes one or more files.
func has_files() -> bool:
	return not get_file_paths().is_empty()


## Returns the raw [Dictionary] as received from the Android plugin layer.
func get_raw_data() -> Dictionary:
	return _data
