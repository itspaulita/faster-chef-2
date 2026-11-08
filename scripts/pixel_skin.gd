extends Node
## Autoload "PixelSkin": gives every panel, banner and button the pixel look (see PixelUI) as
## it enters the scene, so scenes keep their normal editor styles and nothing has to be
## converted by hand. A control with the meta "no_pixel" is left alone.


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is Control and not node.has_meta("no_pixel"):
		_skin(node)


func _skin(control: Control) -> void:
	var changed := false
	for property in control.get_property_list():
		var name: String = property.name
		if not name.begins_with("theme_override_styles/"):
			continue
		var style_name := name.trim_prefix("theme_override_styles/")
		if control.has_theme_stylebox_override(style_name):
			var style := control.get_theme_stylebox(style_name)
			if style is StyleBoxFlat:
				control.add_theme_stylebox_override(style_name, PixelUI.from_flat(style))
				changed = true
	if control.theme:
		changed = _skin_theme(control.theme) or changed
	if changed:
		# Crisp edges: the little picture must never be smoothed when it is drawn.
		control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _skin_theme(theme: Theme) -> bool:
	var changed := false
	for type in theme.get_stylebox_type_list():
		for style_name in theme.get_stylebox_list(type):
			var style := theme.get_stylebox(style_name, type)
			if style is StyleBoxFlat:
				theme.set_stylebox(style_name, type, PixelUI.from_flat(style))
				changed = true
	return changed
