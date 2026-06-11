extends PanelContainer
## Stub — ersätts i Task 11 med full receptpanel.

func _ready() -> void:
	visible = false

func open(_station_type: String) -> void:
	visible = true
