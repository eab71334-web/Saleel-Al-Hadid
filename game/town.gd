extends Node
# The town of every kingdom: freely placed buildings, resource nodes behind the castle,
# construction by builders, workers and the production chain
# (forest -> wood, quarry -> stone, mine -> iron, farm -> grain -> mill -> flour -> bakery -> bread).
# Host-authoritative: the host simulates, clients receive a compact copy in the kingdom state.

const LocS := preload("res://game/loc.gd")
const ModelsT := preload("res://game/townmodels.gd")
const TownUIS := preload("res://game/townui.gd")

const POSTERN_X := -24.0
const GRID := 1.0
const GAP := 0.7

# zone 0 = inside the walls, 1 = land behind the castle, 2 = either
# cost keys: wood stone iron gold
const DEFS := {
	"house": {"name": "House", "zone": 0, "hx": 2.6, "hz": 2.3, "cost": {"wood": 14, "stone": 4}, "time": 16.0, "workers": 0, "max": 30,
		"desc": "Families live here. +4 population and a little tax."},
	"woodcutter": {"name": "Woodcutter's Hut", "zone": 1, "hx": 2.4, "hz": 2.2, "cost": {"wood": 10}, "time": 12.0, "workers": 2, "max": 4, "res": "wood",
		"desc": "Fells trees. Build it right next to a forest."},
	"quarry": {"name": "Quarry", "zone": 1, "hx": 3.6, "hz": 3.2, "cost": {"wood": 18}, "time": 18.0, "workers": 3, "max": 3, "res": "stone",
		"desc": "Cuts stone. Build it next to a rock outcrop."},
	"mine": {"name": "Iron Mine", "zone": 1, "hx": 3.2, "hz": 3.2, "cost": {"wood": 20, "stone": 8}, "time": 24.0, "workers": 3, "max": 3, "res": "iron",
		"desc": "Digs iron ore. Build it next to an ore vein."},
	"farm": {"name": "Wheat Farm", "zone": 1, "hx": 5.5, "hz": 5.5, "cost": {"wood": 12}, "time": 14.0, "workers": 2, "max": 6,
		"desc": "Grows wheat. Needs a mill and a bakery to become bread."},
	"hunter": {"name": "Hunting Lodge", "zone": 1, "hx": 2.4, "hz": 2.4, "cost": {"wood": 12}, "time": 12.0, "workers": 1, "max": 2,
		"desc": "Hunters bring in game meat."},
	"mill": {"name": "Windmill", "zone": 2, "hx": 3.2, "hz": 3.2, "cost": {"wood": 20, "stone": 10}, "time": 20.0, "workers": 1, "max": 2,
		"desc": "Grinds wheat into flour."},
	"bakery": {"name": "Bakery", "zone": 0, "hx": 2.8, "hz": 2.6, "cost": {"wood": 12, "stone": 12}, "time": 18.0, "workers": 1, "max": 2,
		"desc": "Bakes flour into bread (food)."},
	"storehouse": {"name": "Storehouse", "zone": 2, "hx": 3.4, "hz": 3.0, "cost": {"wood": 20}, "time": 14.0, "workers": 0, "max": 3,
		"desc": "Raises the storage limit of every material."},
	"market": {"name": "Market", "zone": 0, "hx": 4.0, "hz": 3.4, "cost": {"wood": 25, "stone": 12, "gold": 30}, "time": 24.0, "workers": 1, "max": 1,
		"desc": "Merchants pay taxes. Buy and sell goods here."},
	"smithy": {"name": "Smithy", "zone": 0, "hx": 3.2, "hz": 3.0, "cost": {"wood": 15, "stone": 25, "iron": 5}, "time": 26.0, "workers": 0, "max": 1,
		"desc": "Forges swords, armour and siege parts from iron."},
	"barracks": {"name": "Barracks", "zone": 0, "hx": 4.0, "hz": 3.2, "cost": {"wood": 30, "stone": 25}, "time": 28.0, "workers": 0, "max": 2,
		"desc": "Trains soldiers. A second one needs castle level 3."},
	"stable": {"name": "Stable", "zone": 0, "hx": 4.2, "hz": 3.4, "cost": {"wood": 35, "stone": 10}, "time": 26.0, "workers": 0, "max": 1,
		"desc": "Needed to train cavalry."},
	"church": {"name": "Church", "zone": 0, "hx": 3.6, "hz": 5.0, "cost": {"wood": 30, "stone": 55, "gold": 40}, "time": 40.0, "workers": 0, "max": 1,
		"desc": "Prayers and donations: steady gold and calm villagers."},
	"well": {"name": "Well", "zone": 0, "hx": 1.6, "hz": 1.6, "cost": {"wood": 4, "stone": 10}, "time": 10.0, "workers": 0, "max": 2,
		"desc": "Fresh water. Protects the town from fires."},
}
const ORDER := ["house", "woodcutter", "quarry", "mine", "farm", "mill", "bakery", "hunter", "storehouse", "market", "smithy", "barracks", "stable", "church", "well"]

