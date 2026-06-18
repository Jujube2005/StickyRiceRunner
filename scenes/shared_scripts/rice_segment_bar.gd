@tool
extends HBoxContainer

# =============================================================================
# RiceSegmentBar — Segmented kratip-milestone progress bar.
#
# Usage (runtime):
#   rice_bar.set_value(player.kratip_milestone_count)
#
# Usage (Editor):
#   Attach this script to an HBoxContainer, then tweak exports freely.
#   Changes rebuild the segments in real-time thanks to @tool.
# =============================================================================

## Number of segments (columns). Change in Editor — rebuilds instantly.
@export var segment_count: int = 10 :
	set(v):
		segment_count = v
		if is_node_ready():
			build_segments()

## Texture shown on a FILLED segment. (e.g. rice_bar_orange.png)
@export var tex_on: Texture2D :
	set(v):
		tex_on = v
		if is_node_ready():
			_refresh_textures()

## Texture shown on an EMPTY segment. Leave blank to use a dark tinted panel.
@export var tex_off: Texture2D :
	set(v):
		tex_off = v
		if is_node_ready():
			_refresh_textures()

## Pixel size of each segment cell.
@export var segment_size: Vector2 = Vector2(18, 36) :
	set(v):
		segment_size = v
		if is_node_ready():
			build_segments()

## Pixel gap between segments (maps to HBoxContainer separation theme constant).
@export var gap: int = 3 :
	set(v):
		gap = v
		if is_node_ready():
			add_theme_constant_override("separation", gap)

## Modulate applied to a filled segment.
@export var color_on: Color = Color(1.0, 1.0, 1.0, 1.0) :
	set(v):
		color_on = v
		if is_node_ready():
			_refresh_visuals()

## Modulate applied to an empty segment.
@export var color_off: Color = Color(0.25, 0.25, 0.25, 0.55) :
	set(v):
		color_off = v
		if is_node_ready():
			_refresh_visuals()

## When true, a filled segment plays a pop-scale tween on activation.
@export var animate_fill: bool = true

## Corner radius passed to StyleBoxFlat used as segment background.
## Only visible when tex_off is not set.
@export var segment_corner_radius: int = 8 :
	set(v):
		segment_corner_radius = v
		if is_node_ready():
			build_segments()

## Target scale on the pop animation when a segment becomes filled.
@export var filled_scale: float = 1.1

# ── Internal state ──────────────────────────────────────────────────────────
var _segments: Array[Control] = []   # each entry is a Panel (bg) + TextureRect (icon)
var _current_value: int = 0
var _fill_tweens: Array[Tween] = []

# ────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_theme_constant_override("separation", gap)
	build_segments()

# ─────────────────────────────────────────────────────────────────────────────
## Clears all child segments and recreates them from scratch.
## Called automatically when exports change in Editor (@tool).
func build_segments() -> void:
	# Stop any running tweens to avoid dangling references
	for tw in _fill_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_fill_tweens.clear()

	# Remove existing children
	for child in get_children():
		child.queue_free()
	_segments.clear()

	add_theme_constant_override("separation", gap)

	for i in range(segment_count):
		var cell := _make_cell()
		add_child(cell)
		_segments.append(cell)

	# Restore visual state (important in @tool preview)
	_refresh_visuals()

# ─────────────────────────────────────────────────────────────────────────────
## Call this whenever kratip_milestone_count changes.
## n = number of filled segments (0 … segment_count).
func set_value(n: int) -> void:
	var prev := _current_value
	_current_value = clamp(n, 0, segment_count)

	for i in range(_segments.size()):
		var cell : Control = _segments[i]
		var icon : TextureRect = cell.get_node_or_null("Icon")
		var filled : bool = i < _current_value

		if filled:
			cell.modulate = color_on
			if icon:
				icon.texture = tex_on
				icon.modulate = color_on
			# Pop animation only when segment just became filled
			if animate_fill and i >= prev and i < _current_value and not Engine.is_editor_hint():
				_play_pop(cell, i)
		else:
			cell.modulate = color_off
			if icon:
				icon.texture = tex_off if tex_off else tex_on
				icon.modulate = color_off
			cell.scale = Vector2.ONE
			cell.pivot_offset = segment_size / 2.0

# ─────────────────────────────────────────────────────────────────────────────
# PRIVATE HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _make_cell() -> Control:
	# Plain container — background comes from the BarBackground TextureRect behind us.
	# Each cell is just a TextureRect; color_off modulate darkens it when empty.
	var cell := Control.new()
	cell.custom_minimum_size = segment_size
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.pivot_offset = segment_size / 2.0

	# Inner TextureRect for the segment image
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = tex_on
	cell.add_child(icon)

	return cell

func _refresh_textures() -> void:
	for i in range(_segments.size()):
		var icon : TextureRect = _segments[i].get_node_or_null("Icon")
		if not icon: continue
		var filled : bool = i < _current_value
		icon.texture = tex_on if (filled or not tex_off) else tex_off

func _refresh_visuals() -> void:
	for i in range(_segments.size()):
		var cell : Control = _segments[i]
		var icon : TextureRect = cell.get_node_or_null("Icon")
		var filled : bool = i < _current_value
		cell.modulate = color_on if filled else color_off
		cell.scale = Vector2.ONE
		cell.pivot_offset = segment_size / 2.0
		if icon:
			icon.texture = tex_on if (filled or not tex_off) else tex_off
			icon.modulate = color_on if filled else color_off

func _play_pop(cell: Control, index: int) -> void:
	cell.pivot_offset = segment_size / 2.0
	# Stagger each segment slightly
	var delay : float = index * 0.04

	var tw : Tween = create_tween()
	_fill_tweens.append(tw)
	tw.tween_interval(delay)
	tw.tween_property(cell, "scale", Vector2(filled_scale, filled_scale), 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(cell, "scale", Vector2(1.0, 1.0), 0.12) \
		.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
