extends RefCounted
# Understands short commands in Arabic (incl. Libyan dialect) and English and turns them
# into game actions. Pure text parsing (works offline, no AI service needed).
#
#   parse(text) -> Array of {act, n, kind, mode, mask, where, pct, text, what}

const AR_NUM := {
	"واحد": 1, "وحده": 1, "اثنين": 2, "اثنان": 2, "ثنين": 2, "ثلاثه": 3, "ثلاث": 3, "تلاته": 3, "تلات": 3,
	"اربعه": 4, "اربع": 4, "خمسه": 5, "خمس": 5, "سته": 6, "ست": 6, "سبعه": 7, "سبع": 7,
	"ثمانيه": 8, "تمانيه": 8, "ثمان": 8, "تسعه": 9, "تسع": 9, "عشره": 10, "عشر": 10,
	"عشرين": 20, "ثلاثين": 30, "اربعين": 40, "خمسين": 50, "مئه": 100, "ميه": 100, "مائه": 100,
	"بيتين": 2, "ثكنتين": 2,
	"one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9,
	"ten": 10, "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "hundred": 100, "couple": 2,
}

const K_HOUSE := ["بيت", "بيوت", "منزل", "منازل", "مسكن", "مساكن", "house", "home"]
const K_BARR := ["ثكنه", "ثكنات", "ثكنتين", "معسكر", "مركز تدريب", "barrack", "camp"]
const K_UPG := ["طور", "تطوير", "تطور", "ارتقي", "ارتقاء", "رقي", "حسن", "upgrade", "develop", "level up", "improve", "expand"]
const K_FOOD := ["اكل", "طعام", "غذاء", "مؤن", "قمح", "خبز", "food", "bread", "grain", "supplies", "provisions"]
const K_VILL := ["فلاح", "سكان", "ساكن", "مزارع", "عامل", "عمال", "قروي", "شعب", "villager", "peasant", "worker", "citizen", "farmer", "settler", "people"]
const K_SWORD := ["سياف", "سيوف", "سيف", "مقاتل", "جندي", "جنود", "مشاه", "عسكري", "عسكر", "soldier", "swordsm", "sword", "infantry", "footm", "warrior"]
const K_ARCH := ["رام", "رماه", "سهام", "قوس", "archer", "bow"]
const K_CAV := ["فارس", "فرسان", "خيال", "خيل", "حصان", "cavalry", "horse", "knight", "rider"]
const K_ARMY := ["جيش", "الجيش", "army", "troops", "everyone", "all ", "الكل", "الجميع", "كلهم", "كل "]
const V_BUY := ["اشتر", "شري", "شراء", "جيب", "هات", "اجلب", "ابتع", "buy", "purchase", "get", "order", "need", "want"]
const V_TRAIN := ["درب", "تدريب", "جند", "وظف", "استاجر", "اشتر", "جيب", "هات", "جهز", "ضيف", "train", "recruit", "hire", "raise", "get", "buy", "make", "add"]
const V_ADV := ["هاجم", "اهجم", "هجوم", "تقدم", "اتقدم", "اطلع", "اخرج", "زحف", "انطلق", "اقتحم", "اضرب", "اغزو", "attack", "advance", "charge", "march", "go out", "push", "assault", "storm", "invade"]
const V_CHARGE := ["اقتحم", "اندفع", "charge", "storm"]
const V_HOLD := ["ثبت", "اثبت", "قف", "اوقف", "احمي", "احمو", "احرس", "دافع", "ابق", "خليك", "stay", "hold", "stop", "guard", "defend", "protect", "wait", "stand"]
const V_RET := ["انسحب", "تراجع", "ارجع", "عودو", "retreat", "fall back", "pull back", "return", "come back", "go back", "withdraw"]
const V_FOLLOW := ["اتبع", "تعالو", "تعال", "تبعني", "follow", "come with", "come to me"]
const K_WAR_N := ["حرب", "war"]
const V_WAR := ["اعلن", "اعلان", "ابدا", "ابدي", "شن", "declare", "start", "begin", "launch"]
const K_LETTER := ["رساله", "رسايل", "مكتوب", "خطاب", "ورقه", "رسول", "letter", "message", "messenger", "note", "scroll", "للملك", "tell the king", "tell him", "كلم الملك", "tell the other king"]
const LETTER_SAY := ["يقول لهم", "تقول لهم", "قول لهم", "قل لهم", "قولهم", "قلهم", "يقول له", "يقول", "تقول", "قل له", "قول له", "قوله", "قله", "بقوله", "مضمونها", "نصها", "فيها", "saying", "that says", "which says", "says", "tell them that", "tell them", "tell him that", "message:", "letter:", ":"]
const LETTER_TO := ["tell the king that", "tell the king", "tell him", "قل للملك", "قول للملك", "قولو للملك", "كلم الملك", "للملك"]
const LETTER_MARK_OLD := ["يقول له", "يقول", "تقول", "قل له", "قول له", "قوله", "قله", "بقوله", "مضمونها", "نصها", "فيها", "saying", "that says", "which says", "says", "tell him that", "tell the king that", "tell him", "tell the king", "with the message", "message:", "letter:", "للملك", ":"]
const K_GARR := ["حرس", "حاميه", "حمايه", "يحمو", "يحرسو", "تحمي", "تحرس", "garrison", "guards", "guard", "protect", "defend", "حماي", "يدافعو"]
const K_HOME := ["قلعه", "حصن", "بوابه", "مدينه", "castle", "home", "gate", "city", "base"]
const K_Q := ["كم", "كام", "قديش", "شحال", "شكم", "how many", "how much", "status", "report", "اخبار", "وضع", "حاله", "تقرير", "احصائ", "what is", "what's", "do i have", "عندي"]
const K_GOLD := ["ذهب", "فلوس", "مال", "خزينه", "gold", "money", "coins", "treasury"]
const K_SOLD := ["جنود", "جندي", "جيش", "عسكر", "soldiers", "army", "troops"]
const K_MAP := ["خريطه", "map"]
const K_HELP := ["مساعده", "ساعدني", "اوامر", "شو تقدر", "ماذا تستطيع", "help", "commands", "what can you do"]
const K_HI := ["سلام", "مرحبا", "اهلا", "هلا", "صباح", "مساء", "hello", "hey", "greetings", "hi"]
const K_THX := ["شكرا", "يعطيك", "thanks", "thank"]
const K_YES := ["نعم", "ايوه", "اي ", "ايه", "تاكيد", "اكيد", "yes", "yeah", "confirm", "sure", "ok", "okay", "do it"]
const K_NO := ["لا ", "الغي", "الغ", "لاحقا", "no", "cancel", "stop", "never"]
const K_WHERE := ["وين العدو", "اين العدو", "اين الاعداء", "where is the enemy", "where are they", "enemy position", "مكان العدو", "موقع العدو"]
const VERB_STARTS := ["ابن", "بني", "عمر", "طور", "درب", "جيب", "هات", "وظف", "اشتر", "شري", "اعلن", "ارسل", "اكتب", "هاجم", "تقدم", "ثبت", "انسحب", "احمي", "خلي", "ضيف"]