# town rect (lx0, lx1, d0, d1) for each zone
const RECT_TOWN := [-33.0, 33.0, 80.5, 118.8]
const RECT_LAND := [-54.0, 54.0, 127.5, 176.0]
# reserved: x0, x1, d0, d1
const RESERVED := [
	[-12.8, 12.8, 100.5, 119.5],     # keep and throne hall
	[-4.6, 4.6, 74.0, 104.0],        # main street
	[-14.4, -9.6, 76.0, 100.0],      # stairs to the wall walk
	[9.6, 14.4, 76.0, 100.0],
	[-27.4, -20.6, 100.0, 176.0],    # lane to the postern gate and the fields
]
# resource nodes: kind -> [amount, radius]
const NODE_KINDS := {"wood": [420.0, 7.5], "stone": [300.0, 4.6], "iron": [220.0, 4.2]}

var kingdom
var battle
var nk := 2
var next_id := 1
var bld := []              # per team: Array of Dictionary {id, type, lx, d, prog, node, present, idle}
var nodes := []            # per team: Array of Dictionary {kind, lx, d, amt, max, r}
var vis := {}              # building id -> Node3D (this peer)
var node_vis := []         # per team: Array of Node3D
var job_t := 0.0
var tick_t := 0.0
var ver := 0
var _spin := 0.0
var ui: Node = null


func setup() -> void:
	kingdom = get_parent()
	battle = kingdom.battle
	nk = kingdom.nk
	bld = []
	nodes = []
	node_vis = []
	for t in nk:
		bld.append([])
		nodes.append([])
		node_vis.append([])
		_gen_nodes(t)
		_build_node_visuals(t)
	_make_paths()


func build_ui(root: Control, u: float, vs: Vector2) -> void:
	ui = TownUIS.new()
	ui.name = "TownUI"
	add_child(ui)
	ui.setup(self, root, u, vs)


# ------------------------------------------------------------------ geometry helpers
func world(t: int, lx: float, d: float) -> Vector3:
	return kingdom.lw(t, Vector3(lx, 0.0, -d))


func rect_of(def: Dictionary) -> Vector2:
	return Vector2(float(def.hx), float(def.hz))


func def_of(type: String) -> Dictionary:
	return DEFS[type]


func get_b(id: int):
	for t in nk:
		for b in bld[t]:
			if int(b.id) == id:
				return b
	return null


func count(t: int, type: String, done_only := true) -> int:
	var n := 0
	for b in bld[t]:
		if b.type == type and (not done_only or float(b.prog) >= 1.0):
			n += 1
	return n


func solid(t: int, l: Vector3) -> bool:
	# l = local position of a unit; buildings are solid rectangles
	var d := -l.z
	if d < 79.0 or absf(l.x) > 62.0 or d > 182.0:
		return false
	for b in bld[t]:
		var def: Dictionary = DEFS[b.type]
		if absf(l.x - float(b.lx)) < float(def.hx) + 0.35 and absf(d - float(b.d)) < float(def.hz) + 0.35:
			return true
	return false


