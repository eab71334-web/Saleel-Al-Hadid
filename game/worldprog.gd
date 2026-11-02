extends RefCounted
# Open-world progression: 50 castle levels, costs, income, unlock milestones and the tasks
# (quests) that must be completed before every upgrade.

const MAXL := 50

# stat id -> [text, unit divisor shown, first level the task can appear]
const TASKS := {
	"caches": ["Collect treasure caches", 1],
	"walk": ["Travel on foot (meters)", 1],
	"recruit": ["Recruit soldiers", 2],
	"ride": ["Ride your horse (meters)", 2],
	"sit": ["Sit on your throne", 3],
	"tax": ["Collect tax from people", 3],
	"houses": ["Build houses outside the castle", 4],
	"kills": ["Defeat raiders", 5],
	"visit": ["Greet other lords in their castles", 6],
	"ally": ["Make an alliance", 6],
}

# level -> unlock lines (levels not listed just make the castle bigger and richer)
const UNLOCK := {
	1: ["Castle keep and walls", "Gather treasure around the world"],
	2: ["Barracks: recruit soldiers", "Stable: your horse waits in the garden - call it and ride"],
	3: ["Market: trade resources", "Your throne: sit and hang a portrait", "Collect tax (once or monthly)"],
	4: ["Build houses outside the castle (a soldier must stand guard)"],
	5: ["Raiders appear - defend your realm with sword and soldiers", "Torches light the gate"],
	6: ["Diplomacy: alliances and treaties with lords and players", "Greet other lords"],
	8: ["Muster allies: a united army marches with you", "Forge: stronger soldiers"],
	10: ["Defend allied castles from raiders", "6 towers"],
	12: ["Farms: more wood"],
	14: ["Quarries: more stone", "Taller keep"],
	16: ["Watch beacon fire"],
	22: ["Moat and drawbridge"],
	30: ["9 towers", "Banner ring around your lands"],
	36: ["Royal guard: elite soldiers"],
	42: ["Grand keep"],
	50: ["Emperor: the greatest castle in the realm"],
}


static func scale_of(lv: int) -> float:
	return lerpf(0.8, 2.7, float(clampi(lv, 1, MAXL) - 1) / float(MAXL - 1))


static func tier(lv: int) -> int:
	if lv < 6:
		return 1
	if lv < 14:
		return 2
	if lv < 24:
		return 3
	if lv < 36:
		return 4
	return 5


static func cost(lv: int) -> Array:
	var g := int(110.0 * pow(float(lv), 1.55))
	return [g, int(g * 0.5), int(g * 0.3)]


static func income(lv: int) -> Array:
	var g := 6.0 * pow(float(lv), 1.25)
	return [int(g), int(g * 0.5), int(g * 0.3)]


static func guards(lv: int) -> int:
	if lv < 2:
		return 0
	return mini(24, 2 + lv / 2)


static func max_soldiers(lv: int) -> int:
	return mini(60, 2 + lv)


static func muster_n(lv: int) -> int:
	return clampi(1 + lv / 4, 1, 8)


static func max_houses(lv: int) -> int:
	return mini(40, int(lv * 0.9))


# tasks needed to leave level `lv` (deterministic): array of {id, n}
static func tasks_for(lv: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001 + lv * 77
	var pool: Array = []
	for k in TASKS.keys():
		if int(TASKS[k][1]) <= lv:
			pool.append(k)
	pool.sort()
	var count := 2 if lv % 5 != 0 else 3
	var out: Array = []
	if lv == 1:
		return [{"id": "caches", "n": 2}, {"id": "walk", "n": 300}]
	var guard := 0
	while out.size() < count and guard < 50:
		guard += 1
		var k: String = pool[rng.randi() % pool.size()]
		var dup := false
		for o in out:
			if o.id == k:
				dup = true
		if dup:
			continue
		out.append({"id": k, "n": _amount(k, lv)})
	return out


static func _amount(k: String, lv: int) -> int:
	match k:
		"caches": return 2 + lv / 3
		"walk": return 300 + lv * 70
		"visit": return 1 + lv / 8
		"sit": return 1
		"recruit": return 1 + lv / 5
		"ride": return 400 + lv * 60
		"tax": return 1 + lv / 6
		"houses": return 1 + lv / 8
		"kills": return 3 + lv / 2
		"ally": return 1
	return 1


static func next_unlock(lv: int) -> Array:
	for l in range(lv + 1, MAXL + 1):
		if UNLOCK.has(l):
			return [l, UNLOCK[l]]
	return []
