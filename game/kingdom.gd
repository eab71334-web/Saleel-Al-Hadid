extends Node
# Kingdom mode: build a city, feed it, train soldiers, write letters, declare war,
# siege the enemy castle, and settle it in a duel of kings.
# Host-authoritative: the host simulates everything, clients get a small state
# dictionary 4 times a second plus a few reliable events.

const GATE_HALF := 4.8
const POSTERN_X := -24.0
const TownS := preload("res://game/town.gd")
const LocS := preload("res://game/loc.gd")
const ProfS := preload("res://game/profile.gd")
const MapS := preload("res://game/mapview.gd")
const CourtS := preload("res://game/court.gd")
const FortressS := preload("res://game/fortress.gd")

const START_GOLD := 120.0
const START_FOOD := 80.0
const VILLAGER_FOOD := 20
const BUY_GOLD := 30
const BUY_FOOD := 40
const BASE_CAP := 4
const HOUSE_CAP := 4
const TREE_MAX := 80.0
const TREES_PER_TEAM := 12
const CASTLE_HP := [2500.0, 3600.0, 5200.0]
const UPGRADE := [[150, 60], [320, 140]]
const REPAIR_COST := 70
# kind: [gold, food, seconds, castle level needed]
const TRAIN := {"sword": [30, 20, 4.0, 1], "archer": [40, 25, 5.0, 2], "cav": [90, 50, 7.0, 3],
	"ballista": [110, 40, 8.0, 2], "catapult": [170, 60, 10.0, 3]}
const TRAIN_X := {"sword": {"iron": 3}, "archer": {"wood": 4}, "cav": {"iron": 5}, "ballista": {"wood": 18, "iron": 4}, "catapult": {"wood": 26, "stone": 12, "iron": 4}}
const WOOD_START := 70.0
const STONE_START := 45.0
const IRON_START := 12.0
const YEAR := 480.0   # seconds per year, 4 seasons
const PLANK_GOLD := 40
const PLANK_WOOD := 20
const SHIP_GOLD := 100
const SHIP_WOOD := 40
const MAX_SHIPS := 3
const YARD_GOLD := 150
const YARD_WOOD := 60
const TRANSPORT_GOLD := 90
const TRANSPORT_WOOD := 45
const MAX_TRANSPORTS := 2
const FISHER_GOLD := 40
const FISHER_WOOD := 15
const MAX_FISHERS := 4
const WALL_Y := 6.8
const RAMP_X := 12.0
const SIEGE_MULT := 0.2
const FOOD_UPKEEP := 0.08
const LETTER_CD := 10.0
const MSG_SPEED := 15.0
const TOWER_RANGE := 30.0
const TOWER_DMG := 11.0
const DUEL_TRIGGER := 20.0
const DUEL_R0 := 9.5
const DUEL_R1 := 3.5
const DUEL_SHRINK := 45.0
const KING_RESPAWN := 15.0

var battle
var net
var is_srv := true
var my_team := 0
var king_trait := ""      # my ruler trait (solo only)
var king_diff := "normal"
var my_king_name := ""
var prog_t := 2.0

var nk := 2
var war_pairs := {}
var gold := [START_GOLD, START_GOLD]
var food := [START_FOOD, START_FOOD]
var level := [1, 1]
var castle_hp := [CASTLE_HP[0], CASTLE_HP[0]]
var fallen := [false, false]
var tree_pos := [[], []]
var tree_food := [[], []]
var pop_used := [0, 0]
var vill_n := [0, 0]
var soldier_n := [0, 0]
var wood := [0.0, 0.0]
var stone := [0.0, 0.0]
var iron := [0.0, 0.0]
var forge_w := [0, 0]   # weapon level per kingdom (0-3)
var forge_a := [0, 0]   # armour level per kingdom (0-3)
var grain := [0.0, 0.0]
var flour := [0.0, 0.0]
var year_t := 0.0
var ship_n := [0, 0]
var trn_n := [0, 0]
var fsh_n := [0, 0]
var yard := [false, false]
var queue := [[], []]
var letter_cd := [0.0, 0.0]
var decree_cd := [{"tax": 0.0, "feast": 0.0}, {"tax": 0.0, "feast": 0.0}]
const FEAST_FOOD := 40

var tree_nodes := [[], []]
var extras := [{}, {}]
var fires := [[], []]
var vis_ready := false
var gate_open := [false, false]
var post_open := [false, false]
var town: Node = null
var view_team := -1
var fortress: Node = null
var mapv: Node = null
var court: Node = null
var gate_t := 0.0

var msgs := {}
var next_msg := 1
var challenge_t := 0.0
var duel_t := 0.0
var duel_pair := [0, 1]
var duel_done := false
var clash = null
var final_team := -1
var duel_ring: MeshInstance3D = null
var respawn := {}
var ai_next := [0.0, 0.0]
var ai_info := [{}, {}]
var ai_replies := []
var inbox := []
var tower_cd := 1.0
var econ_t := 0.0
var state_t := 0.0
var ui_t := 0.0
var war_confirm := 0.0

var ui := {}


# ================================================================== helpers
func ang(t: int) -> float:
	return battle.ang(t)


func lw(t: int, v: Vector3) -> Vector3:
	return battle.lw(t, v)


func wl(t: int, p: Vector3) -> Vector3:
	return battle.wl(t, p)


func team_of(owner: int) -> int:
	if owner < 0:
		return -100 - owner
	var p: Dictionary = net.players.get(owner, {"idx": 0})
	return int(p.idx) % nk


func owner_of_team(t: int) -> int:
	for id in net.players.keys():
		if team_of(id) == t:
			return id
	return -100 - t


func pair_key(a: int, b: int) -> int:
	return mini(a, b) * 10 + maxi(a, b)


func at_war(a: int, b: int) -> bool:
	return war_pairs.has(pair_key(a, b))


func any_war() -> bool:
	return not war_pairs.is_empty()


func declare_war(a: int, b: int) -> void:
	war_pairs[pair_key(a, b)] = true
	battle.war = true


func alive_count() -> int:
	var n := 0
	for t in nk:
		if not fallen[t]:
			n += 1
	return n


# The kingdom team t would attack / talk to by default.
func foe_of(t: int) -> int:
	return battle.foe(t)


func target_castle(u) -> int:
	if u.strike_foe >= 0 and u.strike_foe != u.team and battle.hostile(u.team, u.strike_foe) and castle_alive(u.strike_foe):
		return u.strike_foe
	var ft: int = battle.foe(u.team)
	if ft >= 0 and ft != u.team and battle.hostile(u.team, ft) and castle_alive(ft):
		return ft
	return -1


func rank_of(t: int) -> String:
	var pts: int = level[t] * 3 + count_slots(t, 1) + soldier_n[t] / 5 + int(gold[t] / 400.0)
	if pts < 5:
		return "Lord"
	if pts < 8:
		return "Baron"
	if pts < 11:
		return "Count"
	if pts < 15:
		return "Duke"
	if pts < 20:
		return "King"
	return "Emperor"


func king_name(t: int) -> String:
	for id in net.players.keys():
		if team_of(id) == t:
			return String(net.players[id].name)
	return "King of %s (AI)" % battle.team_name(t)


func fish_spot(t: int, id: int) -> Vector3:
	var sx: float = (float(id % 4) - 1.5) * 16.0
	var sz: float = float((id / 4) % 3) * 9.0
	var p: Vector3 = lw(t, Vector3(sx, 0.0, -(battle.coast_r - battle.ring_r + 73.0 + 24.0 + sz)))
	return battle.keep_on_sea(p)


# where new ships appear: on the water behind the castle's rear wall
func dock_pos(t: int) -> Vector3:
	return lw(t, Vector3(0.0, 0.0, -(battle.coast_r - battle.ring_r + 73.0 + 8.0)))


# ---- wall walk and stairs ----
func has_wall(t: int) -> bool:
	return not fallen[t]


# ground height for a unit standing at p (stairs rise toward the front wall, the wall walk is WALL_Y high)
func ground_y(t: int, p: Vector3) -> float:
	var l := wl(t, p)
	var d := -l.z
	var ax := absf(l.x)
	if d < 75.5 or d > 97.5 or ax > 34.0:
		return 0.0
	if absf(ax - RAMP_X) < 2.4 and d > 77.0:
		return WALL_Y * clampf((97.0 - d) / 19.0, 0.0, 1.0)
	if d <= 78.8 and ax > 6.0:
		return WALL_Y
	return 0.0


func wall_slot(t: int, uid: int) -> Vector3:
	var side := -1.0 if uid % 2 == 0 else 1.0
	var lx: float = side * (7.5 + float((uid * 7) % 24))
	if absf(absf(lx) - RAMP_X) < 2.0:
		lx += side * 3.0
	return lw(t, Vector3(lx, WALL_Y, -76.6))


# waypoint for climbing: up the stairs on the target's side, then along the wall walk
func wall_via(t: int, from: Vector3, slot: Vector3) -> Vector3:
	var lf := wl(t, from)
	var ls := wl(t, slot)
	var side := -1.0 if ls.x < 0.0 else 1.0
	if from.y > 3.2:
		return slot
	var df := -lf.z
	if df > 99.0 or absf(lf.x - side * RAMP_X) > 3.6:
		# get to the foot of the stairs first (through the gate if outside)
		var foot := lw(t, Vector3(side * RAMP_X, 0.0, -98.5))
		return via(t, from, foot)
	return lw(t, Vector3(side * RAMP_X, 0.0, -77.4))


func depot(t: int) -> Vector3:
	return lw(t, Vector3(0.0, 0.0, -86.0))


func home_pos(t: int) -> Vector3:
	return lw(t, Vector3(0.0, 0.0, -90.0))


func gate_in(t: int) -> Vector3:
	return lw(t, Vector3(0.0, 0.0, -76.0))


func gate_out(t: int) -> Vector3:
	return lw(t, Vector3(0.0, 0.0, -69.0))


# ---- walled city geometry (depth = metres behind the front wall line, positive = inside) ----
func depth(t: int, p: Vector3) -> float:
	return -wl(t, p).z


func inside(t: int, p: Vector3) -> bool:
	var l := wl(t, p)
	var d := -l.z
	return absf(l.x) < 34.4 and d > 74.5 and d < 120.0


func inside_any(p: Vector3) -> bool:
	for t in nk:
		if inside(t, p):
			return true
	return false


func _solid(t: int, p: Vector3) -> bool:
	var l := wl(t, p)
	var d := -l.z
	var ax := absf(l.x)
	# throne hall walls (door gap in the middle of the front wall)
	if d > 103.8 and d < 119.2 and ax < 11.2:
		if d < 105.2 and ax > 2.4:
			return true
		if ax > 9.8:
			return true
		if d > 117.8:
			return true
	# buildings are solid
	if town != null and town.solid(t, l):
		return true
	if d > 71.4 and d < 74.6 and ax < 37.5:
		if ax < GATE_HALF and gate_open[t]:
			return false
		return true
	if ax > 34.4 and ax < 37.6 and d >= 74.6 and d < 121.5:
		return true
	if d > 119.8 and d < 122.8 and ax < 37.5:
		if absf(l.x - POSTERN_X) < 2.4 and post_open[t]:
			return false
		return true
	return false


# Walls stop units (except through the open gate). Called after every step of a unit.
func constrain(u, oldp: Vector3) -> void:
	if u.is_ship:
		return
	var gy := 0.0
	for t2 in nk:
		if not fallen[t2]:
			gy = maxf(gy, ground_y(t2, u.position))
	if gy > 3.0 and oldp.y < 2.0:
		u.position = oldp        # the wall walk can only be entered by the stairs
		return
	u.position.y = move_toward(oldp.y, gy, 9.0 * u._dt)
	for t in nk:
		if fallen[t]:
			continue
		var p: Vector3 = u.position
		if p.length() < battle.ring_r - 8.0:
			continue
		if _solid(t, p):
			var a := Vector3(p.x, p.y, oldp.z)
			var b := Vector3(oldp.x, p.y, p.z)
			if not _solid(t, a):
				u.position = a
			elif not _solid(t, b):
				u.position = b
			elif not _solid(t, oldp):
				u.position = oldp
			# else: already inside a freshly built house - let it walk out


func postern_in(t: int) -> Vector3:
	return lw(t, Vector3(POSTERN_X, 0.0, -117.5))


func postern_out(t: int) -> Vector3:
	return lw(t, Vector3(POSTERN_X, 0.0, -126.5))


# 0 = open ground in front of the castle, 1 = inside the walls, 2 = land behind the castle
func zone(t: int, p: Vector3) -> int:
	var l := wl(t, p)
	var d := -l.z
	if absf(l.x) < 34.4 and d > 74.5 and d < 121.0:
		return 1
	if d >= 121.0 and absf(l.x) < 80.0:
		return 2
	return 0


# Next waypoint for a unit of team t that wants to reach `to` (goes through the gates).
func via(t: int, from: Vector3, to: Vector3) -> Vector3:
	if fallen[t]:
		return to
	var fz := zone(t, from)
	var tz := zone(t, to)
	if fz == tz:
		return to
	if fz == 2:
		var po := postern_out(t)
		if depth(t, from) > 124.0 and Vector2(from.x - po.x, from.z - po.z).length() > 2.5:
			return po
		return postern_in(t)
	if tz == 2:
		if fz == 0:
			return via(t, from, postern_in(t))
		var pi := postern_in(t)
		if Vector2(from.x - pi.x, from.z - pi.z).length() > 2.5 and depth(t, from) < 118.5:
			return pi
		return postern_out(t)
	var fi := fz == 1
	var df := depth(t, from)
	if fi:
		if Vector2(from.x - gate_in(t).x, from.z - gate_in(t).z).length() > 3.0:
			return gate_in(t)
		return gate_out(t)
	if df < 71.4 and Vector2(from.x - gate_out(t).x, from.z - gate_out(t).z).length() > 3.0:
		return gate_out(t)
	return gate_in(t)


func _update_gates() -> void:
	for t in nk:
		var open := false
		if fallen[t]:
			open = true
		else:
			var gp: Vector3 = lw(t, Vector3(0, 0, -73.0))
			for u in battle.units.values():
				if u.team == t and not u.dead and Vector2(u.position.x - gp.x, u.position.z - gp.z).length() < 9.5:
					open = true
					break
		if battle.intro and t == my_team:
			open = true
		if open != gate_open[t]:
			battle.sfx.play("gate", lw(t, Vector3(0, 4.0, -73.0)), 4.0, 1.0)
		gate_open[t] = open
		var po := false
		if fallen[t]:
			po = true
		else:
			var pp: Vector3 = lw(t, Vector3(POSTERN_X, 0, -121.0))
			for u in battle.units.values():
				if u.team == t and not u.dead and Vector2(u.position.x - pp.x, u.position.z - pp.z).length() < 6.5:
					po = true
					break
		post_open[t] = po
		var ex: Dictionary = extras[t]
		if ex.has("post") and ex.post != null:
			ex.post.visible = not po