# where a worker stands to use the building (in front of the door, which faces the castle gate)
func work_pos(t: int, b: Dictionary, uid := 0) -> Vector3:
	var def: Dictionary = DEFS[b.type]
	var off := float((uid % 3) - 1) * 1.3
	return world(t, float(b.lx) + off, float(b.d) - float(def.hz) - 1.4)


func site_pos(t: int, b: Dictionary) -> Vector3:
	return world(t, float(b.lx), float(b.d))


func storage_cap(t: int) -> float:
	return 300.0 + 250.0 * float(count(t, "storehouse"))


# ------------------------------------------------------------------ resource nodes
func _gen_nodes(t: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9100 + t * 17
	var plan := ["wood", "stone", "wood", "iron", "wood", "stone", "iron"]
	var placed: Array = []
	for kind in plan:
		var nd: Array = NODE_KINDS[kind]
		for attempt in 80:
			var lx := rng.randf_range(-46.0, 46.0)
			var d := rng.randf_range(134.0, 170.0)
			if absf(lx - POSTERN_X) < 8.0:
				continue
			var ok := true
			for o in placed:
				if Vector2(lx - float(o.lx), d - float(o.d)).length() < float(o.r) + float(nd[1]) + 14.0:
					ok = false
					break
			if not ok:
				continue
			# keep the node on the island (sea maps)
			if battle.sea:
				var w: Vector3 = world(t, lx, d)
				if Vector2(w.x, w.z).length() > battle.coast_r - float(nd[1]) - 6.0:
					continue
			var n := {"kind": kind, "lx": lx, "d": d, "amt": float(nd[0]), "max": float(nd[0]), "r": float(nd[1])}
			nodes[t].append(n)
			placed.append(n)
			break


func nearest_node(t: int, kind: String, lx: float, d: float, reach := 99.0) -> int:
	var best := -1
	var bd := reach
	for i in nodes[t].size():
		var n: Dictionary = nodes[t][i]
		if n.kind != kind:
			continue
		var dist := Vector2(lx - float(n.lx), d - float(n.d)).length() - float(n.r)
		if dist < bd:
			bd = dist
			best = i
	return best


# ------------------------------------------------------------------ placement rules
# returns "" when the building can be placed there, otherwise the reason (English key)
func check(t: int, type: String, lx: float, d: float) -> String:
	if not DEFS.has(type):
		return "Unknown building"
	var def: Dictionary = DEFS[type]
	var hx: float = def.hx
	var hz: float = def.hz
	var zone: int = def.zone
	var in_town: bool = lx - hx >= RECT_TOWN[0] and lx + hx <= RECT_TOWN[1] and d - hz >= RECT_TOWN[2] and d + hz <= RECT_TOWN[3]
	var in_land: bool = lx - hx >= RECT_LAND[0] and lx + hx <= RECT_LAND[1] and d - hz >= RECT_LAND[2] and d + hz <= RECT_LAND[3]
	if zone == 0 and not in_town:
		return "Build this inside the castle walls"
	if zone == 1 and not in_land:
		return "Build this on the land behind the castle"
	if zone == 2 and not (in_town or in_land):
		return "Not allowed here"
	if in_land and battle.sea:
		for c in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(-hx, hz), Vector2(hx, hz)]:
			var w: Vector3 = world(t, lx + c.x, d + c.y)
			if Vector2(w.x, w.z).length() > battle.coast_r - 5.0:
				return "Too close to the sea"
	for r in RESERVED:
		if lx + hx > float(r[0]) - 0.2 and lx - hx < float(r[1]) + 0.2 and d + hz > float(r[2]) - 0.2 and d - hz < float(r[3]) + 0.2:
			return "That spot is needed for a road or stairs"
	for b in bld[t]:
		var o: Dictionary = DEFS[b.type]
		if absf(lx - float(b.lx)) < hx + float(o.hx) + GAP and absf(d - float(b.d)) < hz + float(o.hz) + GAP:
			return "Something is already built there"
	for n in nodes[t]:
		if Vector2(lx - float(n.lx), d - float(n.d)).length() < float(n.r) + maxf(hx, hz) * 0.55 + 0.6:
			return "A resource is in the way"
	if def.has("res"):
		var ni := nearest_node(t, String(def.res), lx, d, 9.0)
		if ni < 0:
			match String(def.res):
				"wood":
					return "Needs a forest within reach"
				"stone":
					return "Needs a rock outcrop within reach"
				_:
					return "Needs an ore vein within reach"
	return ""


