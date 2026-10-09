extends Control
## Multi-touch-safe joystick: owns only the touch that began inside it.
## Other fingers are free to rotate camera or press HUD buttons.

var value := Vector2.ZERO
var _touch_index := -1
var _mouse_held := false
var _active := false
var _radius := 72.0
var _center := Vector2(110, 110)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_center = size * 0.5
	_radius = minf(size.x, size.y) * 0.36

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_center = size * 0.5
		_radius = minf(size.x, size.y) * 0.36
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_active = true
			_set_value(event.position)
			accept_event()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_active = false
			value = Vector2.ZERO
			queue_redraw()
			accept_event()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_set_value(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_held = event.pressed
		_active = _mouse_held
		if _mouse_held:
			_set_value(event.position)
		else:
			value = Vector2.ZERO
			queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and _mouse_held:
		_set_value(event.position)
		accept_event()

func _set_value(local_pos: Vector2) -> void:
	value = ((local_pos - _center) / _radius).limit_length(1.0)
	if value.length() < 0.12:
		value = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	var outer := Color("0c2344")
	outer.a = 0.62
	var rim := Color("8bd5fb")
	rim.a = 0.5
	var inner := Color("7ddaf3") if _active else Color("a9cde5")
	inner.a = 0.85 if _active else 0.57
	draw_circle(_center, _radius * 1.2, outer)
	draw_arc(_center, _radius * 1.2, 0.0, TAU, 54, rim, 3.0, true)
	draw_circle(_center, _radius * 0.91, Color(0.1, 0.24, 0.4, 0.38))
	var knob_at := _center + value * _radius
	draw_circle(knob_at, _radius * 0.41, Color(0.04, 0.18, 0.31, 0.95))
	draw_circle(knob_at, _radius * 0.29, inner)