# ---------------------------------------------------------------- text helpers
static func is_arabic(s: String) -> bool:
	for i in s.length():
		var c := s.unicode_at(i)
		if c >= 0x0600 and c <= 0x06FF:
			return true
	return false


# strips diacritics/tatweel, converts Arabic digits (keeps the same length for everything else)
static func clean(s: String) -> String:
	var out := ""
	for i in s.length():
		var c := s.unicode_at(i)
		if (c >= 0x064B and c <= 0x065F) or c == 0x0670 or c == 0x0640:
			continue
		if c >= 0x0660 and c <= 0x0669:
			out += String.chr(48 + c - 0x0660)
		elif c >= 0x06F0 and c <= 0x06F9:
			out += String.chr(48 + c - 0x06F0)
		elif c == 0x066A:
			out += "%"
		else:
			out += String.chr(c)
	return out


# 1:1 normalisation (alef/ya/ta-marbuta variants, lower case)
static func norm(s: String) -> String:
	var out := ""
	for i in s.length():
		var ch := s.substr(i, 1)
		match ch:
			"أ", "إ", "آ", "ٱ":
				out += "ا"
			"ى", "ئ":
				out += "ي"
			"ة":
				out += "ه"
			"ؤ":
				out += "و"
			_:
				out += ch.to_lower()
	return out


static func has(n: String, list: Array) -> bool:
	for k in list:
		if n.contains(k):
			return true
	return false