func limit_for(t: int, type: String) -> int:
	var def: Dictionary = DEFS[type]
	var m: int = def.max
	if type == "barracks":
		m = 1 if kingdom.level[t] < 3 else 2
	return m


func missing_for(t: int, type: String) -> String:
	# prerequisites other than land and money
	match type:
		"barracks":
			if kingdom.level[t] < 1:
				return ""
		"stable":
			if count(t, "barracks") < 1:
				return "Build a barracks first"
		"church":
			if kingdom.level[t] < 2:
				return "Castle level 2 needed"
		"market":
			if count(t, "house") < 2:
				return "Needs 2 houses"
		"smithy":
			if count(t, "mine") < 1 and kingdom.iron[t] < 5.0:
				return ""
	return ""


func afford(t: int, cost: Dictionary) -> bool:
	for k in cost.keys():
		if kingdom.res_get(t, String(k)) < float(cost[k]):
			return false
	return true


func cost_text(def: Dictionary) -> String:
	var parts := []
	var names := {"wood": "wood", "stone": "stone", "iron": "iron", "gold": "gold"}
	for k in def.cost.keys():
		parts.append("%d %s" % [int(def.cost[k]), LocS.t(String(names[k]))])
	return "  ".join(parts)


# build order (host). Returns "" on success or the reason.
func place(t: int, type: String, lx: float, d: float, free := false) -> String:
	var def: Dictionary = DEFS.get(type, {})
	if def.is_empty():
		return "Unknown building"
	lx = roundf(lx / GRID) * GRID
	d = roundf(d / GRID) * GRID
	var why := check(t, type, lx, d)
	if why != "":
		return why
	if count(t, type, false) >= limit_for(t, type):
		return "You already have the maximum of these"
	var pre := missing_for(t, type)
	if pre != "":
		return pre
	if not free:
		if not afford(t, def.cost):
			return "Not enough materials"
		for k in def.cost.keys():
			kingdom.res_add(t, String(k), -float(def.cost[k]))
	var b := {"id": next_id, "type": type, "lx": lx, "d": d, "prog": 1.0 if free else 0.0, "node": -1, "present": 0, "idle": false, "wk": 0}
	next_id += 1
	if def.has("res"):
		b.node = nearest_node(t, String(def.res), lx, d, 9.0)
	bld[t].append(b)
	ver += 1
	return ""


func demolish(t: int, id: int) -> void:
	for i in bld[t].size():
		var b: Dictionary = bld[t][i]
		if int(b.id) == id:
			var def: Dictionary = DEFS[b.type]
			if b.type == "house" and count(t, "house") <= 1:
				return
			for k in def.cost.keys():
				kingdom.res_add(t, String(k), float(def.cost[k]) * 0.4)
			bld[t].remove_at(i)
			ver += 1
			return


func destroy(t: int, id: int) -> void:
	for i in bld[t].size():
		if int(bld[t][i].id) == id:
			bld[t].remove_at(i)
			ver += 1
			return


# ------------------------------------------------------------------ simulation (host)
func _process(dt: float) -> void:
	_spin += dt
	sync_visuals()
	if not kingdom.is_srv:
		return
	tick_t -= dt
	if tick_t <= 0.0:
		var step := 0.25 - tick_t
		tick_t = 0.25
		_tick(step)
	job_t -= dt
	if job_t <= 0.0:
		job_t = 1.0
		for t in nk:
			_assign_jobs(t)


func season_mult() -> float:
	return kingdom.season_farm()


