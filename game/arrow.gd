extends Node3D
# Flying arrow. live = true on the host (applies damage on landing), visual only on clients.

var battle
var from_p := Vector3.ZERO
var to_p := Vector3.ZERO
var dur := 1.0
var team := 0
var dmg := 10.0
var live := false
var _t := 0.0
var _arc := 1.0
var style := 0         # 0 arrow, 1 ballista bolt, 2 stone, 3 cannonball
var splash := 0.0


func _ready() -> void:
	var m := MeshInstance3D.new()
	if style >= 2:
		var sp := SphereMesh.new()
		sp.radius = 0.38 if style == 2 else 0.3
		sp.height = sp.radius * 2.0
		sp.radial_segments = 10
		sp.rings = 5
		m.mesh = sp
	else:
		var b := BoxMesh.new()
		b.size = Vector3(0.04, 0.04, 0.9) if style == 0 else Vector3(0.1, 0.1, 1.8)
		m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.8, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.3)
	mat.emission_energy_multiplier = 0.8
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	_arc = from_p.distance_to(to_p) * (0.16 if style < 2 else 0.4)
	position = from_p


func _pos_at(t: float) -> Vector3:
	var p := from_p.lerp(to_p, t)
	p.y += sin(t * PI) * _arc
	return p


func _process(dt: float) -> void:
	_t += dt / maxf(dur, 0.05)
	var p := _pos_at(minf(_t, 1.0))
	var nxt := _pos_at(minf(_t + 0.03, 1.0))
	position = p
	if nxt.distance_to(p) > 0.001:
		look_at(nxt, Vector3.UP)
	if _t >= 1.0:
		if live and battle:
			battle.arrow_land(self)
		queue_free()
