extends RefCounted
# Player profile: renown (XP), rank titles, achievements and the daily royal decree. Saved in user://profile.cfg

const PATH := "user://profile.cfg"

static var renown := 0
static var games := 0
static var wins := 0
static var ach: Array = []
static var daily_date := ""
static var daily_done := false
static var king_name := ""
static var trait_id := "warlord"
static var diff := "normal"
static var look: Dictionary = {}
static var castle: Dictionary = {}
static var loaded := false

const RANKS := [
	[0, "Peasant"], [60, "Squire"], [160, "Knight"], [320, "Baron"], [560, "Count"],
	[900, "Duke"], [1400, "Prince"], [2100, "King"], [3200, "High King"], [5000, "Emperor"],
]

const TRAITS := {
	"warlord": {"name": "Warlord", "desc": "Soldiers hit 10% harder and train faster."},
	"merchant": {"name": "Merchant King", "desc": "50% more gold from taxes and trade."},
	"builder": {"name": "Master Builder", "desc": "Buildings go up 50% faster."},
	"pious": {"name": "Pious King", "desc": "Churches pay double and the realm holds 4 more people."},
}

const ACH := {
	"builder10": {"name": "Town Planner", "desc": "Have 10 buildings in your town.", "r": 25},
	"town12": {"name": "Master of Trades", "desc": "Build 12 different kinds of buildings.", "r": 70},
	"granary": {"name": "Full Granary", "desc": "Store 250 grain.", "r": 20},
	"rich": {"name": "Dragon's Hoard", "desc": "Hold 1500 gold.", "r": 40},
	"ironwill": {"name": "Iron Will", "desc": "Fully upgrade your weapons or armour.", "r": 60},
	"veteran": {"name": "Seasoned Soldier", "desc": "Train a three-star veteran.", "r": 50},
	"army40": {"name": "Host of Kings", "desc": "Command 40 soldiers at once.", "r": 60},
	"castle3": {"name": "Great Fortress", "desc": "Upgrade the castle to level 3.", "r": 50},
	"fleet": {"name": "Lord of the Seas", "desc": "Own 3 warships.", "r": 70},
	"victor": {"name": "Conqueror", "desc": "Win a match.", "r": 80},
	"flawless": {"name": "Untouched", "desc": "Win without losing your castle walls below half.", "r": 90},
}

const DAILY := [
	{"id": "farms3", "text": "Royal decree: build 3 wheat farms.", "r": 60},
	{"id": "army20", "text": "Royal decree: command 20 soldiers.", "r": 60},
	{"id": "gold800", "text": "Royal decree: hold 800 gold.", "r": 50},
	{"id": "houses8", "text": "Royal decree: raise 8 houses.", "r": 50},
	{"id": "forge2", "text": "Royal decree: forge level-2 weapons.", "r": 70},
	{"id": "bread", "text": "Royal decree: bake bread - own a mill and a bakery.", "r": 50},
]


static func today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


static func load_all() -> void:
	if loaded:
		return
	loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		renown = int(cf.get_value("p", "renown", 0))
		games = int(cf.get_value("p", "games", 0))
		wins = int(cf.get_value("p", "wins", 0))
		ach = Array(cf.get_value("p", "ach", []))
		daily_date = String(cf.get_value("p", "daily_date", ""))
		daily_done = bool(cf.get_value("p", "daily_done", false))
		king_name = String(cf.get_value("p", "king_name", ""))
		trait_id = String(cf.get_value("p", "trait", "warlord"))
		diff = String(cf.get_value("p", "diff", "normal"))
		look = Dictionary(cf.get_value("p", "look", {}))
		castle = Dictionary(cf.get_value("p", "castle", {}))
	if daily_date != today():
		daily_date = today()
		daily_done = false


static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("p", "renown", renown)
	cf.set_value("p", "games", games)
	cf.set_value("p", "wins", wins)
	cf.set_value("p", "ach", ach)
	cf.set_value("p", "daily_date", daily_date)
	cf.set_value("p", "daily_done", daily_done)
	cf.set_value("p", "king_name", king_name)
	cf.set_value("p", "trait", trait_id)
	cf.set_value("p", "diff", diff)
	cf.set_value("p", "look", look)
	cf.set_value("p", "castle", castle)
	cf.save(PATH)


static func rank_index(r: int = -1) -> int:
	var rr := renown if r < 0 else r
	var idx := 0
	for i in RANKS.size():
		if rr >= int(RANKS[i][0]):
			idx = i
	return idx


static func rank_name(r: int = -1) -> String:
	return String(RANKS[rank_index(r)][1])


# progress inside the current rank: [renown into rank, renown needed, next rank name]
static func rank_progress() -> Array:
	var i := rank_index()
	if i >= RANKS.size() - 1:
		return [1, 1, ""]
	var lo: int = int(RANKS[i][0])
	var hi: int = int(RANKS[i + 1][0])
	return [renown - lo, hi - lo, String(RANKS[i + 1][1])]


static func daily_today() -> Dictionary:
	var d := Time.get_date_dict_from_system()
	var h: int = (d.year * 372 + d.month * 31 + d.day) % DAILY.size()
	return DAILY[h]


# returns the rank-up name if the add crossed into a new rank, else ""
static func add_renown(n: int) -> String:
	var before := rank_index()
	renown += n
	save()
	var after := rank_index()
	return rank_name() if after > before else ""


static func unlock(id: String) -> bool:
	if ach.has(id) or not ACH.has(id):
		return false
	ach.append(id)
	add_renown(int(ACH[id].r))
	return true