func castle_gate(t: int) -> Vector3:
	return lw(t, Vector3(0.0, 0.0, -70.0))


func castle_alive(t: int) -> bool:
	return not fallen[t] and castle_hp[t] > 0.0


func count_slots(t: int, typ: int) -> int:
	# 1 = houses, 2 = barracks (kept for older callers)
	if town == null:
		return 0
	return town.count(t, "house" if typ == 1 else "barracks")


func pop_cap(t: int) -> int:
	return BASE_CAP + HOUSE_CAP * count_slots(t, 1) + (4 if trait_has(t, "pious") else 0)


# ---- materials
func res_get(t: int, key: String) -> float:
	match key:
		"gold":
			return gold[t]
		"food":
			return food[t]
		"wood":
			return wood[t]
		"stone":
			return stone[t]
		"iron":
			return iron[t]
		"grain":
			return grain[t]
		"flour":
			return flour[t]
	return 0.0


func res_add(t: int, key: String, v: float) -> void:
	match key:
		"gold":
			gold[t] = maxf(0.0, gold[t] + v)
		"food":
			food[t] = maxf(0.0, food[t] + v)
		"wood":
			wood[t] = maxf(0.0, wood[t] + v)
		"stone":
			stone[t] = maxf(0.0, stone[t] + v)
		"iron":
			iron[t] = maxf(0.0, iron[t] + v)
		"grain":
			grain[t] = maxf(0.0, grain[t] + v)
		"flour":
			flour[t] = maxf(0.0, flour[t] + v)


# 0 spring, 1 summer, 2 autumn, 3 winter
func season() -> int:
	return int(fmod(year_t, YEAR) / (YEAR * 0.25))


func season_farm() -> float:
	match season():
		0:
			return 0.9
		1:
			return 1.2
		2:
			return 1.4
	return 0.1


func season_name() -> String:
	return ["Spring", "Summer", "Autumn", "Winter"][season()]


func _extra_text(kind: String) -> String:
	var tx: Dictionary = TRAIN_X.get(kind, {})
	var s := ""
	for rk in tx.keys():
		s += " %d%s" % [int(tx[rk]), String(rk).substr(0, 1)]
	return s


func _extra_ok(t: int, kind: String) -> bool:
	var tx: Dictionary = TRAIN_X.get(kind, {})
	for rk in tx.keys():
		if res_get(t, String(rk)) < float(tx[rk]):
			return false
	return true


func train_block(t: int, kind: String) -> String:
	if town.count(t, "barracks") < 1:
		return "Build a barracks first!"
	if kind != "archer" and town.count(t, "smithy") < 1:
		return "Build a smithy first!"
	if kind == "cav" and town.count(t, "stable") < 1:
		return "Build a stable first!"
	return ""


const TRADE := {
	"wood": [20, 14, 30], "stone": [20, 22, 44], "iron": [10, 24, 70], "grain": [20, 10, 28]}   # lot, gold when selling, gold when buying


func _trade(t: int, human: bool, key: String, buy: bool) -> void:
	if town.count(t, "market") < 1:
		if human: toast_team(t, "Build a market first.")
		return
	if not TRADE.has(key):
		return
	var tr: Array = TRADE[key]
	if buy:
		if gold[t] < float(tr[2]):
			if human: toast_team(t, "Not enough gold!")
			return
		gold[t] -= float(tr[2])
		res_add(t, key, float(tr[0]))
	else:
		if res_get(t, key) < float(tr[0]):
			if human: toast_team(t, "Not enough materials")
			return
		res_add(t, key, -float(tr[0]))
		gold[t] += float(tr[1])
	if human and t == my_team:
		battle.sfx.play_ui("coin", -6.0)


func queued(t: int, kind: String) -> int:
	var n := 0
	for q in queue[t]:
		if q.kind == kind:
			n += 1
	return n


func has_arabic(s: String) -> bool:
	for i in s.length():
		var c := s.unicode_at(i)
		if c >= 0x0600 and c <= 0x06FF:
			return true
	return false


# ================================================================== setup
func setup() -> void:
	net = battle.net
	is_srv = battle.is_srv
	my_team = battle.my_team
	nk = battle.nk
	var kc: Dictionary = battle.cfg.get("king", {})
	if not kc.is_empty() and not net.online:
		king_trait = String(kc.get("trait", ""))
		king_diff = String(kc.get("diff", "normal"))
		my_king_name = String(kc.get("name", ""))
	gold = []; food = []; level = []; castle_hp = []; fallen = []; wood = []; stone = []; iron = []; grain = []; flour = []; forge_w = []; forge_a = []; ship_n = []; trn_n = []; fsh_n = []; yard = []
	tree_pos = []; tree_food = []; pop_used = []; vill_n = []; soldier_n = []; queue = []
	letter_cd = []; decree_cd = []
	tree_nodes = []; extras = []; fires = []; gate_open = []; post_open = []; ai_next = []; ai_info = []; march_cd = []
	for t in nk:
		gold.append(START_GOLD); food.append(START_FOOD); level.append(1); wood.append(WOOD_START); stone.append(STONE_START); iron.append(IRON_START); grain.append(0.0); flour.append(0.0); forge_w.append(0); forge_a.append(0); ship_n.append(0); trn_n.append(0); fsh_n.append(0); yard.append(false)
		castle_hp.append(CASTLE_HP[0]); fallen.append(false)
		tree_pos.append([]); tree_food.append([]); pop_used.append(0); vill_n.append(0); soldier_n.append(0)
		queue.append([]); letter_cd.append(0.0); decree_cd.append({"tax": 0.0, "feast": 0.0})
		tree_nodes.append([])
		extras.append({}); fires.append([]); gate_open.append(false); post_open.append(false); ai_next.append(0.0)
		ai_info.append({}); march_cd.append(0.0)
	_make_trees()
	town = TownS.new()
	town.name = "Town"
	add_child(town)
	town.setup()
	for t in nk:
		town.place(t, "house", -19.0, 88.0, true)
		town.place(t, "house", 19.0, 88.0, true)
	fortress = FortressS.new()
	fortress.name = "Fortress"
	fortress.kingdom = self
	fortress.battle = battle
	add_child(fortress)
	fortress.build()
	_refresh_visuals()
	vis_ready = true
	_build_ui()


func _make_trees() -> void:
	var trunk: StandardMaterial3D = battle._mat(Color(0.32, 0.21, 0.11))
	var leaf: StandardMaterial3D = battle._mat(Color(0.17, 0.42, 0.14))
	var fruit_mat: StandardMaterial3D = battle._mat(Color(0.95, 0.3, 0.12), 0.5, 0.0, 0.6)
	var tm: CylinderMesh = battle._cyl(0.25, 0.38, 2.2, 8)
	var sm := SphereMesh.new()
	sm.radius = 1.7
	sm.height = 3.0
	sm.radial_segments = 12
	sm.rings = 6
	var fm := SphereMesh.new()
	fm.radius = 0.2
	fm.height = 0.4
	fm.radial_segments = 6
	fm.rings = 3
	for t in nk:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7000 + t
		for i in TREES_PER_TEAM:
			var side := -1.0 if i % 2 == 0 else 1.0
			var x := side * (rng.randf_range(46.0, 68.0) if nk <= 4 else rng.randf_range(41.0, 52.0))
			var ld := rng.randf_range(6.0, 36.0)
			var p: Vector3 = lw(t, Vector3(x, 0.0, -71.5 + ld))
			tree_pos[t].append(p)
			tree_food[t].append(TREE_MAX)
			var root := Node3D.new()
			root.position = p
			battle.add_child(root)
			battle._mesh(root, tm, trunk, Vector3(0, 1.1, 0), Vector3.ZERO, false)
			battle._mesh(root, sm, leaf, Vector3(0, 3.5, 0), Vector3.ZERO, true)
			var fr := Node3D.new()
			root.add_child(fr)
			for k in 9:
				var a := float(k) / 9.0 * TAU + rng.randf() * 0.5
				battle._mesh(fr, fm, fruit_mat, Vector3(cos(a) * 1.45, 3.2 + rng.randf_range(-0.7, 0.8), sin(a) * 1.45), Vector3.ZERO, false)
			tree_nodes[t].append(fr)


func _make_fire(parent: Node3D, p: Vector3) -> Dictionary:
	var fire := CPUParticles3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3.ONE * 0.5
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(1.0, 0.5, 0.1)
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.45, 0.1)
	fmat.emission_energy_multiplier = 3.0
	fm.material = fmat
	fire.mesh = fm
	fire.amount = 14
	fire.lifetime = 1.0
	fire.direction = Vector3.UP
	fire.spread = 25.0
	fire.initial_velocity_min = 2.0
	fire.initial_velocity_max = 4.0
	fire.gravity = Vector3(0, 1.0, 0)
	fire.scale_amount_min = 0.5
	fire.scale_amount_max = 1.6
	fire.position = p
	fire.emitting = false
	parent.add_child(fire)
	var smoke := CPUParticles3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3.ONE * 1.2
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.15, 0.15, 0.16, 0.6)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = smat
	smoke.mesh = sm
	smoke.amount = 10
	smoke.lifetime = 3.0
	smoke.direction = Vector3.UP
	smoke.spread = 15.0
	smoke.initial_velocity_min = 2.5
	smoke.initial_velocity_max = 4.5
	smoke.gravity = Vector3(0, 0.5, 0)
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 2.4
	smoke.position = p + Vector3(0, 1.5, 0)
	smoke.emitting = false
	parent.add_child(smoke)
	return {"fire": fire, "smoke": smoke}


# ================================================================== buildings
func _make_house(t: int) -> Node3D:
	var n := Node3D.new()
	var wall: StandardMaterial3D = battle._mat(Color(0.86, 0.79, 0.62), 0.95)
	var roofc: Color = battle.team_col(t).darkened(0.25)
	var roof: StandardMaterial3D = battle._mat(roofc, 0.8)
	var dark: StandardMaterial3D = battle._mat(Color(0.25, 0.16, 0.09), 0.9)
	var glow: StandardMaterial3D = battle._mat(Color(1.0, 0.8, 0.4), 0.5, 0.0, 2.0)
	var stone: StandardMaterial3D = battle._mat(Color(0.5, 0.48, 0.45), 0.95)
	battle._mesh(n, battle._box(Vector3(5.0, 2.8, 4.2)), wall, Vector3(0, 1.4, 0), Vector3.ZERO, true)
	var pm := PrismMesh.new()
	pm.size = Vector3(5.7, 1.9, 4.8)
	battle._mesh(n, pm, roof, Vector3(0, 3.75, 0), Vector3.ZERO, true)
	battle._mesh(n, battle._box(Vector3(0.9, 1.7, 0.1)), dark, Vector3(0, 0.85, 2.11), Vector3.ZERO, false)
	for sx in [-1.6, 1.6]:
		battle._mesh(n, battle._box(Vector3(0.7, 0.7, 0.1)), glow, Vector3(sx, 1.7, 2.11), Vector3.ZERO, false)
	battle._mesh(n, battle._box(Vector3(0.55, 1.3, 0.55)), stone, Vector3(1.7, 3.9, -1.1), Vector3.ZERO, false)
	return n


func _make_barracks(t: int) -> Node3D:
	var n := Node3D.new()
	var tc: Color = battle.team_col(t)
	var wall: StandardMaterial3D = battle._mat(Color(0.38, 0.27, 0.19), 0.95)
	var roof: StandardMaterial3D = battle._mat(Color(0.2, 0.17, 0.16), 0.85)
	var dark: StandardMaterial3D = battle._mat(Color(0.14, 0.09, 0.06), 0.9)
	var steel: StandardMaterial3D = battle._mat(Color(0.75, 0.77, 0.82), 0.9, 0.3)
	var cloth: StandardMaterial3D = battle._mat(tc, 0.8, 0.0, 0.7)
	battle._mesh(n, battle._box(Vector3(8.0, 3.6, 6.0)), wall, Vector3(0, 1.8, 0), Vector3.ZERO, true)
	var pm := PrismMesh.new()
	pm.size = Vector3(8.8, 2.4, 6.8)
	battle._mesh(n, pm, roof, Vector3(0, 4.8, 0), Vector3.ZERO, true)
	battle._mesh(n, battle._box(Vector3(2.4, 2.6, 0.12)), dark, Vector3(0, 1.3, 3.02), Vector3.ZERO, false)
	battle._mesh(n, battle._box(Vector3(0.18, 7.0, 0.18)), dark, Vector3(-3.7, 3.5, 3.3), Vector3.ZERO, false)
	battle._mesh(n, battle._box(Vector3(2.0, 1.3, 0.08)), cloth, Vector3(-2.7, 6.2, 3.3), Vector3.ZERO, false)
	for k in 3:
		battle._mesh(n, battle._box(Vector3(0.08, 2.2, 0.08)), steel, Vector3(2.4 + k * 0.5, 1.3, 3.1), Vector3(0, 0, 0.12 * (k - 1)), false)
	return n


func _refresh_visuals() -> void:
	if fortress != null:
		fortress.sync()
	for t in nk:
		for i in tree_nodes[t].size():
			var fr: Node3D = tree_nodes[t][i]
			var r: float = clampf(float(tree_food[t][i]) / TREE_MAX, 0.0, 1.0)
			fr.visible = r > 0.12
			fr.scale = Vector3.ONE * (0.55 + 0.45 * r)
		var ex: Dictionary = extras[t]
		if not ex.is_empty():
			var was2: bool = ex.l2.visible
			ex.l2.visible = level[t] >= 2
			ex.l3.visible = level[t] >= 3
			if vis_ready and ex.l2.visible and not was2:
				battle._burst(lw(t, Vector3(0, 16, -112.0)), Color(1, 0.9, 0.5), 30, 8.0, true)
		if not ex.is_empty() and ex.get("yard") != null:
			var yv: Node3D = ex.yard
			var wasy: bool = yv.visible
			yv.visible = yard[t]
			if vis_ready and yard[t] and not wasy:
				battle._burst(lw(t, Vector3(0, 4, -128.0)), Color(0.8, 0.65, 0.4), 30, 6.0, true)
		var maxhp: float = CASTLE_HP[level[t] - 1]
		var ratio: float = castle_hp[t] / maxhp
		for k in fires[t].size():
			var on: bool = ratio < (0.7 - 0.2 * k) and not fallen[t] or (fallen[t] and k < 2)
			fires[t][k].fire.emitting = on
			fires[t][k].smoke.emitting = on