func _tick(dt: float) -> void:
	# presence: villagers standing at their workplace
	var pres := {}
	for u in battle.units.values():
		if u.kind == "villager" and not u.dead and u.job >= 0 and u.jstate == 1:
			pres[u.job] = int(pres.get(u.job, 0)) + 1
	for t in nk:
		var cap := storage_cap(t)
		for b in bld[t]:
			var def: Dictionary = DEFS[b.type]
			var p: int = int(pres.get(int(b.id), 0))
			b.present = p
			if float(b.prog) < 1.0:
				if p > 0:
					b.prog = minf(1.0, float(b.prog) + float(p) * dt * kingdom.build_mult(t) / float(def.time))
					if float(b.prog) >= 1.0:
						_finished(t, b)
				continue
			_produce(t, b, def, p, dt, cap)
		# nodes regrow slowly (forests only)
		for n in nodes[t]:
			if n.kind == "wood" and float(n.amt) < float(n.max):
				n.amt = minf(float(n.max), float(n.amt) + 0.25 * dt)


func _finished(t: int, b: Dictionary) -> void:
	ver += 1
	kingdom.ev_all("built", {"team": t, "type": b.type, "x": world(t, float(b.lx), float(b.d)).x, "z": world(t, float(b.lx), float(b.d)).z})
	if b.type == "house" or b.type == "barracks":
		pass


func _produce(t: int, b: Dictionary, def: Dictionary, p: int, dt: float, cap: float) -> void:
	var type: String = b.type
	var k = kingdom
	b.idle = false
	if def.has("res"):
		var ni: int = int(b.node)
		if ni < 0 or ni >= nodes[t].size() or float(nodes[t][ni].amt) <= 0.05:
			b.node = nearest_node(t, String(def.res), float(b.lx), float(b.d), 9.0)
			ni = int(b.node)
			if ni < 0 or float(nodes[t][ni].amt) <= 0.05:
				b.idle = true
				return
		if p <= 0:
			return
		var rate := 0.0
		match type:
			"woodcutter":
				rate = 0.34
			"quarry":
				rate = 0.24
			_:
				rate = 0.17
		var take := minf(rate * float(p) * dt, float(nodes[t][ni].amt))
		var key := "wood" if type == "woodcutter" else ("stone" if type == "quarry" else "iron")
		if k.res_get(t, key) >= cap:
			b.idle = true
			return
		nodes[t][ni].amt = float(nodes[t][ni].amt) - take
		k.res_add(t, key, take)
		return
	if p <= 0:
		return
	match type:
		"farm":
			if k.res_get(t, "grain") < cap:
				k.res_add(t, "grain", 0.33 * float(p) * dt * season_mult())
			else:
				b.idle = true
		"hunter":
			k.res_add(t, "food", 0.22 * float(p) * dt)
		"mill":
			var g: float = k.res_get(t, "grain")
			if g > 0.2 and k.res_get(t, "flour") < cap:
				var x := minf(0.55 * float(p) * dt, g)
				k.res_add(t, "grain", -x)
				k.res_add(t, "flour", x)
			else:
				b.idle = true
		"bakery":
			var f: float = k.res_get(t, "flour")
			if f > 0.2:
				var y := minf(0.42 * float(p) * dt, f)
				k.res_add(t, "flour", -y)
				k.res_add(t, "food", y * 2.0)
			else:
				b.idle = true
		"market":
			k.res_add(t, "gold", 0.35 * float(p) * dt)
	if type == "church":
		pass


# passive income from buildings that need nobody
func passive(t: int, dt: float) -> void:
	k_church(t, dt)


func k_church(t: int, dt: float) -> void:
	var n := count(t, "church")
	if n > 0:
		kingdom.res_add(t, "gold", 0.25 * float(n) * dt * (2.0 if kingdom.trait_has(t, "pious") else 1.0))


# ------------------------------------------------------------------ jobs
func _pkey(t: int, b: Dictionary) -> float:
	if float(b.prog) < 1.0:
		return 0.0
	var def: Dictionary = DEFS[b.type]
	if def.has("res"):
		return 2.0 + clampf(kingdom.res_get(t, String(def.res)) / storage_cap(t), 0.0, 0.99)
	return float(_priority(b.type))


func _priority(type: String) -> int:
	match type:
		"bakery", "mill", "farm":
			return 1
		"woodcutter", "quarry", "mine", "hunter":
			return 2
		_:
			return 3