static func first_num(n: String) -> int:
	# digits first
	var digits := ""
	for i in n.length():
		var ch := n.substr(i, 1)
		if ch >= "0" and ch <= "9":
			digits += ch
		elif digits != "":
			break
	if digits != "":
		return mini(int(digits), 999)
	for tok in n.split(" ", false):
		var t: String = tok
		if AR_NUM.has(t):
			return int(AR_NUM[t])
		if t.begins_with("و") and AR_NUM.has(t.substr(1)):
			return int(AR_NUM[t.substr(1)])
		if t.begins_with("ال") and AR_NUM.has(t.substr(2)):
			return int(AR_NUM[t.substr(2)])
	return 0


static func plural(n: String) -> bool:
	return has(n, ["بيوت", "منازل", "فلاحين", "سكان", "جنود", "رماه", "فرسان", "سيوف", "houses", "villagers", "soldiers", "archers", "knights", "units", "workers", "peasants", "people"])


static func kind_of(n: String) -> String:
	if has(n, K_ARCH):
		return "archer"
	if has(n, K_CAV):
		return "cav"
	if has(n, K_SWORD):
		return "sword"
	return ""


const K_SWORD_ONLY := ["سياف", "سيوف", "سيف", "swordsm", "sword", "infantry", "مشاه", "footm"]


static func group_mask(n: String) -> int:
	var m := 0
	if has(n, K_SWORD_ONLY):
		m |= 1
	if has(n, K_ARCH):
		m |= 2
	if has(n, K_CAV):
		m |= 4
	if m == 0 or has(n, K_ARMY):
		m = 7
	return m


# ---------------------------------------------------------------- splitting
static func split_clauses(text_n: String) -> Array:
	var clauses := []
	var cur := []
	var toks: PackedStringArray = text_n.replace("،", " , ").replace(",", " , ").replace(";", " , ").replace("؛", " , ").replace(".", " , ").replace("+", " , ").split(" ", false)
	for tk in toks:
		var t: String = tk
		var brk := false
		if t in [",", "ثم", "then", "and", "و", "بعدين", "وبعدين", "&", "وبعد"]:
			brk = true
		elif t.begins_with("و") and t.length() > 3:
			var rest := t.substr(1)
			for vs in VERB_STARTS:
				if rest.begins_with(vs):
					brk = true
					cur.append(rest)
					t = ""
					break
			if not brk and has(rest, K_HOUSE + K_BARR + K_VILL + K_SWORD_ONLY + K_ARCH + K_CAV + K_FOOD + K_UPG):
				brk = true
				cur.append(rest)
				t = ""
		if brk:
			if t == "" and not cur.is_empty():
				pass
			if not cur.is_empty() and t != "":
				clauses.append(" ".join(cur))
				cur = []
			elif t == "" and cur.size() > 1:
				# the verb-with-"و" token was appended above; start the clause at it
				var last: String = cur.pop_back()
				clauses.append(" ".join(cur))
				cur = [last]
			continue
		cur.append(t)
	if not cur.is_empty():
		clauses.append(" ".join(cur))
	return clauses


# ---------------------------------------------------------------- main parser
static func parse(text: String) -> Array:
	var raw := clean(text).strip_edges()
	var n := norm(raw)
	var out := []
	if n == "":
		return out
	# yes / no (answers to a question)
	var short := n.length() <= 12
	if short and has(n + " ", K_YES) and not has(n, K_HOUSE + K_FOOD):
		return [{"act": "yes"}]
	if short and (n == "لا" or n.begins_with("لا ") or n == "no" or n.begins_with("cancel") or n.begins_with("الغي")):
		return [{"act": "no"}]
	# letter: whole message
	var is_letter := has(n, K_LETTER) and not has(n, V_ADV + ["war ", "حرب"]) or n.contains("للملك") or n.contains("tell the king")
	if is_letter and (has(n, ["ارسل", "ابعث", "ابعت", "اكتب", "وجه", "send", "write", "tell", "say", "dispatch", "نادي", "ناد", "call", "احضر", "هات", "جيب", "قل", "قول", "كلم"]) or n.contains("رساله") or n.contains("letter")):
		var content := _letter_text(raw, n)
		return [{"act": "letter", "text": content}]
	for cl in split_clauses(n):
		var a := _clause(cl)
		if not a.is_empty():
			out.append(a)
	if out.is_empty():
		out.append({"act": "unknown"})
	return out