# ================================================================== state sync
func _state() -> Dictionary:
	var tf := []
	var gl := []
	var fl := []
	var lv := []
	var sl := []
	var hp := []
	var pu := []
	var vn := []
	var sn := []
	var qq := []
	var fa := []
	var wd := []
	var shp := []
	var stn := []
	var irn := []
	var grn := []
	var flr := []
	var yd := []
	var tn := []
	var fnn := []
	for t in nk:
		var a := []
		for v in tree_food[t]:
			a.append(int(v))
		tf.append(a)
		gl.append(int(gold[t]))
		fl.append(int(food[t]))
		lv.append(level[t])
		hp.append(int(castle_hp[t]))
		pu.append(pop_used[t])
		vn.append(vill_n[t])
		sn.append(soldier_n[t])
		qq.append(queue[t].size())
		fa.append(fallen[t])
		wd.append(int(wood[t]))
		shp.append(ship_n[t])
		stn.append(int(stone[t]))
		irn.append(int(iron[t]))
		grn.append(int(grain[t]))
		flr.append(int(flour[t]))
		yd.append(yard[t])
		tn.append(trn_n[t])
		fnn.append(fsh_n[t])
	return {"w": battle.war, "wp": war_pairs.keys(), "g": gl, "f": fl, "l": lv, "s": sl, "h": hp, "tf": tf,
		"pu": pu, "vn": vn, "sn": sn, "q": qq, "fl": fa, "wd": wd, "sh": shp, "yd": yd, "tn": tn, "fn": fnn,
		"fw": forge_w.duplicate(), "fa": forge_a.duplicate(), "stn": stn, "irn": irn, "grn": grn, "flr": flr, "yr": year_t, "tw": town.pack()}


func _apply_state(s: Dictionary) -> void:
	battle.war = bool(s.w)
	war_pairs = {}
	for k in s.wp:
		war_pairs[int(k)] = true
	for t in nk:
		gold[t] = float(s.g[t])
		food[t] = float(s.f[t])
		level[t] = int(s.l[t])
		castle_hp[t] = float(s.h[t])
		for i in tree_food[t].size():
			tree_food[t][i] = float(s.tf[t][i])
		pop_used[t] = int(s.pu[t])
		vill_n[t] = int(s.vn[t])
		soldier_n[t] = int(s.sn[t])
		queue[t] = _fake_q(int(s.q[t]))
		fallen[t] = bool(s.fl[t])
		wood[t] = float(s.wd[t])
		ship_n[t] = int(s.sh[t])
		stone[t] = float(s.stn[t])
		iron[t] = float(s.irn[t])
		forge_w[t] = int(s.fw[t])
		forge_a[t] = int(s.fa[t])
		grain[t] = float(s.grn[t])
		flour[t] = float(s.flr[t])
		yard[t] = bool(s.yd[t])
		trn_n[t] = int(s.tn[t])
		fsh_n[t] = int(s.fn[t])
	year_t = float(s.yr)
	town.unpack(s.tw)
	_refresh_visuals()


func _fake_q(n: int) -> Array:
	var a := []
	for i in n:
		a.append({"kind": "?", "t": 1.0, "owner": 0})
	return a


@rpc("authority", "reliable")
func state_msg(s: Dictionary) -> void:
	if is_srv:
		return
	_apply_state(s)


@rpc("authority", "reliable")
func ev_msg(kind: String, data: Dictionary) -> void:
	if is_srv:
		return
	_ev(kind, data)


@rpc("any_peer", "reliable")
func cmd_msg(act: String, data: Dictionary) -> void:
	if not is_srv:
		return
	_cmd(multiplayer.get_remote_sender_id(), act, data)


func ev_all(kind: String, data: Dictionary) -> void:
	_ev(kind, data)
	if net.online:
		ev_msg.rpc(kind, data)


func cmd(act: String, data := {}) -> void:
	if battle.over:
		return
	if is_srv:
		_cmd(battle.ctrl_owner(), act, data)
	else:
		cmd_msg.rpc_id(1, act, data)


func toast_team(t: int, text: String) -> void:
	ev_all("toast", {"team": t, "text": text})


# ================================================================== commands (host)
func _cmd(owner: int, act: String, data: Dictionary) -> void:
	if battle.over or not battle.running:
		return
	var t := team_of(owner)
	var human := owner >= 0
	match act:
		"villager":
			if food[t] < VILLAGER_FOOD:
				if human: toast_team(t, "Not enough food!")
				return
			if pop_used[t] >= pop_cap(t):
				if human: toast_team(t, "Build more houses first!")
				return
			if queue[t].size() >= 8:
				return
			food[t] -= VILLAGER_FOOD
			queue[t].append({"kind": "villager", "t": 3.0, "owner": owner})
		"build":
			var why: String = town.place(t, String(data.get("type", "")), float(data.get("lx", 0.0)), float(data.get("d", 0.0)))
			if why != "":
				if human: toast_team(t, why)
				return
			if t == my_team:
				battle.sfx.play_ui("coin", -6.0)
		"demolish":
			town.demolish(t, int(data.get("id", -1)))
		"trade":
			_trade(t, human, String(data.get("res", "")), bool(data.get("buy", false)))
		"upgrade":
			if level[t] >= 3:
				return
			var cost: Array = UPGRADE[level[t] - 1]
			if gold[t] < cost[0] or food[t] < cost[1]:
				if human: toast_team(t, "Need %d gold and %d food" % [cost[0], cost[1]])
				return
			gold[t] -= cost[0]
			food[t] -= cost[1]
			var oldmax: float = CASTLE_HP[level[t] - 1]
			level[t] += 1
			castle_hp[t] += CASTLE_HP[level[t] - 1] - oldmax
			ev_all("level", {"team": t, "lvl": level[t]})
		"forge":
			var which: String = String(data.get("w", "w"))
			var lvl: int = forge_w[t] if which == "w" else forge_a[t]
			if town.count(t, "smithy") <= 0:
				if human: toast_team(t, "Build a smithy first!")
				return
			if lvl >= 3:
				if human: toast_team(t, "Already at the highest level.")
				return
			var cst := forge_cost(which, lvl)
			if gold[t] < float(cst.gold) or iron[t] < float(cst.iron) or stone[t] < float(cst.stone):
				if human: toast_team(t, "Not enough materials for weapons!")
				return
			gold[t] -= float(cst.gold)
			iron[t] -= float(cst.iron)
			stone[t] -= float(cst.stone)
			if which == "w":
				forge_w[t] += 1
			else:
				forge_a[t] += 1
			toast_team(t, "The smith finished better weapons!" if which == "w" else "The smith finished stronger armour!")
			battle.sfx.play_ui("hammer", -4.0) if t == my_team else null
		"repair":
			var mx: float = CASTLE_HP[level[t] - 1]
			if gold[t] < REPAIR_COST:
				if human: toast_team(t, "Not enough gold!")
				return
			if castle_hp[t] >= mx - 1.0:
				if human: toast_team(t, "The walls are already sound.")
				return
			gold[t] -= REPAIR_COST
			castle_hp[t] = minf(mx, castle_hp[t] + mx * 0.25)
			battle.sfx.play_ui("hammer", -4.0) if t == my_team else null
		"shipyard":
			if not battle.sea:
				if human: toast_team(t, "Ships need the Island map.")
				return
			if yard[t]:
				return
			if level[t] < 2:
				if human: toast_team(t, "Castle level 2 needed")
				return
			if gold[t] < YARD_GOLD or wood[t] < YARD_WOOD:
				if human: toast_team(t, "Need %d gold and %d planks" % [YARD_GOLD, YARD_WOOD])
				return
			gold[t] -= YARD_GOLD
			wood[t] -= YARD_WOOD
			yard[t] = true
			ev_all("toast", {"team": t, "text": "The shipyard is built!"})
			battle.sfx.play("hammer", dock_pos(t), 4.0)
		"ship":
			if not battle.sea:
				if human: toast_team(t, "Ships need the Island map.")
				return
			if not yard[t]:
				if human: toast_team(t, "Build a shipyard first.")
				return
			var typ: String = str(data.get("type", "ship"))
			var cg := SHIP_GOLD
			var cw := SHIP_WOOD
			var have: int = ship_n[t]
			var mx := MAX_SHIPS
			if typ == "transport":
				cg = TRANSPORT_GOLD; cw = TRANSPORT_WOOD; have = trn_n[t]; mx = MAX_TRANSPORTS
			elif typ == "fisher":
				cg = FISHER_GOLD; cw = FISHER_WOOD; have = fsh_n[t]; mx = MAX_FISHERS
			else:
				typ = "ship"
			if have >= mx:
				if human: toast_team(t, "You already have the maximum number of ships.")
				return
			if gold[t] < cg or wood[t] < cw:
				if human: toast_team(t, "Need %d gold and %d planks" % [cg, cw])
				return
			gold[t] -= cg
			wood[t] -= cw
			var nb: int = ship_n[t] + trn_n[t] + fsh_n[t]
			var sp: Vector3 = dock_pos(t) + battle.rotv(t, Vector3(float(nb % 6) * 8.0 - 20.0, 0, 6.0 * float(nb / 6)))
			sp = battle.keep_on_sea(sp)
			var sh = battle._make_unit(typ, t, owner, sp)
			sh.rotation.y = atan2(sp.x, sp.z)
			sh.scale = Vector3(1, 0.05, 1)
			create_tween().tween_property(sh, "scale", Vector3.ONE, 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if typ == "ship":
				ship_n[t] += 1
			elif typ == "transport":
				trn_n[t] += 1
			else:
				fsh_n[t] += 1
			ev_all("ship", {"team": t})
			battle.sfx.play("hammer", sp, 4.0)
		"buyfood":
			if town.count(t, "market") < 1:
				if human: toast_team(t, "Build a market first.")
				return
			if gold[t] < BUY_GOLD:
				if human: toast_team(t, "Not enough gold!")
				return
			gold[t] -= BUY_GOLD
			food[t] += BUY_FOOD
		"train":
			var kind: String = String(data.get("kind", "sword"))
			if not TRAIN.has(kind):
				return
			var info: Array = TRAIN[kind]
			if level[t] < info[3]:
				if human: toast_team(t, "Castle level %d needed" % info[3])
				return
			var blk: String = train_block(t, kind)
			if blk != "":
				if human: toast_team(t, blk)
				return
			if gold[t] < info[0] or food[t] < info[1]:
				if human: toast_team(t, "Need %d gold and %d food" % [info[0], info[1]])
				return
			var tx: Dictionary = TRAIN_X.get(kind, {})
			var tx_ok := true
			for rk in tx.keys():
				if res_get(t, String(rk)) < float(tx[rk]):
					tx_ok = false
			if not tx_ok:
				if human: toast_team(t, "Not enough materials for weapons!")
				return
			if pop_used[t] >= pop_cap(t):
				if human: toast_team(t, "Build more houses first!")
				return
			if queue[t].size() >= 8:
				return
			gold[t] -= info[0]
			food[t] -= info[1]
			for rk2 in tx.keys():
				res_add(t, String(rk2), -float(tx[rk2]))
			queue[t].append({"kind": kind, "t": float(info[2]) * (0.85 if trait_has(t, "warlord") else 1.0), "owner": owner})
		"tax":
			if float(decree_cd[t].tax) > 0.0:
				if human: toast_team(t, "Wait %ds" % ceili(float(decree_cd[t].tax)))
				return
			var tg: int = 25 + 10 * count_slots(t, 1) + 2 * vill_n[t]
			gold[t] += tg
			decree_cd[t].tax = 60.0
			if human: toast_team(t, "The people paid %d gold in taxes." % tg)
		"feast":
			if float(decree_cd[t].feast) > 0.0:
				if human: toast_team(t, "Wait %ds" % ceili(float(decree_cd[t].feast)))
				return
			if food[t] < FEAST_FOOD:
				if human: toast_team(t, "Not enough food!")
				return
			food[t] -= FEAST_FOOD
			decree_cd[t].feast = 90.0
			for fu in battle.units.values():
				if fu.team == t and not fu.dead and fu.kind != "villager":
					fu.hp = fu.max_hp
			if human: toast_team(t, "The royal feast heals your army!")
		"challenge":
			var ct: int = int(data.get("to", battle.foe(t)))
			if ct == t or ct < 0 or ct >= nk or not at_war(t, ct):
				if human: toast_team(t, "Declare war first!")
				return
			if battle.duel_active or duel_done or challenge_t > 0.0:
				return
			challenge_t = 3.5
			duel_pair = [t, ct]
			ev_all("summon", {"by": t})
		"letter":
			var text: String = String(data.get("text", "")).strip_edges()
			if text.is_empty():
				return
			if letter_cd[t] > 0.0:
				if human: toast_team(t, "Your messenger is still preparing (%ds)" % ceili(letter_cd[t]))
				return
			letter_cd[t] = LETTER_CD
			var lt: int = int(data.get("to", battle.foe(t)))
			_send_letter(t, text.substr(0, 240), owner, lt)
		"war":
			var wt: int = int(data.get("to", battle.foe(t)))
			if wt == t or wt < 0 or wt >= nk or fallen[t] or fallen[wt] or at_war(t, wt):
				return
			declare_war(t, wt)
			battle.war_t0 = battle.game_time
			ev_all("war", {"by": t, "to": wt})
	state_t = 0.0


func _send_letter(from_t: int, text: String, owner: int, to_t := -1) -> void:
	if battle.ai_teams.has(from_t) and LocS.lang == "ar":
		text = LocS.t(text)
	if to_t < 0 or to_t >= nk or to_t == from_t:
		to_t = battle.foe(from_t)
	var id := next_msg
	next_msg += 1
	var dist: float = gate_out(from_t).distance_to(gate_out(to_t))
	msgs[id] = {"from": from_t, "to": to_t, "t": 0.0, "dur": dist / MSG_SPEED, "text": text, "owner": owner, "node": null}
	ev_all("msg_spawn", {"id": id, "from": from_t, "to": to_t})
	if owner >= 0:
		toast_team(from_t, "Messenger sent!")


# ================================================================== events (all peers)
func _fire_fx(p: Vector3) -> void:
	var root := Node3D.new()
	root.position = p
	battle.add_child(root)
	var lt := OmniLight3D.new()
	lt.light_color = Color(1.0, 0.55, 0.2)
	lt.omni_range = 14.0
	lt.light_energy = 2.5
	lt.position = Vector3(0, 3.0, 0)
	root.add_child(lt)
	for i in 6:
		var m := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.9
		sp.height = 1.8
		m.mesh = sp
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.45 + randf() * 0.3, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.4, 0.05)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.material_override = mat
		m.position = Vector3(randf_range(-2.0, 2.0), 0.8 + randf() * 2.0, randf_range(-2.0, 2.0))
		root.add_child(m)
		var tw := create_tween()
		tw.tween_property(m, "scale", Vector3(0.5, 1.5, 0.5), 0.25 + randf() * 0.2)
		tw.tween_property(m, "scale", Vector3(1.2, 0.8, 1.2), 0.25 + randf() * 0.2)
		tw.set_loops(18)
	var out := create_tween()
	out.tween_interval(9.0)
	out.tween_callback(root.queue_free)
	battle.sfx.play("crackle", p, 6.0, 1.0)


