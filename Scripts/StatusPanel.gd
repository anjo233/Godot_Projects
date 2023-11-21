extends HBoxContainer

@export var stats: Stats

@onready var health_bar: TextureProgressBar = $HealthBar
@onready var ease_health_bar: TextureProgressBar = $HealthBar/EaseHealthBar


func _ready() -> void:
	#将health_changed（血量变化）信号连接至update_health（更新血条）函数
	stats.health_changed.connect(update_health)
	update_health()

func  update_health() -> void:
	var percentage := stats.health / float(stats.max_health)
	health_bar.value = percentage
	
	#补间动画对象
	create_tween().tween_property(ease_health_bar, "value", percentage, 0.3)
