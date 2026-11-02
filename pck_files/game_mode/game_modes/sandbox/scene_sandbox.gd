extends SceneClassic

func _ready() -> void:
	super()
	Dev.on_cheat.emit()

func pregameover_condition_met() -> bool:
	return false
