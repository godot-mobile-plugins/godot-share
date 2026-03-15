#
# © 2024-present https://github.com/cengiz-pz
#

extends Node

@export var shared_title: String = "My Title"
@export var shared_subject: String = "My Subject"

@onready var share: Share = $Share as Share
@onready var _text_edit: TextEdit = $CanvasLayer/CenterContainer/VBoxContainer/VBoxContainer/TextEdit as TextEdit
@onready var _label: RichTextLabel = $CanvasLayer/CenterContainer/VBoxContainer/RichTextLabel as RichTextLabel
@onready var _android_texture_rect := %AndroidTextureRect as TextureRect
@onready var _ios_texture_rect := %iOSTextureRect as TextureRect

var _active_texture_rect: TextureRect


func _ready() -> void:
	if OS.has_feature("ios"):
		_android_texture_rect.hide()
		_active_texture_rect = _ios_texture_rect
	else:
		_ios_texture_rect.hide()
		_active_texture_rect = _android_texture_rect


func _on_share_texture_button_pressed() -> void:
	_print_to_screen("Sharing texture")
	share.share_texture(_active_texture_rect.texture, shared_title, shared_subject, _text_edit.text)


func _on_share_viewport_button_pressed() -> void:
	_print_to_screen("Sharing viewport")
	share.share_viewport(get_viewport(), shared_title, shared_subject, _text_edit.text)


func _on_share_share_completed(a_activity_type: String) -> void:
	_print_to_screen("Share completed by %s" % a_activity_type)


func _on_share_share_canceled() -> void:
	_print_to_screen("Share canceled")


func _on_share_share_failed(a_error_message: String) -> void:
	_print_to_screen("Share failed due to %s" % a_error_message)


func _print_to_screen(a_message: String, a_is_error: bool = false) -> void:
	_label.add_text("%s\n\n" % a_message)
	if a_is_error:
		printerr(a_message)
	else:
		print(a_message)