func _ev(kind: String, d: Dictionary) -> void:
	match kind:
		"built":
			if int(d.team) == my_team:
				battle._toast(LocS.t(TownS.DEFS[String(d.type)].name) + " " + LocS.t("is finished!"), 2.4)
				battle.sfx.play("hammer", Vector3(float(d.x), 0, float(d.z)), 2.0)
		"fire":
			_fire_fx(Vector3(float(d.x), 0, float(d.z)))
		"toast":
			var tt: int = int(d.team)
			if tt == -1 or tt == my_team:
				battle._toast(String(d.text), 2.6)
		"level":
			var t: int = int(d.team)
			battle.sfx.play("horn", lw(t, Vector3(0, 10, -73.0)), 2.0)
			if t == my_team:
				battle.banner("CASTLE LEVEL %d" % int(d.lvl), Color(1.0, 0.85, 0.3), 1.6)
		"war":
			var by: int = int(d.by)
			var wto: int = int(d.get("to", battle.foe(by)))
			if not is_srv:
				declare_war(by, wto)
			battle.war_t0 = battle.game_time
			battle.sfx.play_ui("horn", 2.0)
			var mine_declared := by == my_team
			var involved := mine_declared or wto == my_team
			if involved or nk == 2:
				battle.banner("WAR!" if mine_declared else "%s DECLARES WAR!" % king_name(by).to_upper(), Color(1.0, 0.25, 0.2), 3.0)
				var tgt: int = wto if mine_declared else by
				battle.cine_orbit(lw(tgt, Vector3(0, 6, -73.0)), 70.0, 28.0, 4.0, 0.7)
			else:
				battle._toast("%s declared war on %s!" % [king_name(by), king_name(wto)], 3.5)
		"msg_spawn":
			_vis_msg_spawn(int(d.id), int(d.from), int(d.get("to", battle.foe(int(d.from)))))
		"msg_end":
			_vis_msg_end(int(d.id), bool(d.ok))
		"letter":
			if int(d.to) == my_team:
				battle.sfx.play_ui("bell")
				_show_reader(String(d.name), String(d.text))
		"march":
			if int(d.team) == my_team:
				battle.cine_shot(lw(my_team, Vector3(10, 4.5, -58.0)), lw(my_team, Vector3(-4, 6.5, -54.0)), lw(my_team, Vector3(0, 4.0, -74.0)), lw(my_team, Vector3(0, 3.0, -66.0)), 6.0)
				battle.banner("THE ARMY MARCHES!", Color(1.0, 0.85, 0.3), 3.0)
				battle.sfx.play_ui("horn", -1.0)
		"summon":
			battle.sfx.play_ui("horn", 2.0)
			battle.banner("THE KINGS ARE SUMMONED TO THE FIELD OF HONOR!", Color(1.0, 0.75, 0.25), 3.4)
		"duel_start":
			battle.duel_teams = [int(d.get("a", 0)), int(d.get("b", 1))]
			_duel_visual_start(Vector3(d.c))
		"duel_end":
			_duel_visual_end()
		"castle_fall":
			_castle_fall_visual(int(d.team))
			if int(d.team) == my_team and nk > 2:
				battle._toast("Your kingdom has fallen. You are now watching.", 6.0)
		"king_down":
			if int(d.team) == my_team:
				battle._toast("Your king has fallen! He will return soon...", 3.0)
			else:
				battle._toast("The enemy king has fallen!", 3.0)


func _castle_fall_visual(t: int) -> void:
	var root: Node3D = battle.castle_roots[t]
	var cc: Vector3 = lw(t, Vector3(0, 0, -73.0))
	battle.cine_orbit(lw(t, Vector3(0, 6, -73.0)), 48.0, 24.0, 6.5, 1.1)
	battle._slowmo(0.45, 3.5)
	battle.banner("THE CASTLE FALLS!", Color(1.0, 0.6, 0.2), 3.5)
	var tw := create_tween()
	tw.tween_property(root, "scale:y", 0.1, 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(root, "rotation:x", 0.07, 3.0)
	for i in 14:
		var tm := get_tree().create_timer(0.2 + i * 0.22)
		tm.timeout.connect(func():
			var p: Vector3 = lw(t, Vector3(randf_range(-34.0, 34.0), randf_range(2.0, 12.0), -73.0))
			battle._burst(p, Color(0.5, 0.46, 0.4), 22, 7.0, false)
			battle.sfx.play("thud", p, 6.0, 0.7)
			battle.shake = minf(battle.shake + 0.25, 0.7))
	for k in fires[t].size():
		fires[t][k].fire.emitting = true
		fires[t][k].smoke.emitting = true


# ================================================================== messengers
func _msg_point(from_t: int, to_t: int, p: float) -> Vector3:
	var a: Vector3 = gate_out(from_t)
	var b: Vector3 = gate_out(to_t)
	var dir: Vector3 = (b - a).normalized()
	var perp := Vector3(-dir.z, 0.0, dir.x)
	var pos: Vector3 = a.lerp(b, p)
	return pos + perp * 14.0 * sin(p * PI)


func _make_rider(t: int) -> Node3D:
	var n := Node3D.new()
	var tc: Color = battle.team_col(t)
	var hm: StandardMaterial3D = battle._mat(Color(0.55, 0.38, 0.22), 0.0, 0.8)
	var dark: StandardMaterial3D = battle._mat(Color(0.12, 0.08, 0.05), 0.0, 0.9)
	var cloth: StandardMaterial3D = battle._mat(tc, 0.0, 0.8, 0.4)
	var skin: StandardMaterial3D = battle._mat(Color(0.86, 0.66, 0.52), 0.0, 0.9)
	var paper: StandardMaterial3D = battle._mat(Color(0.96, 0.92, 0.8), 0.0, 0.9, 0.5)
	var wax: StandardMaterial3D = battle._mat(Color(0.7, 0.1, 0.1), 0.0, 0.6, 0.8)
	battle._mesh(n, battle._box(Vector3(0.6, 0.65, 1.6)), hm, Vector3(0, 1.0, 0), Vector3.ZERO, true)
	battle._mesh(n, battle._box(Vector3(0.28, 0.7, 0.3)), hm, Vector3(0, 1.45, 0.8), Vector3(-0.5, 0, 0), false)
	battle._mesh(n, battle._box(Vector3(0.24, 0.26, 0.55)), hm, Vector3(0, 1.75, 1.15), Vector3.ZERO, false)
	battle._mesh(n, battle._box(Vector3(0.08, 0.7, 0.1)), dark, Vector3(0, 0.95, -0.88), Vector3.ZERO, false)
	for sx in [-0.2, 0.2]:
		for sz in [0.6, -0.6]:
			battle._mesh(n, battle._box(Vector3(0.14, 0.7, 0.14)), hm, Vector3(sx, 0.35, sz), Vector3.ZERO, false)
	var cap := CapsuleMesh.new()
	cap.radius = 0.24
	cap.height = 0.95
	battle._mesh(n, cap, cloth, Vector3(0, 1.75, -0.05), Vector3.ZERO, true)
	var hd := SphereMesh.new()
	hd.radius = 0.17
	hd.height = 0.34
	battle._mesh(n, hd, skin, Vector3(0, 2.35, -0.02), Vector3.ZERO, false)
	battle._mesh(n, battle._box(Vector3(0.42, 0.1, 0.42)), cloth, Vector3(0, 2.52, -0.02), Vector3.ZERO, false)
	# the scroll, held out in front
	var sc := CylinderMesh.new()
	sc.top_radius = 0.07
	sc.bottom_radius = 0.07
	sc.height = 0.6
	sc.radial_segments = 8
	battle._mesh(n, sc, paper, Vector3(0.3, 1.9, 0.35), Vector3(PI / 2.0, 0, 0.0), false)
	battle._mesh(n, battle._sph_mesh(0.08), wax, Vector3(0.3, 1.9, 0.55), Vector3.ZERO, false)
	# dust
	var pr := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.22
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.66, 0.55, 0.4, 0.7)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.material = bmat
	pr.mesh = bm
	pr.amount = 14
	pr.lifetime = 0.9
	pr.direction = Vector3(0, 0.6, -1)
	pr.spread = 30.0
	pr.initial_velocity_min = 1.0
	pr.initial_velocity_max = 3.0
	pr.gravity = Vector3(0, -1.0, 0)
	pr.position = Vector3(0, 0.2, -1.0)
	n.add_child(pr)
	pr.emitting = true
	return n


func _vis_msg_spawn(id: int, from_t: int, to_t: int) -> void:
	var node := _make_rider(from_t)
	battle.add_child(node)
	node.position = _msg_point(from_t, to_t, 0.0)
	var m: Dictionary
	if msgs.has(id):
		m = msgs[id]
	else:
		var dist: float = gate_out(from_t).distance_to(gate_out(to_t))
		m = {"from": from_t, "to": to_t, "t": 0.0, "dur": dist / MSG_SPEED, "text": "", "owner": 0}
		msgs[id] = m
	m["node"] = node
	battle.sfx.play("horn", node.position, -6.0, 1.6)


func _vis_msg_end(id: int, ok: bool) -> void:
	if not msgs.has(id):
		return
	var m: Dictionary = msgs[id]
	var node = m.get("node")
	if node != null and is_instance_valid(node):
		battle._burst(node.position + Vector3(0, 1.5, 0), Color(0.95, 0.9, 0.7) if ok else Color(0.8, 0.2, 0.2), 16, 4.0, true)
		node.queue_free()
	msgs.erase(id)


func _tick_messengers(dt: float) -> void:
	var done := []
	for id in msgs.keys():
		var m: Dictionary = msgs[id]
		m.t += dt
		var p: float = clampf(m.t / m.dur, 0.0, 1.0)
		var node = m.get("node")
		if node != null and is_instance_valid(node):
			var a := _msg_point(m.from, m.to, p)
			var b := _msg_point(m.from, m.to, minf(p + 0.02, 1.0))
			node.position = a + Vector3(0, absf(sin(m.t * 9.0)) * 0.22, 0)
			if b.distance_to(a) > 0.01:
				node.rotation.y = atan2(b.x - a.x, b.z - a.z)
		if is_srv:
			if p >= 1.0:
				done.append([id, true])
			elif at_war(int(m.from), int(m.to)):
				var pos := _msg_point(m.from, m.to, p)
				for e in battle.by_team[int(m.to)]:
					if e.dead or e.kind == "villager":
						continue
					if Vector2(e.position.x - pos.x, e.position.z - pos.z).length() < 3.0:
						done.append([id, false])
						break
	for pair in done:
		var id: int = pair[0]
		if not msgs.has(id):
			continue
		var m: Dictionary = msgs[id]
		var ok: bool = pair[1]
		var from_t: int = int(m.from)
		var text: String = String(m.text)
		var owner: int = int(m.owner)
		ev_all("msg_end", {"id": id, "ok": ok})
		if ok:
			var to_t: int = int(m.to)
			ev_all("letter", {"to": to_t, "from": from_t, "name": king_name(from_t), "text": text})
			_ai_read_letter(to_t, from_t, text)
			if owner >= 0:
				toast_team(from_t, "Your letter was delivered.")
		else:
			toast_team(-1, "A messenger was cut down on the road!")


# ================================================================== host simulation
func _physics_process(dt: float) -> void:
	if not is_srv or not battle.running or battle.over:
		return
	for t in nk:
		letter_cd[t] = maxf(0.0, letter_cd[t] - dt)
		decree_cd[t].tax = maxf(0.0, float(decree_cd[t].tax) - dt)
		decree_cd[t].feast = maxf(0.0, float(decree_cd[t].feast) - dt)
	econ_t += dt
	if econ_t >= 0.25:
		var step := econ_t
		econ_t = 0.0
		_econ(step)
	_tower_tick(dt)
	_tick_duel(dt)
	_tick_respawn(dt)
	for r in ai_replies:
		r.t -= dt
	while not ai_replies.is_empty() and ai_replies[0].t <= 0.0:
		var r: Dictionary = ai_replies.pop_front()
		_send_letter(int(r.team), String(r.text), -100 - int(r.team))
	for t in battle.ai_teams:
		if battle.admin and battle.admin_ctrl and battle.admin_view == t and not net.online:
			continue
		ai_next[t] -= dt
		if ai_next[t] <= 0.0:
			ai_next[t] = 1.5
			_ai_tick(t)
	state_t -= dt
	if state_t <= 0.0:
		state_t = 0.25
		var s := _state()
		_refresh_visuals()
		if net.online:
			state_msg.rpc(s)


func _econ(dt: float) -> void:
	year_t += dt
	var vn := []
	var sn := []
	var shn := []
	var trs := []
	var fis := []
	for t in nk:
		trs.append(0)
		fis.append(0)
		vn.append(0)
		sn.append(0)
		shn.append(0)
	for u in battle.units.values():
		if u.dead:
			continue
		if u.kind == "villager":
			vn[u.team] += 1
		elif u.is_ship:
			if u.kind == "ship":
				shn[u.team] += 1
			elif u.kind == "transport":
				trs[u.team] += 1
			else:
				fis[u.team] += 1
		elif u.kind != "hero":
			sn[u.team] += 1
	ship_n = shn
	trn_n = trs
	fsh_n = fis
	vill_n = vn
	soldier_n = sn
	for t in nk:
		var houses := count_slots(t, 1)
		gold[t] += (houses * 0.22 + vn[t] * 0.04) * dt * (1.5 if trait_has(t, "merchant") else 1.0) * (1.0 + ai_extra(t))
		town.passive(t, dt)
		# everybody eats (more in winter)
		var cold := 1.3 if season() == 3 else 1.0
		food[t] = maxf(0.0, food[t] - float(vn[t] + sn[t]) * FOOD_UPKEEP * dt * cold)
		pop_used[t] = vn[t] + sn[t] + queue[t].size()
		_life(t, dt)
		# trees regrow
		for i in tree_food[t].size():
			tree_food[t][i] = minf(TREE_MAX, float(tree_food[t][i]) + 0.4 * dt)
		# training (up to 3 at once)
		var q: Array = queue[t]
		var k := 0
		while k < mini(3, q.size()):
			q[k].t -= dt
			if q[k].t <= 0.0:
				var item: Dictionary = q.pop_at(k)
				_spawn_trained(t, item)
			else:
				k += 1


# ---------------------------------------------------------------- medieval life (host)
var life_t := []
var life_log := []


func trait_has(t: int, id: String) -> bool:
	return t == my_team and king_trait == id