static func _letter_text(raw: String, n: String) -> String:
	# quoted text wins
	for q in [["\"", "\""], ["“", "”"], ["«", "»"], ["'", "'"]]:
		var i := raw.find(q[0])
		if i >= 0:
			var j := raw.find(q[1], i + 1)
			if j > i:
				return raw.substr(i + 1, j - i - 1).strip_edges()
	for group in [LETTER_SAY, LETTER_TO]:
		var best := -1
		var best_len := 0
		for m in group:
			var i := n.find(m)
			if i < 0:
				continue
			if best < 0 or i < best or (i == best and m.length() > best_len):
				best = i
				best_len = m.length()
		if best >= 0:
			var content := raw.substr(best + best_len).strip_edges()
			for lead in ["that ", "ان ", "إن ", "أن "]:
				if content.to_lower().begins_with(lead):
					content = content.substr(lead.length()).strip_edges()
			return content.lstrip(":،, ").strip_edges()
	return ""


static func _clause(n: String) -> Dictionary:
	var num := first_num(n)
	var many := plural(n)
	# --- war
	if has(n, K_WAR_N) and (has(n, V_WAR) or n.length() < 14):
		return {"act": "war"}
	# --- where is the enemy
	if has(n, K_WHERE):
		return {"act": "enemy_where"}
	# --- garrison (keep some soldiers to guard the castle)
	if has(n, K_GARR) and has(n, K_HOME) and (num > 0 or has(n, ["ولا واحد", "none", "no one", "nobody", "بدون", "الغي"])):
		var pct := -1
		if n.contains("%") or has(n, ["بالمئه", "في المئه", "بالميه", "في الميه", "percent", "per cent"]):
			pct = clampi(num, 0, 100)
		return {"act": "garrison", "n": num, "pct": pct}
	if has(n, ["no guards", "بدون حرس", "لا حرس", "الغي الحرس", "no garrison"]):
		return {"act": "garrison", "n": 0, "pct": 0}
	# --- map / help / greetings
	if has(n, K_MAP):
		return {"act": "map"}
	if has(n, K_HELP):
		return {"act": "help"}
	# --- status question
	if has(n, K_Q) and not has(n, K_HOUSE + K_BARR + K_UPG + V_ADV + V_HOLD + V_RET):
		var what := "all"
		if has(n, K_GOLD):
			what = "gold"
		elif has(n, K_FOOD):
			what = "food"
		elif has(n, K_SOLD):
			what = "soldiers"
		elif has(n, K_VILL):
			what = "villagers"
		elif has(n, ["قلعه", "castle", "hp", "صحه"]):
			what = "castle"
		return {"act": "status", "what": what}
	# --- army orders
	if has(n, V_RET):
		return {"act": "order", "mode": 4, "mask": group_mask(n), "where": "home"}
	if has(n, V_FOLLOW):
		return {"act": "order", "mode": 0, "mask": group_mask(n), "where": "here"}
	if has(n, V_ADV) and not has(n, K_HOUSE + K_BARR):
		var mode := 3 if has(n, V_CHARGE) else 1
		return {"act": "order", "mode": mode, "mask": group_mask(n), "where": "enemy"}
	if has(n, V_HOLD) and not has(n, K_HOUSE + K_BARR):
		var where := "home"
		if has(n, ["هنا", "عندي", "here", "my position", "me "]):
			where = "here"
		elif has(n, ["بوابه", "gate"]):
			where = "gate"
		return {"act": "order", "mode": 2, "mask": group_mask(n), "where": where}
	# --- economy
	if has(n, K_BARR):
		return {"act": "barracks", "n": maxi(num, 1)}
	if has(n, K_HOUSE):
		return {"act": "house", "n": num if num > 0 else (3 if many else 1)}
	if has(n, K_UPG):
		return {"act": "upgrade"}
	if has(n, K_VILL):
		return {"act": "villager", "n": num if num > 0 else (3 if many else 1)}
	var kd := kind_of(n)
	if kd != "" and (has(n, V_TRAIN) or num > 0 or many or true):
		return {"act": "train", "kind": kd, "n": num if num > 0 else (3 if many else 1)}
	if has(n, K_FOOD):
		return {"act": "buyfood", "n": num if num > 0 else (3 if has(n, ["كثير", "lots", "much", "many"]) else 1)}
	if has(n, K_THX):
		return {"act": "thanks"}
	if has(n, K_HI) and n.length() < 24:
		return {"act": "hi"}
	return {}
