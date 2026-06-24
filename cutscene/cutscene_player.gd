extends Node
# =============================================================================
# CutscenePlayer — Data-driven sequential timeline engine
#
# Usage:
#   var player = CutscenePlayer.new()
#   add_child(player)
#   player.setup(image_rect, overlay_rect, char_left, char_right, dialogue_panel, dialogue_label)
#   player.play_timeline(timeline_array)
#   await player.finished
#
# Supported action types (Dictionary with "action" key):
#   show_image   { path, duration, zoom }
#   fade_out     { duration }
#   fade_in      { duration }
#   show_char    { path, side: "left"|"right", duration }
#   hide_char    { side: "left"|"right" }
#   show_dialogue { text_th, text_en, speaker }
#   hide_dialogue {}
#   wait         { duration }
#   play_sfx     { sfx_name }
#   play_music   { music_name }
#   stop_music   {}
# =============================================================================

signal finished
signal action_completed(index: int)

# --- Node references (set via setup()) ---
var _image_rect: TextureRect        = null  # Main image display
var _overlay: ColorRect             = null  # Black fade overlay
var _char_left: TextureRect         = null  # Left character sprite
var _char_right: TextureRect        = null  # Right character sprite
var _dialogue_panel: PanelContainer = null  # Dialogue box container
var _dialogue_label: RichTextLabel  = null  # Dialogue text label
var _speaker_label: Label           = null  # Speaker name label

var _timeline: Array[Dictionary] = []
var _current_index: int = 0
var _is_playing: bool = false

var _action_timer: Timer
var _current_tween: Tween

func setup(
	image_rect: TextureRect,
	overlay: ColorRect,
	char_left: TextureRect,
	char_right: TextureRect,
	dialogue_panel: PanelContainer,
	dialogue_label: RichTextLabel,
	speaker_label: Label = null
) -> void:
	_image_rect    = image_rect
	_overlay       = overlay
	_char_left     = char_left
	_char_right    = char_right
	_dialogue_panel = dialogue_panel
	_dialogue_label = dialogue_label
	_speaker_label  = speaker_label
	
	if not _action_timer:
		_action_timer = Timer.new()
		_action_timer.one_shot = true
		add_child(_action_timer)

func play_timeline(timeline: Array[Dictionary]) -> void:
	_timeline = timeline
	_current_index = 0
	_is_playing = true
	_run()

func request_skip() -> void:
	Engine.time_scale = 100.0

func _run() -> void:
	for i in _timeline.size():
		_current_index = i
		Engine.time_scale = 1.0
		await _execute(_timeline[i])
		action_completed.emit(i)
	_is_playing = false
	Engine.time_scale = 1.0
	finished.emit()

func _interruptible_wait(duration: float) -> void:
	if duration <= 0: return
	await get_tree().create_timer(duration).timeout

# ─────────────────────────────────────────────────────────────
func _execute(action: Dictionary) -> void:
	var type: String = action.get("action", "wait")
	match type:
		"show_image":
			await _do_show_image(action)
		"crossfade_image":
			await _do_crossfade_image(action)
		"brush_wipe_image":
			await _do_brush_wipe_image(action)
		"fade_out":
			await _do_fade(_overlay, 0.0, 1.0, action.get("duration", 0.5))
		"fade_in":
			await _do_fade(_overlay, 1.0, 0.0, action.get("duration", 0.5))
		"show_char":
			await _do_show_char(action)
		"hide_char":
			_do_hide_char(action.get("side", "left"))
		"show_dialogue":
			_do_show_dialogue(action)
		"hide_dialogue":
			if _dialogue_panel:
				_dialogue_panel.visible = false
			if _speaker_label and _speaker_label.get_parent() != _dialogue_panel:
				_speaker_label.visible = false
		"wait":
			await _interruptible_wait(action.get("duration", 1.0))
		"play_sfx":
			AudioManager.play_sfx(action.get("sfx_name", ""))
		"play_music":
			AudioManager.play_music_by_name(action.get("music_name", ""))
		"stop_music":
			AudioManager.stop_music()