func ai_extra(t: int) -> float:
	# difficulty: the computer kingdoms earn more (hard) or less (easy) gold
	if t == my_team or net.online:
		return 0.0
	match king_diff:
		"easy":
			return -0.35
		"hard":
			return 0.55
	return 0.0


func build_mult(t: int) -> float:
	return 1.5 if trait_has(t, "builder") else 1.0


func forge_cost(which: String, lvl: int) -> Dictionary:
	var n := lvl + 1
	if which == "w":
		return {"gold": 60 * n, "iron": 15 * n, "stone": 0}
	return {"gold": 50 * n, "iron": 12 * n, "stone": 15 * n}


func dmg_mult(t: int, kind: String) -> float:
	if kind == "hero" or kind == "villager" or t < 0 or t >= forge_w.size():
		return 1.0
	return 1.0 + 0.15 * float(forge_w[t]) + (0.1 if trait_has(t, "warlord") else 0.0)


func armor_mult(t: int, kind: String) -> float:
	if kind == "hero" or kind == "villager" or t < 0 or t >= forge_a.size():
		return 1.0
	return 1.0 - 0.12 * float(forge_a[t])


# ---------------------------------------------------------------- renown, achievements, daily decree (local)
func _prog(dt: float) -> void:
	prog_t -= dt
	if prog_t > 0.0 or battle.over or battle.intro:
		return
	prog_t = 2.0
	var t := my_team
	if t < 0 or t >= nk or fallen[t]:
		return
	var ids := {}
	var total := 0
	var kinds := {}
	for b in town.bld[t]:
		if float(b.prog) >= 1.0:
			total += 1
			kinds[String(b.type)] = true
	if total >= 10:
		ids["builder10"] = true
	if kinds.size() >= 12:
		ids["town12"] = true
	if grain[t] >= 250.0:
		ids["granary"] = true
	if gold[t] >= 1500.0:
		ids["rich"] = true
	if forge_w[t] >= 3 or forge_a[t] >= 3:
		ids["ironwill"] = true
	if soldier_n[t] >= 40:
		ids["army40"] = true
	if level[t] >= 3:
		ids["castle3"] = true
	if ship_n[t] >= 3:
		ids["fleet"] = true
	for u in battle.by_team[t]:
		if u.rank_lv >= 3 and not u.dead:
			ids["veteran"] = true
			break
	for id in ids.keys():
		if ProfS.unlock(String(id)):
			var a: Dictionary = ProfS.ACH[id]
			battle._toast(LocS.t("Achievement unlocked:") + " " + LocS.t(String(a.name)) + "  +%d" % int(a.r), 3.5)
			battle.sfx.play_ui("ding")
	# daily decree
	if not ProfS.daily_done:
		var dd: Dictionary = ProfS.daily_today()
		var ok := false
		match String(dd.id):
			"farms3":
				ok = town.count(t, "farm") >= 3
			"army20":
				ok = soldier_n[t] >= 20
			"gold800":
				ok = gold[t] >= 800.0
			"houses8":
				ok = town.count(t, "house") >= 8
			"forge2":
				ok = forge_w[t] >= 2
			"bread":
				ok = town.count(t, "mill") > 0 and town.count(t, "bakery") > 0
		if ok:
			ProfS.daily_done = true
			var up := ProfS.add_renown(int(dd.r))
			battle._toast(LocS.t("Royal decree fulfilled!") + "  +%d" % int(dd.r), 3.5)
			battle.sfx.play_ui("ding")
			if up != "":
				battle._toast(LocS.t("New rank:") + " " + LocS.t(up), 3.5)


func _life(t: int, dt: float) -> void:
	while life_t.size() < nk:
		life_t.append(100.0 + randf() * 60.0)
	life_t[t] = float(life_t[t]) - dt
	if float(life_t[t]) > 0.0 or battle.game_time < 100.0:
		return
	life_t[t] = 70.0 + randf() * 70.0
	var r := randf()
	var has_well: bool = town.count(t, "well") > 0
	var has_church: bool = town.count(t, "church") > 0
	var has_market: bool = town.count(t, "market") > 0
	var seas := season()
	if r < 0.22:
		# fire: a wooden building burns down unless a well stops it
		if has_well and randf() < 0.75:
			toast_team(t, "A fire broke out, but the well saved the town!")
			return
		var cand := []
		for b in town.bld[t]:
			if String(b.type) in ["house", "woodcutter", "hunter", "farm", "mill", "bakery", "stable", "storehouse"] and float(b.prog) >= 1.0:
				cand.append(b)
		if cand.size() > 2:
			var b: Dictionary = cand[randi() % cand.size()]
			ev_all("fire", {"x": town.world(t, float(b.lx), float(b.d)).x, "z": town.world(t, float(b.lx), float(b.d)).z})
			town.destroy(t, int(b.id))
			toast_team(t, "Fire! A building burned down.")
	elif r < 0.40:
		# plague: villagers fall sick (a church helps)
		if has_church and randf() < 0.7:
			toast_team(t, "Sickness spread, but the priests healed the sick.")
			return
		var vs := []
		for u in battle.by_team[t]:
			if u.kind == "villager" and not u.dead:
				vs.append(u)
		if vs.size() > 3:
			var n: int = mini(2, vs.size() - 3)
			for i in n:
				vs[i].take_damage(999.0)
			toast_team(t, "Plague! Some villagers died.")
	elif r < 0.62:
		# travelling merchants
		var g := 70.0 + randf() * 90.0
		if has_market:
			g *= 1.6
		gold[t] += g
		if randf() < 0.5:
			iron[t] = minf(iron[t] + 12.0, 600.0)
		toast_team(t, "A merchant caravan arrived and paid you gold.")
	elif r < 0.78:
		if seas == 2 or seas == 0:
			grain[t] = minf(grain[t] + 80.0, 600.0)
			toast_team(t, "A rich harvest! Extra grain in the barns.")
		else:
			food[t] += 25.0
			toast_team(t, "Hunters had a lucky day: extra food.")
	elif r < 0.9:
		# bandits on the roads
		if soldier_n[t] < 3 and gold[t] > 120.0:
			var loss := minf(gold[t] * 0.2, 150.0)
			gold[t] -= loss
			toast_team(t, "Bandits robbed a caravan! Soldiers would have stopped them.")
		else:
			toast_team(t, "Your soldiers drove off bandits.")
	else:
		# village festival: calm and a little gold
		food[t] = maxf(0.0, food[t] - 12.0)
		gold[t] += 40.0
		toast_team(t, "A village festival! The people are happy.")



func _spawn_trained(t: int, item: Dictionary) -> void:
	var kind: String = item.kind
	var owner: int = item.owner
	if kind == "villager":
		var p: Vector3 = depot(t) + battle.rotv(t, Vector3(randf_range(-3.0, 3.0), 0, 0))
		battle._make_unit("villager", t, owner, p)
		return
	var bpos := depot(t)
	for bb in town.bld[t]:
		if bb.type == "barracks" and float(bb.prog) >= 1.0:
			bpos = town.world(t, float(bb.lx), float(bb.d) - 5.2)
			break
	var u = battle._make_unit(kind, t, owner, bpos + battle.rotv(t, Vector3(randf_range(-1.5, 1.5), 0, 0)))
	var n := 0
	for o in battle.units.values():
		if o != u and not o.dead and o.team == t and o.kind == kind:
			n += 1
	if kind == "sword":
		u.slot = battle.rotv(t, Vector3((n % 12 - 5.5) * 1.7, 0, -(3.0 + floorf(n / 12.0) * 1.8)))
	elif kind == "archer":
		u.slot = battle.rotv(t, Vector3((n % 12 - 5.5) * 1.7, 0, -(9.0 + floorf(n / 12.0) * 1.8)))
	else:
		var side := -1.0 if n % 2 == 0 else 1.0
		u.slot = battle.rotv(t, Vector3(side * (14.0 + float((n / 2) % 4) * 2.2), 0, -(3.0 + floorf(n / 8.0) * 2.5)))
	if not battle.orders.has(owner):
		battle.orders[owner] = {}
		for k in ["sword", "archer", "cav"]:
			battle.orders[owner][k] = {"mode": 2, "pos": home_pos(t)}
	battle.sfx.play("horn", u.position, -8.0, 1.8)


# ---- villager services (called from unit.gd) ----
func pick_tree(t: int, from: Vector3) -> int:
	var best := -1
	var bs := 1e9
	for i in tree_pos[t].size():
		if float(tree_food[t][i]) < 10.0:
			continue
		var s: float = from.distance_to(tree_pos[t][i]) + randf() * 12.0
		if s < bs:
			bs = s
			best = i
	return best


func tree_has_food(t: int, i: int) -> bool:
	return i >= 0 and i < tree_food[t].size() and float(tree_food[t][i]) >= 1.0


func tree_at(t: int, i: int) -> Vector3:
	return tree_pos[t][i]


func take_food(t: int, i: int, n: float) -> int:
	var got := minf(n, float(tree_food[t][i]))
	tree_food[t][i] = float(tree_food[t][i]) - got
	return int(got)


func deposit(t: int, n: int) -> void:
	food[t] += n


# The army was ordered to march: show the gate-opening cut-scene to that player.
var march_cd := [0.0, 0.0]


func on_march(owner: int) -> void:
	if not is_srv or not battle.war or owner < 0:
		return
	var t := team_of(owner)
	if battle.game_time < march_cd[t]:
		return
	var n := 0
	for u in battle.by_team[t]:
		if u.kind != "hero" and u.kind != "villager" and inside(t, u.position):
			n += 1
	if n < 3:
		return
	march_cd[t] = battle.game_time + 45.0
	ev_all("march", {"team": t})


# ---- castle, towers ----
func damage_castle(t: int, amount: float, by := -1) -> void:
	if not is_srv or fallen[t] or not battle.war:
		return
	castle_hp[t] = maxf(0.0, castle_hp[t] - amount)
	if castle_hp[t] <= 0.0:
		fallen[t] = true
		ev_all("castle_fall", {"team": t})
		var timer := get_tree().create_timer(6.5)
		timer.timeout.connect(func(): _eliminate(t, by))


# A kingdom is out of the game: its units vanish, and the match ends when one is left
# (or when no human kingdom is left).
func _eliminate(t: int, by: int) -> void:
	if battle.over:
		return
	for u in battle.units.values().duplicate():
		if u.team == t and not u.dead:
			u.hp = 0.0
			u.die()
	for k in war_pairs.keys().duplicate():
		if int(k) / 10 == t or int(k) % 10 == t:
			war_pairs.erase(k)
	if alive_count() <= 1:
		var w := -1
		for i in nk:
			if not fallen[i]:
				w = i
		battle.finish(w if w >= 0 else maxi(by, 0), "castle")
		return
	var humans_alive := false
	for id in net.players.keys():
		if not fallen[team_of(id)]:
			humans_alive = true
	if not humans_alive:
		var w2 := 0
		for i in nk:
			if not fallen[i]:
				w2 = i
				break
		battle.finish(w2, "castle")
	elif war_pairs.is_empty():
		battle.war = false


func _tower_tick(dt: float) -> void:
	if not battle.war:
		return
	tower_cd -= dt
	if tower_cd > 0.0:
		return
	tower_cd = 1.7
	for t in nk:
		if fallen[t]:
			continue
		for side in [-1.0, 1.0]:
			var tp: Vector3 = lw(t, Vector3(side * 36.0, 20.0, -73.0))
			var best = null
			var bd := TOWER_RANGE * TOWER_RANGE
			for ot in nk:
				if not battle.hostile(t, ot):
					continue
				for e in battle.by_team[ot]:
					if e.dead:
						continue
					var d: float = Vector2(e.position.x - tp.x, e.position.z - tp.z).length_squared()
					if d < bd:
						bd = d
						best = e
			if best != null:
				battle.fire_arrow_pos(tp, best, t, TOWER_DMG * (0.8 + 0.1 * level[t]))


# ---- king duel ----
func _tick_duel(dt: float) -> void:
	if challenge_t > 0.0:
		challenge_t -= dt
		if challenge_t <= 0.0:
			var ka = battle.team_king(int(duel_pair[0]))
			var kb = battle.team_king(int(duel_pair[1]))
			if ka != null and kb != null and not battle.duel_active:
				ka.position = Vector3(-5.0, 0.0, 0.0)
				kb.position = Vector3(5.0, 0.0, 0.0)
	# no separate duel arena any more: when the two kings meet in the war and trade blows,
	# their swords lock (see clash.gd) and the winner decides the loser's fate
	if not battle.war or battle.over:
		return
	if clash == null:
		clash = preload("res://game/clash.gd").new()
		clash.battle = battle
		clash.kingdom = self
		battle.add_child(clash)
	clash.update(dt)


# the loser lives (spared or captured): same ending as a fallen king, without the death
func duel_end_manual(loser_t: int, winner_t: int) -> void:
	if battle.duel_active:
		battle.duel_active = false
		battle.freeze_others = false
		duel_done = true
		ev_all("duel_end", {"loser": loser_t})
	if nk == 2:
		battle.finish(winner_t, "duel")
	else:
		damage_castle(loser_t, 1e9, winner_t)


func on_king_death(u) -> void:
	if not is_srv:
		return
	if battle.duel_active or final_team == u.team:
		battle.duel_active = false
		battle.freeze_others = false
		duel_done = true
		ev_all("duel_end", {"loser": u.team})
		var winner_t: int = battle.duel_other(u.team)
		var loser_t: int = u.team
		var timer := get_tree().create_timer(3.0)
		if nk == 2:
			timer.timeout.connect(func(): battle.finish(winner_t, "duel"))
		else:
			timer.timeout.connect(func(): damage_castle(loser_t, 1e9, winner_t))
		return
	respawn[u.team] = {"t": KING_RESPAWN, "owner": u.owner_id}
	ev_all("king_down", {"team": u.team})


func _tick_respawn(dt: float) -> void:
	for t in respawn.keys():
		respawn[t].t -= dt
		if respawn[t].t <= 0.0:
			var owner: int = respawn[t].owner
			respawn.erase(t)
			var h = battle._make_unit("hero", t, owner, home_pos(t) + battle.rotv(t, Vector3(0, 0, -3.0)))
			battle.sfx.play("horn", h.position, 0.0, 1.3)
			break