func _assign_jobs(t: int) -> void:
	var vills := []
	for u in battle.by_team[t]:
		if u.kind == "villager" and not u.dead:
			vills.append(u)
	if vills.is_empty():
		return
	# wanted workers per building
	var want := {}
	var order := []
	for b in bld[t]:
		var def: Dictionary = DEFS[b.type]
		var w := 0
		if float(b.prog) < 1.0:
			w = 3
		elif int(def.workers) > 0 and not bool(b.idle):
			w = int(def.workers)
		if w > 0:
			want[int(b.id)] = w
			order.append(b)
	# split the available villagers by priority: building sites, food chain, then raw materials
	order.sort_custom(func(a, c):
		return _pkey(t, a) < _pkey(t, c))
	var budget := vills.size()
	for b in bld[t]:
		b.wk = 0
	for b in order:
		var al: int = mini(int(want[int(b.id)]), budget)
		budget -= al
		if al > 0:
			want[int(b.id)] = al
		else:
			want.erase(int(b.id))
	order = order.filter(func(b): return want.has(int(b.id)))
	var have := {}
	var free := []
	for u in vills:
		if u.job >= 0 and want.has(u.job) and int(have.get(u.job, 0)) < int(want[u.job]):
			have[u.job] = int(have.get(u.job, 0)) + 1
		else:
			if u.job >= 0:
				u.job = -1
				u.jstate = 0
				u.jwait = 0.0
			free.append(u)
	# construction comes first: pull workers off finished buildings when a site has none
	var short := 0
	for b in order:
		if float(b.prog) < 1.0:
			short += maxi(0, mini(2, int(want[int(b.id)])) - int(have.get(int(b.id), 0)))
	if short > 0:
		for u in vills:
			if short <= 0:
				break
			if u.job >= 0 and want.has(u.job) and not free.has(u):
				var jb = get_b(int(u.job))
				if jb != null and float(jb.prog) >= 1.0:
					have[u.job] = int(have.get(u.job, 0)) - 1
					u.job = -1
					u.jstate = 0
					u.jwait = 0.0
					free.append(u)
					short -= 1
	order.sort_custom(func(a, c):
		var pa: int = 0 if float(a.prog) < 1.0 else _priority(a.type)
		var pc: int = 0 if float(c.prog) < 1.0 else _priority(c.type)
		return pa < pc)
	# keep one villager picking fruit when the food stock is low
	var reserve := 1 if (kingdom.food[t] < 25.0 and vills.size() >= 4) else 0
	for b in order:
		var need: int = int(want[int(b.id)]) - int(have.get(int(b.id), 0))
		var bp: Vector3 = site_pos(t, b)
		while need > 0 and free.size() > reserve:
			var bi := 0
			var bdist := 1e9
			for i in free.size():
				var dd: float = free[i].position.distance_to(bp)
				if dd < bdist:
					bdist = dd
					bi = i
			var u = free[bi]
			free.remove_at(bi)
			u.job = int(b.id)
			u.jstate = 0
			u.jwait = 0.0
			have[int(b.id)] = int(have.get(int(b.id), 0)) + 1
			need -= 1
		b.wk = int(have.get(int(b.id), 0))


# ------------------------------------------------------------------ sync
func pack() -> Dictionary:
	var bl := []
	var nl := []
	for t in nk:
		var a := PackedFloat32Array()
		for b in bld[t]:
			a.append_array(PackedFloat32Array([float(b.id), float(ORDER.find(b.type)), float(b.lx), float(b.d), float(b.prog), float(b.node), float(b.present), 1.0 if b.idle else 0.0]))
		bl.append(a)
		var na := PackedFloat32Array()
		for n in nodes[t]:
			na.append(float(n.amt))
		nl.append(na)
	return {"b": bl, "n": nl, "id": next_id}


func unpack(s: Dictionary) -> void:
	next_id = int(s.id)
	for t in nk:
		var a: PackedFloat32Array = s.b[t]
		var nb := []
		var i := 0
		while i + 7 < a.size():
			nb.append({"id": int(a[i]), "type": ORDER[int(a[i + 1])], "lx": a[i + 2], "d": a[i + 3], "prog": a[i + 4], "node": int(a[i + 5]), "present": int(a[i + 6]), "idle": a[i + 7] > 0.5, "wk": 0})
			i += 8
		bld[t] = nb
		var na: PackedFloat32Array = s.n[t]
		for j in mini(na.size(), nodes[t].size()):
			nodes[t][j].amt = na[j]


