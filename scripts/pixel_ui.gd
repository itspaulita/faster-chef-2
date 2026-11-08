class_name PixelUI
extends RefCounted
## Gives panels, banners and buttons a pixel-art look: no smooth rounded corners, only chunky
## square "pixels" with stepped (notched) corners and a hard border. It turns an ordinary
## StyleBoxFlat (colors, border width, corner radius, margins) into a StyleBoxTexture drawn
## from a tiny generated picture, so the colors and sizes you set in the editor still apply.
## PixelSkin (the autoload) runs this on every panel and button in the game.

## Size of one pixel on screen.
const BLOCK := 4

static var _cache := {}


## A pixel panel from plain numbers (for styles built in code).
static func panel(bg: Color, border: Color, border_px := 6, radius := 16, margin := 6) -> StyleBox:
	var flat := StyleBoxFlat.new()
	flat.bg_color = bg
	flat.border_color = border
	flat.set_border_width_all(border_px)
	flat.set_corner_radius_all(radius)
	flat.set_content_margin_all(margin)
	return from_flat(flat)


static func from_flat(flat: StyleBoxFlat) -> StyleBox:
	var border_px := maxi(maxi(flat.border_width_left, flat.border_width_right), maxi(flat.border_width_top, flat.border_width_bottom))
	var radius := maxi(maxi(flat.corner_radius_top_left, flat.corner_radius_top_right), maxi(flat.corner_radius_bottom_left, flat.corner_radius_bottom_right))
	var k := 0 if border_px <= 0 else clampi(roundi(border_px / float(BLOCK)), 1, 3)   # border thickness in pixels
	var n := clampi(ceili(radius / 5.0), 0, 4)   # how many pixels each corner is cut
	if k + n == 0:
		var square := flat.duplicate() as StyleBoxFlat
		square.anti_aliasing = false
		return square
	var margins := [flat.get_margin(SIDE_LEFT), flat.get_margin(SIDE_TOP), flat.get_margin(SIDE_RIGHT), flat.get_margin(SIDE_BOTTOM)]
	var key := "%s|%s|%d|%d|%s" % [flat.bg_color, flat.border_color, k, n, margins]
	if not _cache.has(key):
		_cache[key] = _build(flat.bg_color, flat.border_color, k, n, margins)
	return _cache[key]


static func _build(bg: Color, border: Color, k: int, n: int, margins: Array) -> StyleBoxTexture:
	var c := k + n                 # corner size in pixels; the picture is 2c+1 pixels across
	var size := 2 * c + 1
	var inside := []               # inside[y][x]: is this pixel part of the shape
	for y in size:
		var row := []
		for x in size:
			var dx := mini(x, size - 1 - x)
			var dy := mini(y, size - 1 - y)
			row.append(dx + dy >= n)
		inside.append(row)
	# depth: 1 for pixels touching the outside, 2 for the next layer in, and so on.
	var depth := []
	for y in size:
		depth.append([])
		for x in size:
			depth[y].append(0)
	var frontier := []
	for y in size:
		for x in size:
			if inside[y][x] and _touches_outside(inside, x, y, size):
				depth[y][x] = 1
				frontier.append(Vector2i(x, y))
	var level := 1
	while not frontier.is_empty() and level < k:
		var next := []
		for cell in frontier:
			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = cell + step
				if p.x >= 0 and p.y >= 0 and p.x < size and p.y < size and inside[p.y][p.x] and depth[p.y][p.x] == 0:
					depth[p.y][p.x] = level + 1
					next.append(p)
		frontier = next
		level += 1
	var image := Image.create(size * BLOCK, size * BLOCK, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var color := Color(0, 0, 0, 0)
			if inside[y][x]:
				color = border if depth[y][x] > 0 and depth[y][x] <= k else bg
			image.fill_rect(Rect2i(x * BLOCK, y * BLOCK, BLOCK, BLOCK), color)
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	style.texture_margin_left = c * BLOCK
	style.texture_margin_top = c * BLOCK
	style.texture_margin_right = c * BLOCK
	style.texture_margin_bottom = c * BLOCK
	style.content_margin_left = margins[0]
	style.content_margin_top = margins[1]
	style.content_margin_right = margins[2]
	style.content_margin_bottom = margins[3]
	return style


static func _touches_outside(inside: Array, x: int, y: int, size: int) -> bool:
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var p: Vector2i = Vector2i(x, y) + step
		if p.x < 0 or p.y < 0 or p.x >= size or p.y >= size or not inside[p.y][p.x]:
			return true
	return false