# ================================================================== visuals: duel
func _duel_visual_start(c: Vector3) -> void:
	battle.duel_active = true
	battle.freeze_others = true
	battle.duel_center = c
	battle.duel_r = DUEL_R0
	duel_t = 0.0
	if duel_ring != null and is_instance_valid(duel_ring):
		duel_ring.queue_free()
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.96
	tm.outer_radius = 1.0
	tm.rings = 64
	tm.ring_segments = 8
	ring.mesh = tm
	ring.material_override = battle._mat(Color(1.0, 0.45, 0.12), 0.5, 0.0, 4.0)
	ring.position = c + Vector3(0, 0.15, 0)
	ring.scale = Vector3(DUEL_R0, 3.0, DUEL_R0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	battle.add_child(ring)
	duel_ring = ring
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 4.0
	l.omni_range = 30.0
	l.position = Vector3(0, 3.0, 0)
	ring.add_child(l)
	battle.sfx.play_ui("horn", 3.0)
	battle.banner("DUEL OF KINGS", Color(1.0, 0.7, 0.2), 1.0)
	var ka = battle.team_king(int(battle.duel_teams[0]))
	var kb = battle.team_king(int(battle.duel_teams[1]))
	if ka != null and kb != null:
		var mid: Vector3 = (ka.position + kb.position) * 0.5
		var axis: Vector3 = (kb.position - ka.position)
		axis.y = 0.0
		var side: Vector3 = axis.normalized().cross(Vector3.UP) * 7.0
		battle.cine_shot(mid + side + Vector3(0, 1.1, 0), mid + side * 0.55 + Vector3(0, 1.9, 0), ka.position + Vector3(0, 1.6, 0), mid + Vector3(0, 1.7, 0), 3.2)
		battle.banner("%s  VS  %s" % [king_name(int(battle.duel_teams[0])).to_upper(), king_name(int(battle.duel_teams[1])).to_upper()], Color(1.0, 0.85, 0.35), 3.0)
		var tmr := get_tree().create_timer(3.3)
		tmr.timeout.connect(func():
			if battle.duel_active:
				battle.cine_orbit(c + Vector3(0, 1.5, 0), 17.0, 6.5, 3.8, 1.5))
	else:
		battle.cine_orbit(c + Vector3(0, 1.5, 0), 17.0, 6.5, 3.8, 1.5)
	battle._slowmo(0.55, 1.4)


func _duel_visual_end() -> void:
	battle.duel_active = false
	battle.freeze_others = false
	if duel_ring != null and is_instance_valid(duel_ring):
		duel_ring.queue_free()
	duel_ring = null


# ================================================================== AI king (host)
const AI_PLAN := [
	["woodcutter", 1, 1], ["farm", 1, 1], ["hunter", 1, 1], ["house", 3, 1], ["woodcutter", 2, 1], ["quarry", 1, 1], ["barracks", 1, 1], ["mill", 1, 1], ["bakery", 1, 1],
	["barracks", 1, 1], ["house", 4, 1], ["mine", 1, 1], ["smithy", 1, 1], ["woodcutter", 2, 1], ["farm", 2, 1],
	["house", 6, 1], ["market", 1, 1], ["quarry", 2, 2], ["mine", 2, 2], ["storehouse", 1, 2], ["house", 8, 2],
	["church", 1, 2], ["stable", 1, 3], ["farm", 3, 2], ["house", 10, 3], ["barracks", 2, 3], ["bakery", 2, 3], ["mill", 2, 3], ["well", 1, 2],
]


func _ai_build(t: int, owner: int) -> bool:
	var open_sites := 0
	for b in town.bld[t]:
		if float(b.prog) < 1.0:
			open_sites += 1
	if open_sites >= 2:
		return false
	for e in AI_PLAN:
		var type: String = e[0]
		if level[t] < int(e[2]):
			continue
		if town.count(t, type, false) >= int(e[1]):
			continue
		var def: Dictionary = TownS.DEFS[type]
		if not town.afford(t, def.cost):
			# save up for it, unless something cheap and useful is missing
			return false
		if town.missing_for(t, type) != "":
			continue
		var sp: Vector2 = town.find_spot(t, type)
		if sp.x < -900.0:
			continue
		_cmd(owner, "build", {"type": type, "lx": sp.x, "d": sp.y})
		return true
	return false


func _ai_tick(t: int) -> void:
	var owner := -100 - t
	var lv: int = level[t]
	var houses := count_slots(t, 1)
	var barr := count_slots(t, 2)
	var info: Dictionary = ai_info[t]
	if not info.has("greeted") and battle.game_time > 30.0:
		info["greeted"] = true
		var txt := "Greetings, neighbour king. My lands prosper - see that yours do too."
		_send_letter(t, txt, owner)
	if float(decree_cd[t].tax) <= 0.0:
		_cmd(owner, "tax", {})
	var my_foes: Array = battle.foes_of(t)
	if float(decree_cd[t].feast) <= 0.0 and not my_foes.is_empty() and food[t] > 120:
		_cmd(owner, "feast", {})
	# merchant caravans: the AI turns spare gold into timber and bread (no market micro-management)
	if float(info.get("cara", 0.0)) <= battle.game_time and gold[t] > 250.0 and (wood[t] < 50.0 or food[t] < 20.0):
		info["cara"] = battle.game_time + 20.0
		gold[t] -= 60.0
		if wood[t] < 50.0:
			wood[t] += 45.0
		if food[t] < 20.0:
			food[t] += 30.0
	var actions := 0
	# villagers
	var want_v := 5 + 2 * lv
	if vill_n[t] + queued(t, "villager") < want_v and food[t] >= VILLAGER_FOOD and pop_used[t] < pop_cap(t):
		_cmd(owner, "villager", {})
		actions += 1
	# economy: build the town step by step
	if actions < 2 and _ai_build(t, owner):
		actions += 1
	# castle upgrade
	if actions < 2 and lv < 3 and houses >= 2 + 2 * lv and barr >= 1:
		var cost: Array = UPGRADE[lv - 1]
		if gold[t] >= cost[0] and food[t] >= cost[1]:
			_cmd(owner, "upgrade", {})
			actions += 1
	# recruit
	if actions < 2 and barr >= 1 and vill_n[t] >= 3 and food[t] > 30.0:
		var roll := randf()
		var kind := "sword"
		if lv >= 3 and roll > 0.93:
			kind = "catapult"
		elif lv >= 2 and roll > 0.87:
			kind = "ballista"
		elif lv >= 3 and roll > 0.8:
			kind = "cav"
		elif lv >= 2 and roll > 0.45:
			kind = "archer"
		if train_block(t, kind) != "":
			kind = "archer" if (lv >= 2 and train_block(t, "archer") == "") else "sword"
		var inf: Array = TRAIN[kind]
		if train_block(t, kind) == "" and gold[t] >= inf[0] and food[t] >= inf[1] + 10 and pop_used[t] < pop_cap(t):
			_cmd(owner, "train", {"kind": kind})
	# smith: better weapons and armour once the town is rich enough
	if actions < 2 and lv >= 2 and town.count(t, "smithy") > 0:
		var wk := "w" if forge_w[t] <= forge_a[t] else "a"
		var lvf: int = forge_w[t] if wk == "w" else forge_a[t]
		if lvf < 3:
			var cf := forge_cost(wk, lvf)
			if gold[t] > float(cf.gold) + 150.0 and iron[t] >= float(cf.iron) and stone[t] >= float(cf.stone):
				_cmd(owner, "forge", {"w": wk})
	# navy (island map)
	if battle.sea and lv >= 2 and actions < 2 and barr >= 1:
		if not yard[t]:
			if gold[t] >= YARD_GOLD + 40 and wood[t] >= YARD_WOOD:
				_cmd(owner, "shipyard", {})
		elif fsh_n[t] < 2 and gold[t] > FISHER_GOLD + 60:
			_cmd(owner, "ship", {"type": "fisher"})
		elif not my_foes.is_empty() and ship_n[t] < MAX_SHIPS and gold[t] > SHIP_GOLD + 80:
			_cmd(owner, "ship", {"type": "ship"})
	if battle.sea and not my_foes.is_empty() and yard[t]:
		var eft: int = battle.foe(t)
		for e in battle.by_team[t]:
			if e.kind == "ship" and not e.dead and not e.has_dest and battle.game_time > 200.0:
				e.dest = battle.keep_on_sea(dock_pos(eft) + battle.rotv(eft, Vector3(randf_range(-14.0, 14.0), 0, 18.0)))
				e.has_dest = true
	# food buying when starving
	if food[t] < 15 and gold[t] > 90 and town.count(t, "market") > 0:
		_cmd(owner, "buyfood", {})
	# army orders once the war has begun
	if not my_foes.is_empty():
		var ft: int = battle.foe(t)
		var mine_n: int = soldier_n[t]
		var their_n: int = soldier_n[ft]
		var mode := 2
		if mine_n >= 5 and (mine_n >= their_n * 0.7 or fallen[ft] or their_n == 0):
			mode = 1
		if not battle.orders.has(owner):
			battle.orders[owner] = {}
		for kk in ["sword", "archer", "cav"]:
			battle.orders[owner][kk] = {"mode": mode, "pos": home_pos(t)}
	# war decision: pick the weakest neighbour we are not fighting yet
	elif battle.game_time > 150.0 + 12.0 * t:
		var mine: int = soldier_n[t]
		var pick := -1
		var best_n := 1000000
		for o in nk:
			if o == t or fallen[o] or at_war(t, o):
				continue
			if soldier_n[o] < best_n:
				best_n = soldier_n[o]
				pick = o
		if pick >= 0 and (mine >= 10 + lv or (mine >= 7 and mine > best_n * 1.8)):
			_send_letter(t, "I have waited long enough. My armies march - defend your castle!", owner, pick)
			_cmd(owner, "war", {"to": pick})


func _ai_read_letter(to_t: int, from_t: int, text: String) -> void:
	if not battle.ai_teams.has(to_t):
		return
	var low := text.to_lower()
	var ar := has_arabic(text)
	var reply := ""
	var warlike := false
	for k in ["war", "attack", "fight", "destroy", "حرب", "هجوم", "اقاتل", "سأدمر"]:
		if low.contains(k):
			warlike = true
	var peaceful := false
	for k in ["peace", "truce", "ally", "friend", "سلام", "هدنة", "تحالف", "صديق"]:
		if low.contains(k):
			peaceful = true
	if warlike:
		reply = "كلماتك تسليني. جيوشي سترد عليك." if ar else "Your threats amuse me, king. My armies will answer."
	elif peaceful:
		reply = "السلام رفاهية للأقوياء... احرس حدودك." if ar else "Peace is a luxury for the strong... guard your borders."
	else:
		var en := ["I read your letter. A king should guard his walls, not his words.", "Send as many letters as you wish; my walls are high.", "Your message reached me. Let us see who rules this valley."]
		var arr := ["قرأت رسالتك. على الملك أن يحرس أسواره لا كلماته.", "أرسل ما شئت من الرسائل، فأسواري عالية.", "وصلتني رسالتك. لنرَ من سيحكم هذا الوادي."]
		reply = (arr if ar else en)[randi() % 3]
	ai_replies.append({"t": 4.0, "team": to_t, "text": reply})


# ================================================================== UI
func _theme(u: float) -> Theme:
	var th := Theme.new()
	th.default_font_size = int(22 * u)
	var sb := func(c: Color, border: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = c
		s.border_color = border
		s.set_border_width_all(int(2 * u))
		s.set_corner_radius_all(int(8 * u))
		s.content_margin_left = 10 * u
		s.content_margin_right = 10 * u
		s.content_margin_top = 6 * u
		s.content_margin_bottom = 6 * u
		return s
	var UiFx2 := preload("res://game/uifx.gd")
	var fx := func(state: String) -> StyleBoxTexture:
		var s: StyleBoxTexture = UiFx2.button(state)
		s.content_margin_left = 10 * u
		s.content_margin_right = 10 * u
		s.content_margin_top = 6 * u
		s.content_margin_bottom = 6 * u
		return s
	th.set_stylebox("normal", "Button", fx.call("normal"))
	th.set_stylebox("hover", "Button", fx.call("hover"))
	th.set_stylebox("pressed", "Button", fx.call("pressed"))
	th.set_stylebox("disabled", "Button", fx.call("disabled"))
	th.set_color("font_color", "Button", Color(1.0, 0.93, 0.75))
	th.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.5))
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	var pn: StyleBoxTexture = UiFx2.panel()
	pn.content_margin_left = 22 * u
	pn.content_margin_right = 22 * u
	pn.content_margin_top = 18 * u
	pn.content_margin_bottom = 18 * u
	th.set_stylebox("panel", "PanelContainer", pn)
	return th


# Coloured HUD button: rounded, glowing border in the accent colour
# compact size for the top HUD row
func _small(b: Button, u: float) -> void:
	b.add_theme_font_size_override("font_size", int(17 * u))
	b.add_theme_constant_override("outline_size", int(3 * u))
	b.add_theme_constant_override("icon_max_width", int(22 * u))
	b.add_theme_constant_override("h_separation", int(4 * u))
	for st in ["normal", "hover", "pressed"]:
		var sb = b.get_theme_stylebox(st)
		if sb is StyleBoxTexture:
			sb.content_margin_left = 6 * u
			sb.content_margin_right = 6 * u
			sb.content_margin_top = 2 * u
			sb.content_margin_bottom = 2 * u


func style_btn(b: Button, _c: Color, u: float, icon := "") -> void:
	preload("res://game/uifx.gd").style_btn(b, u, icon)


func _parch(u: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.89, 0.8, 0.6)
	s.border_color = Color(0.45, 0.3, 0.12)
	s.set_border_width_all(int(6 * u))
	s.set_corner_radius_all(int(12 * u))
	s.content_margin_left = 26 * u
	s.content_margin_right = 26 * u
	s.content_margin_top = 20 * u
	s.content_margin_bottom = 20 * u
	return s


