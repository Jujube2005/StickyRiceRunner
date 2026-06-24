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
signal custom_action(action: Dictionary)  # Emitted for app-specific actions

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
var _zoom_mat: ShaderMaterial = null  # Persistent zoom shader on _image_rect

# ─── Shader-based zoom helpers ───────────────────────────────
func _make_zoom_material() -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = load("res://cutscene/dolly_zoom.gdshader")
	m.set_shader_parameter("zoom", 1.0)
	return m

func _get_image_zoom() -> float:
	if _zoom_mat:
		return _zoom_mat.get_shader_parameter("zoom")
	return 1.0

func _set_image_zoom(val: float) -> void:
	if _zoom_mat:
		_zoom_mat.set_shader_parameter("zoom", val)

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

var _is_skipping: bool = false

func play_timeline(timeline: Array[Dictionary]) -> void:
	_timeline = timeline
	_current_index = 0
	_is_playing = true
	_is_skipping = false
	_run()

func request_skip() -> void:
	_is_skipping = true
	Engine.time_scale = 100.0

func _run() -> void:
	for i in _timeline.size():
		_current_index = i
		if not _is_skipping:
			Engine.time_scale = 1.0
		await _execute(_timeline[i])
		action_completed.emit(i)
	_is_playing = false
	_is_skipping = false
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
		# App-specific custom actions — emit signal and let the scene handle them
		"show_name_image", "hide_name_image":
			custom_action.emit(action)
			# Wait for the scene to finish the animation (1.2s max)
			await _interruptible_wait(action.get("duration", 1.2))

# ─────────────────────────────────────────────────────────────
# Show image with optional shader-based zoom (no scale, no pivot issues)
func _do_show_image(action: Dictionary) -> void:
	if not _image_rect:
		return
	var path: String = action.get("path", "")
	var duration: float = action.get("duration", 2.5)
	var zoom: float = action.get("zoom", 1.0)

	if ResourceLoader.exists(path):
		_image_rect.texture = load(path)
	_image_rect.visible = true

	# Apply / reuse zoom shader
	if not _zoom_mat:
		_zoom_mat = _make_zoom_material()
	_set_image_zoom(1.0)
	_image_rect.material = _zoom_mat

	if zoom > 1.0:
		_current_tween = create_tween()
		var set_z = func(v: float): _set_image_zoom(v)
		_current_tween.tween_method(set_z, 1.0, zoom, duration).set_trans(Tween.TRANS_LINEAR)
		await _interruptible_wait(duration)
		# Leave zoom at its current value — brush_wipe will read it
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
# Brush wipe transition with shader and continuous shader-based zoom
func _do_brush_wipe_image(action: Dictionary) -> void:
	if not _image_rect:
		return
	var path: String = action.get("path", "")
	var duration: float = action.get("duration", 2.5)
	var fade_time: float = action.get("fade_time", 1.0)
	var zoom: float = action.get("zoom", 1.0)

	# Snapshot the current zoom of the outgoing image
	var old_zoom = _get_image_zoom()

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
	# Give old_rect its own zoom shader at the current zoom value
	var old_zoom_mat = _make_zoom_material()
	old_zoom_mat.set_shader_parameter("zoom", old_zoom)
	old_rect.material = old_zoom_mat
	
	_image_rect.get_parent().add_child(old_rect)
	_image_rect.get_parent().move_child(old_rect, _image_rect.get_index())
	
	if ResourceLoader.exists(path):
		_image_rect.texture = load(path)
	_image_rect.modulate.a = 1.0
	
	# Set up combined brush-wipe + zoom shader on new image
	var wipe_mat = ShaderMaterial.new()
	wipe_mat.shader = load("res://cutscene/brush_wipe.gdshader")
	wipe_mat.set_shader_parameter("cutoff", 0.0)
	_image_rect.material = wipe_mat
	# Re-assign zoom_mat reference so _set_image_zoom works after wipe
	_zoom_mat = _make_zoom_material()
	_set_image_zoom(1.0)
	
	var sfx = AudioManager.play_sfx("Drawing")
	
	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	
	# Animate brush wipe cutoff
	var update_wipe = func(val: float):
		if wipe_mat:
			wipe_mat.set_shader_parameter("cutoff", val)
	_current_tween.tween_method(update_wipe, 0.0, 1.0, fade_time)
	
	# New image: shader dolly-in via wipe shader zoom param
	if zoom > 1.0:
		var set_new_z = func(v: float):
			if wipe_mat:
				wipe_mat.set_shader_parameter("zoom", v)
		_current_tween.tween_method(set_new_z, 1.0, zoom, duration).set_trans(Tween.TRANS_LINEAR)
	
	# Old image: continue its zoom during the wipe
	var old_end_zoom = old_zoom + (zoom - 1.0) * fade_time / duration
	var set_old_z = func(v: float):
		if old_zoom_mat:
			old_zoom_mat.set_shader_parameter("zoom", v)
	_current_tween.tween_method(set_old_z, old_zoom, old_end_zoom, fade_time)
	
	_current_tween.chain().tween_callback(old_rect.queue_free)
	_current_tween.chain().tween_callback(func():
		# After wipe: switch from wipe_mat to pure zoom_mat
		_image_rect.material = _zoom_mat
		_set_image_zoom(_get_image_zoom() if wipe_mat == null else wipe_mat.get_shader_parameter("zoom"))
		
		# Fade out SFX when wipe finishes
		if is_instance_valid(sfx) and sfx.playing:
			var sfx_tween = create_tween()
			sfx_tween.tween_property(sfx, "volume_db", -60.0, 0.3)
			sfx_tween.tween_callback(sfx.queue_free)
	)
	
	await _interruptible_wait(duration)

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
