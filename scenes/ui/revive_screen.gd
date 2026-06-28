extends Control

signal accepted
signal skipped

@onready var timer_label = $Dialog/TimerLabel
@onready var btn_revive = $Dialog/BtnArea/BtnRevive
@onready var btn_skip = $Dialog/BtnArea/BtnSkip

func _ready():
	# Wire up button signals
	btn_revive.pressed.connect(func(): accepted.emit())
	btn_skip.pressed.connect(func(): skipped.emit())

func setup(can_afford: bool):
	if not is_node_ready():
		await ready
	btn_revive.disabled = !can_afford

func set_time(time_left: float):
	if is_instance_valid(timer_label):
		timer_label.text = "%.1f" % time_left
