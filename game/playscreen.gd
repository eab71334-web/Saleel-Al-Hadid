extends "res://game/mainmenu.gd"
# Game-mode picker styled like the main menu: 3D lobby behind, big gold-framed cards, arrow + START buttons.

const CardsS := preload("res://game/menucards.gd")

var cards
var on_pick: Callable
var on_back: Callable


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_vignette()
	get_child(get_child_count() - 1).queue_free()          # no side panel on this screen
	var tl := _lbl(self, "Choose your game", 58, GOLD, 12)
	tl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	tl.offset_left = -400
	tl.offset_right = 400
	tl.offset_top = 14
	tl.offset_bottom = 90
	tl.autowrap_mode = TextServer.AUTOWRAP_OFF
	tl.add_theme_color_override("font_shadow_color", Color(0.8, 0.35, 0.05, 0.6))
	tl.add_theme_constant_override("shadow_offset_y", 4)
	intro_items.append([tl, Vector2(0, -90)])
	cards = CardsS.new()
	cards.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cards.anchor_left = 0.1
	cards.anchor_right = 0.9
	cards.anchor_top = 0.15
	cards.anchor_bottom = 0.8
	cards.offset_left = 0
	cards.offset_right = 0
	cards.offset_top = 0
	cards.offset_bottom = 0
	cards.cards = [
		{"id": "battle", "title": "Solo Battle", "desc": "Command your army against the enemy", "art": "battle"},
		{"id": "kingdom", "title": "Solo Kingdom", "desc": "Build a castle city, then rule or conquer", "art": "kingdom"},
		{"id": "world", "title": "Open World", "desc": "Found your castle in a huge world and grow it", "art": "world", "beta": true},
	]
	cards.chosen.connect(func(id): _choose(String(id)))
	add_child(cards)
	intro_items.append([cards, Vector2(0, 80), 0.15])
	actions = {
		"start": func(): _choose(String(cards.cards[cards.cur].id)),
		"back": func(): on_back.call(),
		"prev": func(): cards.go(cards.cur - 1),
		"next": func(): cards.go(cards.cur + 1),
	}
	var lb := _mbtn("prev", "<", "", Vector2(70, 120), 52)
	lb.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	lb.offset_left = 18
	lb.offset_right = 88
	lb.offset_top = -60
	lb.offset_bottom = 60
	add_child(lb)
	var rb := _mbtn("next", ">", "", Vector2(70, 120), 52)
	rb.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	rb.offset_left = -88
	rb.offset_right = -18
	rb.offset_top = -60
	rb.offset_bottom = 60
	add_child(rb)
	var sb := _mbtn("start", "START", "sword", Vector2(360, 78), 38, true)
	sb.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	sb.offset_left = -180
	sb.offset_right = 180
	sb.offset_top = -100
	sb.offset_bottom = -22
	add_child(sb)
	var bb := _mbtn("back", "Back", "flag", Vector2(200, 58), 24)
	bb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bb.offset_left = 20
	bb.offset_right = 220
	bb.offset_top = -80
	bb.offset_bottom = -22
	add_child(bb)
	for b in [sb, bb]:
		intro_items.append([b, Vector2.ZERO, 0.3])
	_intro()


func _choose(id: String) -> void:
	if busy:
		return
	Snd.play(self, "confirm", -6.0)
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	busy = true
	var f := create_tween()
	f.tween_property(fade, "color:a", 1.0, 0.2)
	await f.finished
	busy = false
	on_pick.call(id)