# ─────────────────────────────────────────────────────────────
# Show image with optional zoom tween, then wait duration
func _do_show_image(action: Dictionary) -> void:
	if not _image_rect:
		return
	var path: String = action.get("path", "")
	var duration: float = action.get("duration", 2.5)
	var zoom: float = action.get("zoom", 1.0)

	if ResourceLoader.exists(path):
		_image_rect.texture = load(path)
	_image_rect.scale = Vector2.ONE
	_image_rect.pivot_offset = _image_rect.size / 2.0
	_image_rect.visible = true

	if zoom > 1.0:
		_current_tween = create_tween()
		_current_tween.tween_property(_image_rect, "scale",
			Vector2(zoom, zoom), duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await _interruptible_wait(duration)
		_image_rect.scale = Vector2.ONE
	else:
		await _interruptible_wait(duration)

# ─────────────────────────────────────────────────────────────
# Crossfade to a new image with zoom
func _do_crossfade_image(action: Dictionary) -> void:
	if not _image_rect:
		return
	var path: String = action.get("path", "")
	var duration: float = action.get("duration", 2.5)
	var fade_time: float = action.get("fade_time", 1.0)
	var zoom: float = action.get("zoom", 1.0)

	var old_rect = TextureRect.new()
	old_rect.texture = _image_rect.texture
	old_rect.layout_mode = _image_rect.layout_mode
	old_rect.anchors_preset = _image_rect.anchors_preset
	old_rect.anchor_right = _image_rect.anchor_right
	old_rect.anchor_bottom = _image_rect.anchor_bottom
	old_rect.grow_horizontal = _image_rect.grow_horizontal
	old_rect.grow_vertical = _image_rect.grow_vertical
	old_rect.expand_mode = _image_rect.expand_mode
	old_rect.stretch_mode = _image_rect.stretch_mode
	old_rect.pivot_offset = _image_rect.pivot_offset
	old_rect.scale = _image_rect.scale
	
	_image_rect.get_parent().add_child(old_rect)
	_image_rect.get_parent().move_child(old_rect, _image_rect.get_index())
	
	if ResourceLoader.exists(path):
		_image_rect.texture = load(path)
	_image_rect.scale = Vector2.ONE
	_image_rect.modulate.a = 0.0
	
	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	_current_tween.tween_property(_image_rect, "modulate:a", 1.0, fade_time)
	if zoom > 1.0:
		_current_tween.tween_property(_image_rect, "scale", Vector2(zoom, zoom), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	_current_tween.tween_property(old_rect, "modulate:a", 0.0, fade_time)
	_current_tween.chain().tween_callback(old_rect.queue_free)
	
	await _interruptible_wait(duration)
	_image_rect.scale = Vector2.ONE

# ─────────────────────────────────────────────────────────────
# Brush wipe transition with shader and continuous zoom
func _do_brush_wipe_image(action: Dictionary) -> void:
	if not _image_rect:
		return
	var path: String = action.get("path", "")
	var duration: float = action.get("duration", 2.5)
	var fade_time: float = action.get("fade_time", 1.0)
	var zoom: float = action.get("zoom", 1.0)

	var old_rect = TextureRect.new()
	old_rect.texture = _image_rect.texture
	old_rect.layout_mode = _image_rect.layout_mode
	old_rect.anchors_preset = _image_rect.anchors_preset
	old_rect.anchor_right = _image_rect.anchor_right
	old_rect.anchor_bottom = _image_rect.anchor_bottom
	old_rect.grow_horizontal = _image_rect.grow_horizontal
	old_rect.grow_vertical = _image_rect.grow_vertical
	old_rect.expand_mode = _image_rect.expand_mode
	old_rect.stretch_mode = _image_rect.stretch_mode
	old_rect.pivot_offset = _image_rect.pivot_offset
	old_rect.scale = _image_rect.scale
	
	_image_rect.get_parent().add_child(old_rect)
	_image_rect.get_parent().move_child(old_rect, _image_rect.get_index())
	
	if ResourceLoader.exists(path):
		_image_rect.texture = load(path)
	_image_rect.scale = Vector2.ONE
	_image_rect.modulate.a = 1.0
	
	var mat = ShaderMaterial.new()
	mat.shader = load("res://cutscene/brush_wipe.gdshader")
	mat.set_shader_parameter("cutoff", 0.0)
	_image_rect.material = mat
	
	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	
	# Animate cutoff
	_current_tween.tween_method(func(val): if mat: mat.set_shader_parameter("cutoff", val), 0.0, 1.0, fade_time)
	
	if zoom > 1.0:
		_current_tween.tween_property(_image_rect, "scale", Vector2(zoom, zoom), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	# Keep old rect zooming seamlessly during transition
	var old_start_scale = old_rect.scale
	_current_tween.tween_property(old_rect, "scale", old_start_scale * 1.025, fade_time).set_trans(Tween.TRANS_LINEAR)
	
	_current_tween.chain().tween_callback(old_rect.queue_free)
	_current_tween.chain().tween_callback(func(): _image_rect.material = null)
	
	await _interruptible_wait(duration)
	_image_rect.scale = Vector2.ONE

# ─────────────────────────────────────────────────────────────
func _do_fade(target: ColorRect, from_alpha: float, to_alpha: float, duration: float) -> void:
	if not target:
		return
	target.visible = true
	target.color.a = from_alpha
	_current_tween = create_tween()
	_current_tween.tween_property(target, "color:a", to_alpha, duration).set_trans(Tween.TRANS_QUAD)
	await _current_tween.finished
	if to_alpha <= 0.0:
		target.visible = false

# ─────────────────────────────────────────────────────────────
func _do_show_char(action: Dictionary) -> void:
	var path: String = action.get("path", "")
	var side: String = action.get("side", "left")
	var duration: float = action.get("duration", 0.4)
	var target: TextureRect = _char_left if side == "left" else _char_right
	if not target:
		return
	if ResourceLoader.exists(path):
		target.texture = load(path)
	target.modulate.a = 0.0
	target.visible = true
	_current_tween = create_tween()
	_current_tween.tween_property(target, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_QUAD)
	await _current_tween.finished

func _do_hide_char(side: String) -> void:
	var target: TextureRect = _char_left if side == "left" else _char_right
	if not target:
		return
	_current_tween = create_tween()
	_current_tween.tween_property(target, "modulate:a", 0.0, 0.3)
	await _current_tween.finished
	target.visible = false

# ─────────────────────────────────────────────────────────────
func _do_show_dialogue(action: Dictionary) -> void:
	if not _dialogue_panel or not _dialogue_label:
		return
	var locale = LanguageManager.current_locale
	var text: String = action.get("text_" + locale, action.get("text_th", ""))
	_dialogue_label.text = text
	if _speaker_label:
		_speaker_label.text = action.get("speaker", "")
	
	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	
	if text != "":
		_dialogue_panel.visible = true
		_dialogue_panel.modulate.a = 0.0
		_current_tween.tween_property(_dialogue_panel, "modulate:a", 1.0, 0.25)
	else:
		_dialogue_panel.visible = false
	
	if _speaker_label and _speaker_label.get_parent() != _dialogue_panel:
		_speaker_label.visible = true
		_speaker_label.modulate.a = 0.0
		_current_tween.tween_property(_speaker_label, "modulate:a", 1.0, 0.25)
		
	await _current_tween.finished
