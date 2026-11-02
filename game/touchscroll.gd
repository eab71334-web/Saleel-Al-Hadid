extends Node
# Touch-drag scrolling with momentum for every ScrollContainer (no white scrollbars).
# Attached automatically through SceneTree.node_added (see install()).

const DEAD := 14.0
var sc: ScrollContainer
var _down := false
var _drag := false
var _p0 := Vector2.ZERO
var _s0 := Vector2.ZERO
var _vel := Vector2.ZERO
var _last := Vector2.ZERO
static var _hooked := false


static func install(tree: SceneTree) -> void:
	if _hooked:
		return
	_hooked = true
	tree.node_added.connect(func(n: Node):
		if n is ScrollContainer and not n.has_node("TouchScroll"):
			var t: Node = load("res://game/touchscroll.gd").new()
			t.name = "TouchScroll"
			n.add_child.call_deferred(t))


func _ready() -> void:
	sc = get_parent() as ScrollContainer
	if sc == null:
		queue_free()
		return
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED else ScrollContainer.SCROLL_MODE_DISABLED
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED else ScrollContainer.SCROLL_MODE_DISABLED
	sc.get_v_scroll_bar().modulate.a = 0.0
	sc.get_h_scroll_bar().modulate.a = 0.0
	set_process(false)


func _input(e: InputEvent) -> void:
	if sc == null or not sc.is_visible_in_tree():
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			if sc.get_global_rect().has_point(e.position):
				_down = true
				_drag = false
				_p0 = e.position
				_last = e.position
				_s0 = Vector2(sc.scroll_horizontal, sc.scroll_vertical)
				_vel = Vector2.ZERO
				set_process(false)
		elif _down:
			_down = false
			if _drag:
				get_viewport().set_input_as_handled()
				set_process(true)
			_drag = false
	elif e is InputEventMouseMotion and _down:
		var d: Vector2 = e.position - _p0
		if not _drag and d.length() > DEAD:
			_drag = true
			# tell the button under the finger the press left it (so it won't click)
			var cancel := InputEventMouseMotion.new()
			cancel.position = Vector2(-9000, -9000)
			cancel.global_position = cancel.position
			Input.parse_input_event(cancel)
		if _drag:
			get_viewport().set_input_as_handled()
			if sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				sc.scroll_vertical = int(_s0.y - d.y)
			if sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				sc.scroll_horizontal = int(_s0.x - d.x)
			_vel = (e.position - _last) / maxf(get_process_delta_time(), 0.008)
			_last = e.position


func _process(dt: float) -> void:
	_vel *= pow(0.04, dt)
	if _vel.length() < 20.0:
		set_process(false)
		return
	if sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		sc.scroll_vertical -= int(_vel.y * dt)
	if sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		sc.scroll_horizontal -= int(_vel.x * dt)