func _label(parent: Node, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _build_ui() -> void:
	var u: float = battle.ui_u
	var vs: Vector2 = battle.vs
	var cl := CanvasLayer.new()
	cl.layer = 7
	add_child(cl)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme(u)
	cl.add_child(root)
	ui["root"] = root
	var rl := Label.new()
	rl.position = Vector2(20, 84) * u
	rl.add_theme_font_size_override("font_size", int(20 * u))
	rl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	rl.add_theme_color_override("font_outline_color", Color.BLACK)
	rl.add_theme_constant_override("outline_size", int(6 * u))
	root.add_child(rl)
	rl.visible = false
	ui["res"] = rl
	var UiFxR := preload("res://game/uifx.gd")
	var rv := VBoxContainer.new()
	rv.position = Vector2(12, 62) * u
	rv.add_theme_constant_override("separation", int(4 * u))
	rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rv)
	ui["chips"] = {}
	var rows := [[["gold", "coin", 100.0, Color(1, 0.9, 0.5)], ["food", "food", 92.0, Color(1, 0.8, 0.75)], ["pop", "pop", 100.0, Color(0.85, 0.92, 1)], ["vill", "vill", 76.0, Color(0.85, 1, 0.8)], ["level", "level", 66.0, Color(1, 0.85, 0.4)]],
		[["wood", "wood", 82.0, Color(1, 0.88, 0.7)], ["stone", "stone", 82.0, Color(0.88, 0.9, 0.95)], ["iron", "iron", 76.0, Color(0.8, 0.88, 1.0)], ["grain", "grain", 76.0, Color(1, 0.92, 0.6)], ["flour", "flour", 76.0, Color(1, 1, 0.9)], ["season", "season", 104.0, Color(1, 0.95, 0.7)]]]
	for row in rows:
		var rh := HBoxContainer.new()
		rh.add_theme_constant_override("separation", int(4 * u))
		rh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rv.add_child(rh)
		for c in row:
			var ch: Dictionary = UiFxR.chip(c[1], u, c[2], c[3])
			rh.add_child(ch.box)
			ui.chips[c[0]] = ch.lbl
	var bld_btn := Button.new()
	bld_btn.text = "BUILD"
	bld_btn.position = Vector2(148, 148) * u
	bld_btn.size = Vector2(124, 44) * u
	bld_btn.pressed.connect(func(): town.ui.open_menu())
	root.add_child(bld_btn)
	style_btn(bld_btn, Color(0.9, 0.65, 0.25), u, "hammer")
	_small(bld_btn, u)
	ui["build"] = bld_btn
	var city := Button.new()
	city.text = "CITY"
	city.position = Vector2(20, 148) * u
	city.size = Vector2(120, 44) * u
	city.pressed.connect(_toggle_panel)
	root.add_child(city)
	style_btn(city, Color(0.35, 0.8, 0.4), u, "city")
	_small(city, u)
	ui["city"] = city
	town.build_ui(root, u, vs)
	# castle bars + status
	var cx := vs.x * 0.5
	var mk_bar := func(x: float, col: Color, title: String) -> ProgressBar:
		var pb := ProgressBar.new()
		pb.position = Vector2(x, 30 * u)
		pb.size = Vector2(250 * u, 16 * u)
		pb.show_percentage = false
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := StyleBoxFlat.new()
		fill.bg_color = col
		pb.add_theme_stylebox_override("fill", fill)
		root.add_child(pb)
		var lb := Label.new()
		lb.text = title
		lb.position = Vector2(x, 4 * u)
		lb.add_theme_font_size_override("font_size", int(18 * u))
		lb.add_theme_color_override("font_outline_color", Color.BLACK)
		lb.add_theme_constant_override("outline_size", int(5 * u))
		root.add_child(lb)
		return pb
	var mine_col: Color = battle.team_col(my_team)
	ui["bar_me"] = mk_bar.call(cx - 262 * u, mine_col, "YOUR CASTLE")
	ui["bar_foe"] = mk_bar.call(cx + 12 * u, battle.team_col(battle.foe(my_team)), "ENEMY CASTLE")
	ui["bar_foe_lbl"] = ui["bar_foe"]
	# the top castle bars are gone: castle health lives on the war map now
	for bn in ["bar_me", "bar_foe"]:
		ui[bn].visible = false
	for ch in root.get_children():
		if ch is Label and ch.position.y < 10 * u and ch.text in ["YOUR CASTLE", "ENEMY CASTLE"]:
			ch.visible = false
	# list of all kingdoms (top right)
	var kl := VBoxContainer.new()
	kl.position = Vector2(20 * u, 300 * u)
	kl.add_theme_constant_override("separation", int(2 * u))
	kl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(kl)
	ui["klist"] = kl
	ui["krows"] = []
	if nk > 2:
		for i in nk:
			var rl2 := Label.new()
			rl2.add_theme_font_size_override("font_size", int(16 * u))
			rl2.add_theme_color_override("font_color", battle.team_col(i).lightened(0.25))
			rl2.add_theme_color_override("font_outline_color", Color.BLACK)
			rl2.add_theme_constant_override("outline_size", int(5 * u))
			rl2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			kl.add_child(rl2)
			ui["krows"].append(rl2)
	var st := Label.new()
	st.position = Vector2(cx - 100 * u, 10 * u)
	st.size = Vector2(200, 38) * u
	st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var stp: StyleBoxFlat = preload("res://game/uifx.gd").plate(18.0 * u, 0.82)
	stp.content_margin_top = 2 * u
	stp.content_margin_bottom = 4 * u
	st.add_theme_stylebox_override("normal", stp)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.add_theme_font_size_override("font_size", int(22 * u))
	st.add_theme_color_override("font_outline_color", Color.BLACK)
	st.add_theme_constant_override("outline_size", int(6 * u))
	root.add_child(st)
	ui["status"] = st
	# city panel
	var panel := PanelContainer.new()
	panel.position = Vector2(cx - 330 * u, 30 * u)
	panel.z_index = 30
	panel.visible = false
	root.add_child(panel)
	ui["panel"] = panel
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(8 * u))
	var psc := ScrollContainer.new()
	psc.custom_minimum_size = Vector2(660 * u, minf(vs.y - 60 * u, 640 * u))
	psc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(psc)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	psc.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var tl := _label(head, "YOUR KINGDOM", int(26 * u), Color(1.0, 0.85, 0.4))
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(60, 46) * u
	close.pressed.connect(_toggle_panel)
	head.add_child(close)
	var stats := Label.new()
	stats.add_theme_font_size_override("font_size", int(22 * u))
	stats.add_theme_color_override("font_color", Color(0.85, 0.95, 0.8))
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.custom_minimum_size = Vector2(640, 0) * u
	vb.add_child(stats)
	ui["stats"] = stats
	var hpbar := ProgressBar.new()
	hpbar.show_percentage = false
	hpbar.custom_minimum_size = Vector2(640, 18) * u
	var hf := StyleBoxFlat.new()
	hf.bg_color = Color(0.3, 0.8, 0.3)
	hpbar.add_theme_stylebox_override("fill", hf)
	vb.add_child(hpbar)
	ui["hpbar"] = hpbar
	var g1 := GridContainer.new()
	g1.columns = 2
	g1.add_theme_constant_override("h_separation", int(8 * u))
	g1.add_theme_constant_override("v_separation", int(8 * u))
	vb.add_child(g1)
	var mkb := func(parent: Node, key: String, cb: Callable, w: float) -> Button:
		var b := Button.new()
		b.custom_minimum_size = Vector2(w, 66) * u
		b.pressed.connect(cb)
		parent.add_child(b)
		ui[key] = b
		var icm := {"b_vill": "vill", "b_food": "food", "b_build": "hammer", "b_upg2": "season", "b_up": "level", "b_repair": "hammer", "b_fw": "sword", "b_fa": "army", "b_sword": "sword", "b_archer": "bow", "b_cav": "horse", "b_ballista": "bow", "b_catapult": "stone", "b_ship": "wood"}
		if icm.has(key):
			b.icon = preload("res://game/uifx.gd").icon(icm[key], int(44 * u))
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", int(30 * u))
			b.add_theme_constant_override("h_separation", int(8 * u))
		return b
	mkb.call(g1, "b_vill", func(): cmd("villager"), 318.0)
	mkb.call(g1, "b_food", func(): cmd("buyfood"), 318.0)
	mkb.call(g1, "b_build", func(): _toggle_panel(); town.ui.open_menu(), 318.0)
	mkb.call(g1, "b_upg2", func(): cmd("upgrade"), 318.0)
	mkb.call(g1, "b_up", func(): cmd("upgrade"), 318.0)
	mkb.call(g1, "b_repair", func(): cmd("repair"), 318.0)
	mkb.call(g1, "b_fw", func(): cmd("forge", {"w": "w"}), 318.0)
	mkb.call(g1, "b_fa", func(): cmd("forge", {"w": "a"}), 318.0)
	_label(vb, "TRAIN SOLDIERS", int(20 * u), Color(0.8, 0.8, 0.85))
	var g2 := HBoxContainer.new()
	g2.add_theme_constant_override("separation", int(8 * u))
	vb.add_child(g2)
	mkb.call(g2, "b_sword", func(): cmd("train", {"kind": "sword"}), 208.0)
	mkb.call(g2, "b_archer", func(): cmd("train", {"kind": "archer"}), 208.0)
	mkb.call(g2, "b_cav", func(): cmd("train", {"kind": "cav"}), 208.0)
	_label(vb, "SIEGE AND SEA", int(20 * u), Color(0.8, 0.8, 0.85))
	var g2b := HBoxContainer.new()
	g2b.add_theme_constant_override("separation", int(8 * u))
	vb.add_child(g2b)
	mkb.call(g2b, "b_ballista", func(): cmd("train", {"kind": "ballista"}), 318.0)
	mkb.call(g2b, "b_catapult", func(): cmd("train", {"kind": "catapult"}), 318.0)
	var g2c := HBoxContainer.new()
	g2c.add_theme_constant_override("separation", int(8 * u))
	vb.add_child(g2c)
	var gtr := GridContainer.new()
	gtr.columns = 2
	gtr.add_theme_constant_override("h_separation", int(8 * u))
	gtr.add_theme_constant_override("v_separation", int(8 * u))
	_label(vb, "MARKET", int(20 * u), Color(0.8, 0.8, 0.85))
	vb.add_child(gtr)
	for tk in ["wood", "stone", "iron", "grain"]:
		var key: String = tk
		mkb.call(gtr, "t_%s_s" % key, func(): cmd("trade", {"res": key, "buy": false}), 318.0)
		mkb.call(gtr, "t_%s_b" % key, func(): cmd("trade", {"res": key, "buy": true}), 318.0)
	mkb.call(g2c, "b_yard", func(): cmd("shipyard"), 318.0)
	mkb.call(g2c, "b_ship", func(): cmd("ship", {"type": "ship"}), 318.0)
	var g2d := HBoxContainer.new()
	g2d.add_theme_constant_override("separation", int(8 * u))
	vb.add_child(g2d)
	mkb.call(g2d, "b_trans", func(): cmd("ship", {"type": "transport"}), 318.0)
	mkb.call(g2d, "b_fisher", func(): cmd("ship", {"type": "fisher"}), 318.0)
	var g3 := HBoxContainer.new()
	g3.add_theme_constant_override("separation", int(8 * u))
	vb.add_child(g3)
	mkb.call(g3, "b_letter", func(): _show_compose(""), 318.0)
	mkb.call(g3, "b_war", func(): _war_press(), 318.0)
	var g4 := HBoxContainer.new()
	vb.add_child(g4)
	var tb: Button = mkb.call(g4, "b_target", func(): cycle_target(), 644.0)
	tb.visible = nk > 2
	mapv = MapS.new()
	mapv.name = "MapView"
	mapv.kingdom = self
	mapv.battle = battle
	add_child(mapv)
	mapv.build_ui(root, u, vs)
	court = CourtS.new()
	court.name = "Court"
	court.kingdom = self
	court.battle = battle
	court.mapv = mapv
	add_child(court)
	court.build_ui(root, u, vs)
	_build_admin(root, u)


func _toggle_panel() -> void:
	var p: PanelContainer = ui.panel
	p.visible = not p.visible
	_update_ui(true)
	battle.sfx.play_ui("coin", -10.0)


var sel_target := -1


# The kingdom whose point of view the screen shows (admin mode can look through another kingdom).
func vteam() -> int:
	if battle.admin and battle.admin_view >= 0 and battle.admin_view < nk:
		return battle.admin_view
	return my_team


func target_team() -> int:
	var vt := vteam()
	if sel_target >= 0 and sel_target < nk and sel_target != vt and not fallen[sel_target]:
		return sel_target
	return battle.foe(vt)


func cycle_target() -> void:
	var cur := target_team()
	for i in nk:
		var c := (cur + 1 + i) % nk
		if c != vteam() and not fallen[c]:
			sel_target = c
			break
	_update_ui(true)


func _war_press() -> void:
	if at_war(vteam(), target_team()):
		return
	if war_confirm > 0.0:
		war_confirm = 0.0
		cmd("war", {"to": target_team()})
		_toggle_panel()
	else:
		war_confirm = 3.0
		_update_ui(true)


func _process(dt: float) -> void:
	if battle == null:
		return
	_tick_messengers(dt)
	_prog(dt)
	gate_t -= dt
	if gate_t <= 0.0:
		gate_t = 0.15
		_update_gates()
	war_confirm = maxf(0.0, war_confirm - dt)
	if battle.duel_active:
		if not is_srv:
			duel_t += dt
			battle.duel_r = lerpf(DUEL_R0, DUEL_R1, clampf(duel_t / DUEL_SHRINK, 0.0, 1.0))
		if duel_ring != null and is_instance_valid(duel_ring):
			var r: float = battle.duel_r
			duel_ring.scale = Vector3(r, 3.0, r)
	ui_t -= dt
	if ui_t <= 0.0:
		ui_t = 0.25
		_update_ui(false)