# ------------------------------------------------------------------ visuals (every peer)
func _make_paths() -> void:
	var path_m: StandardMaterial3D = battle._mat(Color(0.42, 0.33, 0.21), 1.0)
	for t in nk:
		# path from the postern into the fields
		var m: MeshInstance3D = battle._mesh(battle, battle._box(Vector3(4.6, 0.05, 56.0)), path_m, world(t, POSTERN_X, 150.0) + Vector3(0, 0.03, 0), Vector3(0, kingdom.ang(t), 0), false)
		var m2: MeshInstance3D = battle._mesh(battle, battle._box(Vector3(4.6, 0.05, 24.0)), path_m, world(t, POSTERN_X, 108.0) + Vector3(0, 0.03, 0), Vector3(0, kingdom.ang(t), 0), false)


func _build_node_visuals(t: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4400 + t
	for n in nodes[t]:
		var root := Node3D.new()
		root.position = world(t, float(n.lx), float(n.d))
		root.rotation.y = kingdom.ang(t)
		battle.add_child(root)
		ModelsT.build_node(battle, root, String(n.kind), float(n.r), rng)
		node_vis[t].append(root)


func sync_visuals() -> void:
	var seen := {}
	for t in nk:
		for b in bld[t]:
			var id: int = int(b.id)
			seen[id] = true
			var n = vis.get(id)
			if n == null or not is_instance_valid(n):
				n = ModelsT.make(self, t, String(b.type))
				n.position = world(t, float(b.lx), float(b.d))
				n.rotation.y = kingdom.ang(t)
				battle.add_child(n)
				vis[id] = n
				if kingdom.vis_ready:
					battle.sfx.play("hammer", n.position, -4.0)
			ModelsT.update(self, n, b, _spin)
		# nodes
		for i in nodes[t].size():
			if i < node_vis[t].size():
				ModelsT.update_node(node_vis[t][i], nodes[t][i])
	for id in vis.keys():
		if not seen.has(id):
			var n2 = vis[id]
			if is_instance_valid(n2):
				battle._burst(n2.position + Vector3(0, 1.5, 0), Color(0.6, 0.5, 0.4), 22, 5.0, false)
				n2.queue_free()
			vis.erase(id)


# ------------------------------------------------------------------ AI helpers
func find_spot(t: int, type: String) -> Vector2:
	var def: Dictionary = DEFS[type]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var cands: Array = []
	for attempt in 160:
		var lx := 0.0
		var d := 0.0
		if def.has("res"):
			var ni := -1
			var tries := 0
			var idxs := []
			for i in nodes[t].size():
				if nodes[t][i].kind == def.res and float(nodes[t][i].amt) > 30.0:
					idxs.append(i)
			if idxs.is_empty():
				return Vector2(-999, -999)
			ni = idxs[rng.randi() % idxs.size()]
			var n: Dictionary = nodes[t][ni]
			var a := rng.randf() * TAU
			var rad: float = float(n.r) + maxf(float(def.hx), float(def.hz)) * 0.55 + 1.5 + rng.randf() * 3.0
			lx = float(n.lx) + cos(a) * rad
			d = float(n.d) + sin(a) * rad
		elif int(def.zone) == 0:
			lx = rng.randf_range(RECT_TOWN[0] + 3.0, RECT_TOWN[1] - 3.0)
			d = rng.randf_range(RECT_TOWN[2] + 2.0, RECT_TOWN[3] - 2.0)
		else:
			lx = rng.randf_range(RECT_LAND[0] + 6.0, RECT_LAND[1] - 6.0)
			d = rng.randf_range(RECT_LAND[2] + 4.0, RECT_LAND[3] - 6.0)
		lx = roundf(lx)
		d = roundf(d)
		if check(t, type, lx, d) == "":
			return Vector2(lx, d)
	return Vector2(-999, -999)