func _update_ui(force: bool) -> void:
	if ui.is_empty():
		return
	var t := vteam()
	var houses := count_slots(t, 1)
	var res: Label = ui.res
	var cwl: Dictionary = ui.chips
	cwl.gold.text = str(int(gold[t]))
	cwl.food.text = str(int(food[t]))
	cwl.pop.text = "%d/%d" % [pop_used[t], pop_cap(t)]
	cwl.vill.text = str(vill_n[t])
	cwl.level.text = str(level[t])
	cwl.wood.text = str(int(wood[t]))
	cwl.stone.text = str(int(stone[t]))
	cwl.iron.text = str(int(iron[t]))
	cwl.grain.text = str(int(grain[t]))
	cwl.flour.text = str(int(flour[t]))
	cwl.season.text = LocS.t(season_name())
	res.text = LocS.t("GOLD %d    FOOD %d    POP %d/%d    VILLAGERS %d    LV %d" % [int(gold[t]), int(food[t]), pop_used[t], pop_cap(t), vill_n[t], level[t]]) + "\n" + LocS.t("WOOD %d   STONE %d   IRON %d   GRAIN %d   FLOUR %d" % [int(wood[t]), int(stone[t]), int(iron[t]), int(grain[t]), int(flour[t])]) + "   " + LocS.t(season_name())
	var bm: ProgressBar = ui.bar_me
	var bf: ProgressBar = ui.bar_foe
	bm.max_value = CASTLE_HP[level[t] - 1]
	bm.value = castle_hp[t]
	var tt: int = target_team()
	bf.max_value = CASTLE_HP[level[tt] - 1]
	bf.value = castle_hp[tt]
	var ffill := StyleBoxFlat.new()
	ffill.bg_color = battle.team_col(tt)
	bf.add_theme_stylebox_override("fill", ffill)
	if nk > 2:
		var rows: Array = ui.krows
		for i in nk:
			var tag := ""
			if fallen[i]:
				tag = "  X"
			elif at_war(vteam(), i):
				tag = "  WAR"
			elif i == tt:
				tag = "  <"
			var nm: String = battle.team_name(i) + (" (you)" if i == my_team else "")
			var rl3: Label = rows[i]
			rl3.text = LocS.t(nm) + LocS.t(tag) + "  %d" % int(castle_hp[i])
	var st: Label = ui.status
	if battle.duel_active:
		st.text = LocS.t("DUEL OF KINGS")
		st.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	elif at_war(t, tt) or (nk == 2 and battle.war):
		st.text = LocS.t("WAR")
		st.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
	else:
		st.text = LocS.t("PEACE")
		st.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55))
	var panel: PanelContainer = ui.panel
	if not panel.visible and not force:
		return
	var set_b := func(key: String, text: String, ok: bool):
		var b: Button = ui[key]
		b.text = LocS.t(text)
		b.disabled = not ok
	var cap := pop_cap(t)
	set_b.call("b_vill", "Hire Villager\n%d food" % VILLAGER_FOOD, food[t] >= VILLAGER_FOOD and pop_used[t] < cap)
	set_b.call("b_food", "Buy Food\n%d gold -> %d food" % [BUY_GOLD, BUY_FOOD], gold[t] >= BUY_GOLD and town.count(t, "market") > 0)
	set_b.call("b_build", "Build Town\nhouses, farms, mines...", true)
	set_b.call("b_upg2", LocS.t("Season:") + " " + LocS.t(season_name()), false)
	for tk2 in TRADE.keys():
		var tr2: Array = TRADE[tk2]
		var mk_ok: bool = town.count(t, "market") > 0
		set_b.call("t_%s_s" % tk2, LocS.t("Sell") + " %d %s\n+%d " % [tr2[0], LocS.t(tk2), tr2[1]] + LocS.t("gold"), mk_ok and res_get(t, tk2) >= float(tr2[0]))
		set_b.call("t_%s_b" % tk2, LocS.t("Buy") + " %d %s\n-%d " % [tr2[0], LocS.t(tk2), tr2[2]] + LocS.t("gold"), mk_ok and gold[t] >= float(tr2[2]))
	var smi: bool = town.count(t, "smithy") > 0
	var cw := forge_cost("w", mini(forge_w[t], 2))
	var ca := forge_cost("a", mini(forge_a[t], 2))
	set_b.call("b_fw", LocS.t("Sharper Weapons") + " %d/3\n" % forge_w[t] + ("%d " % cw.iron + LocS.t("iron") + "  %d " % cw.gold + LocS.t("gold") if forge_w[t] < 3 else LocS.t("maximum reached")), smi and forge_w[t] < 3 and gold[t] >= float(cw.gold) and iron[t] >= float(cw.iron))
	set_b.call("b_fa", LocS.t("Stronger Armour") + " %d/3\n" % forge_a[t] + ("%d " % ca.iron + LocS.t("iron") + "  %d " % ca.stone + LocS.t("stone") + "  %d " % ca.gold + LocS.t("gold") if forge_a[t] < 3 else LocS.t("maximum reached")), smi and forge_a[t] < 3 and gold[t] >= float(ca.gold) and iron[t] >= float(ca.iron) and stone[t] >= float(ca.stone))
	set_b.call("b_repair", "Repair Walls\n%d gold -> fixes a quarter" % REPAIR_COST, gold[t] >= REPAIR_COST and castle_hp[t] < CASTLE_HP[level[t] - 1] - 1.0)
	var stl: Label = ui.stats
	stl.text = LocS.t("Castle level %d   Soldiers %d   Houses %d   Villagers %d" % [level[t], soldier_n[t], count_slots(t, 1), vill_n[t]])
	var hpb: ProgressBar = ui.hpbar
	hpb.max_value = CASTLE_HP[level[t] - 1]
	hpb.value = castle_hp[t]
	if level[t] < 3:
		var c: Array = UPGRADE[level[t] - 1]
		set_b.call("b_up", "Develop Castle -> Lv%d\n%d gold, %d food" % [level[t] + 1, c[0], c[1]], gold[t] >= c[0] and food[t] >= c[1])
	else:
		set_b.call("b_up", "Castle at max level", false)
	var barr_ok: bool = pop_used[t] < cap
	for pair in [["b_sword", "sword", "Swordsman"], ["b_archer", "archer", "Archer"], ["b_cav", "cav", "Cavalry"]]:
		var inf: Array = TRAIN[pair[1]]
		var txt: String = "%s\n%dg %df" % [pair[2], inf[0], inf[1]]
		if level[t] < inf[3]:
			txt = "%s\nCastle Lv%d" % [pair[2], inf[3]]
		var tbk: String = train_block(t, pair[1])
		var xs := _extra_text(pair[1])
		if tbk != "":
			txt = "%s\n%s" % [pair[2], tbk]
		elif level[t] >= inf[3]:
			txt += xs
		set_b.call(pair[0], txt, barr_ok and tbk == "" and level[t] >= inf[3] and gold[t] >= inf[0] and food[t] >= inf[1] and _extra_ok(t, pair[1]))
	for pair2 in [["b_ballista", "ballista", "Ballista"], ["b_catapult", "catapult", "Catapult"]]:
		var inf2: Array = TRAIN[pair2[1]]
		var txt2: String = "%s\n%dg %df" % [pair2[2], inf2[0], inf2[1]]
		if level[t] < inf2[3]:
			txt2 = "%s\nCastle Lv%d" % [pair2[2], inf2[3]]
		var tbk2: String = train_block(t, pair2[1])
		if tbk2 != "":
			txt2 = "%s\n%s" % [pair2[2], tbk2]
		elif level[t] >= inf2[3]:
			txt2 += _extra_text(pair2[1])
		set_b.call(pair2[0], txt2, barr_ok and tbk2 == "" and level[t] >= inf2[3] and gold[t] >= inf2[0] and food[t] >= inf2[1] and _extra_ok(t, pair2[1]))
	if battle.sea:
		var yok: bool = yard[t]
		if yok:
			set_b.call("b_yard", "Shipyard\nbuilt", false)
		else:
			set_b.call("b_yard", "Build Shipyard\n%dg %d planks" % [YARD_GOLD, YARD_WOOD], level[t] >= 2 and gold[t] >= YARD_GOLD and wood[t] >= YARD_WOOD)
		set_b.call("b_ship", "Warship (%d/%d)\n%dg %d planks" % [ship_n[t], MAX_SHIPS, SHIP_GOLD, SHIP_WOOD], yok and ship_n[t] < MAX_SHIPS and gold[t] >= SHIP_GOLD and wood[t] >= SHIP_WOOD)
		set_b.call("b_trans", "Troop Ship (%d/%d)\n%dg %d planks" % [trn_n[t], MAX_TRANSPORTS, TRANSPORT_GOLD, TRANSPORT_WOOD], yok and trn_n[t] < MAX_TRANSPORTS and gold[t] >= TRANSPORT_GOLD and wood[t] >= TRANSPORT_WOOD)
		set_b.call("b_fisher", "Fishing Boat (%d/%d)\n%dg %d planks" % [fsh_n[t], MAX_FISHERS, FISHER_GOLD, FISHER_WOOD], yok and fsh_n[t] < MAX_FISHERS and gold[t] >= FISHER_GOLD and wood[t] >= FISHER_WOOD)
	else:
		set_b.call("b_yard", "Shipyard\nIsland map only", false)
		set_b.call("b_ship", "Warship\nIsland map only", false)
		set_b.call("b_trans", "Troop Ship\nIsland map only", false)
		set_b.call("b_fisher", "Fishing Boat\nIsland map only", false)
	set_b.call("b_letter", "Write Letter\nsend a messenger", true)
	var wb: Button = ui.b_war
	var tbn: Button = ui.b_target
	tbn.text = LocS.t("Target: ") + LocS.t(battle.team_name(tt)) + "  " + LocS.t("(tap to change)")
	if at_war(t, tt):
		wb.text = LocS.t("WAR IS ON")
		wb.disabled = true
	else:
		wb.disabled = fallen[tt]
		wb.text = LocS.t("TAP AGAIN TO CONFIRM" if war_confirm > 0.0 else "Declare War\nattack the other king")


func _modal(title: String, user: float) -> Array:
	var u: float = user
	var vs: Vector2 = battle.vs
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.root.add_child(dim)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _parch(u))
	pc.position = Vector2(vs.x * 0.5 - 360 * u, 40 * u)
	pc.custom_minimum_size = Vector2(720, 300) * u
	dim.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(10 * u))
	pc.add_child(vb)
	_label(vb, title, int(28 * u), Color(0.35, 0.18, 0.05))
	battle.modal = true
	return [dim, vb]


func _close_modal(dim: Control) -> void:
	dim.queue_free()
	battle.modal = false
	if not inbox.is_empty():
		var nx: Dictionary = inbox.pop_front()
		_show_reader.call_deferred(String(nx.from), String(nx.text))


func _show_compose(prefill: String) -> void:
	var u: float = battle.ui_u
	if ui.panel.visible:
		_toggle_panel()
	var m := _modal("WRITE A LETTER TO THE OTHER KING", u)
	var dim: Control = m[0]
	var vb: VBoxContainer = m[1]
	var te := TextEdit.new()
	te.placeholder_text = "Write your message here..."
	te.text = prefill
	te.custom_minimum_size = Vector2(660, 190) * u
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.text_direction = Control.TEXT_DIRECTION_AUTO
	te.add_theme_font_size_override("font_size", int(26 * u))
	te.add_theme_color_override("font_color", Color(0.22, 0.12, 0.04))
	te.add_theme_color_override("font_placeholder_color", Color(0.5, 0.38, 0.22))
	te.add_theme_color_override("caret_color", Color(0.4, 0.1, 0.05))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.95, 0.88, 0.7)
	bg.set_corner_radius_all(int(6 * u))
	te.add_theme_stylebox_override("normal", bg)
	te.add_theme_stylebox_override("focus", bg)
	vb.add_child(te)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(12 * u))
	vb.add_child(row)
	var send := Button.new()
	send.text = "SEND MESSENGER"
	send.custom_minimum_size = Vector2(330, 62) * u
	send.pressed.connect(func():
		var txt := te.text.strip_edges()
		if txt.is_empty():
			battle._toast("The paper is empty!", 1.5)
			return
		cmd("letter", {"text": txt.substr(0, 240), "to": target_team()})
		_close_modal(dim))
	row.add_child(send)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(200, 62) * u
	cancel.pressed.connect(func(): _close_modal(dim))
	row.add_child(cancel)
	te.grab_focus()


func _show_reader(from_name: String, text: String) -> void:
	if battle.modal:
		inbox.append({"from": from_name, "text": text})
		battle._toast("A messenger has arrived - read the letter when you finish.", 3.0)
		return
	var u: float = battle.ui_u
	var m := _modal("A MESSENGER HAS ARRIVED", u)
	var dim: Control = m[0]
	var vb: VBoxContainer = m[1]
	_label(vb, "Letter from %s:" % from_name, int(22 * u), Color(0.45, 0.25, 0.08))
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(660, 150) * u
	body.text_direction = Control.TEXT_DIRECTION_AUTO
	body.add_theme_font_size_override("font_size", int(28 * u))
	body.add_theme_color_override("font_color", Color(0.2, 0.1, 0.03))
	vb.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(12 * u))
	vb.add_child(row)
	var reply := Button.new()
	reply.text = "Write Reply"
	reply.custom_minimum_size = Vector2(260, 62) * u
	reply.pressed.connect(func():
		_close_modal(dim)
		_show_compose(""))
	row.add_child(reply)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(200, 62) * u
	close.pressed.connect(func(): _close_modal(dim))
	row.add_child(close)


# ================================================================== admin mode (secret code typed to the advisor)
func set_admin(on: bool) -> void:
	battle.admin = on
	battle.reveal = on
	if not on:
		battle.admin_view = -1
		battle.admin_ctrl = false
		Engine.time_scale = 1.0
	if ui.has("b_admin"):
		ui.b_admin.visible = on
	if not on and ui.has("apanel"):
		ui.apanel.visible = false
	_update_ui(true)


func vs_x_half(_u: float) -> float:
	return battle.vs.x * 0.5


func _build_admin(root: Control, u: float) -> void:
	var b := Button.new()
	b.text = "ADMIN"
	b.position = Vector2(700, 148) * u
	b.size = Vector2(120, 44) * u
	b.visible = false
	b.pressed.connect(func(): ui.apanel.visible = not ui.apanel.visible; _admin_refresh())
	root.add_child(b)
	ui["b_admin"] = b
	var p := PanelContainer.new()
	p.position = Vector2(vs_x_half(u) - 215 * u, 190 * u)
	p.visible = false
	root.add_child(p)
	ui["apanel"] = p
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(6 * u))
	p.add_child(vb)
	_label(vb, "ADMIN MODE", int(24 * u), Color(1.0, 0.6, 0.3))
	var mk := func(key: String, cb: Callable) -> void:
		var bt := Button.new()
		bt.custom_minimum_size = Vector2(430, 54) * u
		bt.pressed.connect(cb)
		vb.add_child(bt)
		ui[key] = bt
	mk.call("a_view", func():
		var cur := vteam()
		var nxt := (cur + 1) % nk
		battle.admin_view = nxt if nxt != my_team else -1
		if battle.admin_view < 0:
			battle.admin_ctrl = false
		battle.cam_yaw = ang(vteam())
		sel_target = -1
		_admin_refresh()
		_update_ui(true))
	mk.call("a_ctrl", func():
		battle.admin_ctrl = not battle.admin_ctrl
		_admin_refresh())
	mk.call("a_fog", func():
		battle.reveal = not battle.reveal
		_admin_refresh())
	mk.call("a_speed", func():
		var sp := Engine.time_scale
		Engine.time_scale = 2.0 if sp < 1.5 else (4.0 if sp < 3.0 else 1.0)
		_admin_refresh())
	mk.call("a_gold", func():
		if is_srv:
			var vt := vteam()
			gold[vt] += 500.0
			food[vt] += 300.0
		_admin_refresh())


func _admin_refresh() -> void:
	if not ui.has("a_view"):
		return
	var vt := vteam()
	ui.a_view.text = LocS.t("View: ") + LocS.t(battle.team_name(vt)) + (" (you)" if vt == my_team else "") + "  " + LocS.t("(tap to switch)")
	var can_ctrl: bool = vt != my_team and not net.online
	ui.a_ctrl.disabled = not can_ctrl
	ui.a_ctrl.text = LocS.t("Control this kingdom: ") + (LocS.t("ON") if battle.admin_ctrl and can_ctrl else LocS.t("OFF"))
	ui.a_fog.text = LocS.t("See everything: ") + (LocS.t("ON") if battle.reveal else LocS.t("OFF"))
	ui.a_speed.text = LocS.t("Game speed: x%d") % int(Engine.time_scale)
	ui.a_gold.text = LocS.t("+500 gold, +300 food")
	ui.a_gold.disabled = not is_srv
