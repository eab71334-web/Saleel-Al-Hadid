extends RefCounted
# Arabic translation of every on-screen text. English strings are the keys.
# Texts with %d / %s are matched as patterns, so formatted messages translate too.

const Loc2S := preload("res://game/loc2.gd")
static var lang := "en"
static var _pat: Array = []
static var _built := false

const AR := {
	# multi-kingdom / map / admin
	"Kingdoms: %d": "المملكات: %d", "AI kingdom": "مملكة الكمبيوتر", "Enemy AI": "عدو الكمبيوتر",
	"GREEN": "الأخضر", "YELLOW": "الأصفر", "PURPLE": "البنفسجي", "ORANGE": "البرتقالي",
	"Blue": "الأزرق", "Red": "الأحمر", "Green": "الأخضر", "Yellow": "الأصفر", "Purple": "البنفسجي", "Orange": "البرتقالي",
	"Blue (you)": "الأزرق (أنت)", "Red (you)": "الأحمر (أنت)", "Green (you)": "الأخضر (أنت)", "Yellow (you)": "الأصفر (أنت)", "Purple (you)": "البنفسجي (أنت)", "Orange (you)": "البرتقالي (أنت)",
	"King of Blue (AI)": "ملك الأزرق (كمبيوتر)", "King of Red (AI)": "ملك الأحمر (كمبيوتر)", "King of Green (AI)": "ملك الأخضر (كمبيوتر)",
	"King of Yellow (AI)": "ملك الأصفر (كمبيوتر)", "King of Purple (AI)": "ملك البنفسجي (كمبيوتر)", "King of Orange (AI)": "ملك البرتقالي (كمبيوتر)",
	"  X": "  سقطت", "  WAR": "  حرب", "  <": "  <",
	"Target: ": "الهدف: ", "(tap to change)": "(اضغط للتغيير)", "(tap to switch)": "(اضغط للتبديل)",
	"ARMY: %d   ENEMY: %d": "الجيش: %d   العدو: %d",
	"AT THE GATE": "عند البوابة", "IN FRONT": "في الأمام", "MIDFIELD": "وسط الميدان", "ON THE WALLS": "على الأسوار",
	"BATTLE MAP": "خريطة المعركة", "Pick groups, then tap the map where they should stand.": "اختر الفرق ثم اضغط على الخريطة وين يقفو.",
	"AT MY WALL": "عند سوري", "REAR GUARD": "الحرس الخلفي", "FRONT LINE": "خط المواجهة", "RETREAT to my wall": "انسحاب للسور",
	"Orders given: fall back.": "تم الأمر: انسحاب.",
	"ADMIN": "المشرف", "ADMIN MODE": "وضع المشرف", "View: ": "المشاهدة: ", "Control this kingdom: ": "التحكم في هذه المملكة: ",
	"See everything: ": "كشف الخريطة: ", "Game speed: x%d": "سرعة اللعبة: x%d", "+500 gold, +300 food": "+500 ذهب، +300 أكل",
	"Your kingdom has fallen. You are now watching.": "سقطت مملكتك. أنت الحين تشاهد.",
	# menu
	"SALEEL AL HADID": "سليل الحديد",
	"Swords  -  Bows  -  Kingdoms": "سيوف - أقواس - ممالك",
	"Solo Battle (vs AI)": "معركة فردية (ضد الكمبيوتر)",
	"Solo Kingdom (vs AI king)": "مملكة فردية (ضد ملك الكمبيوتر)",
	"Host LAN Game": "استضافة لعبة على الشبكة",
	"Join LAN Game": "الانضمام للعبة على الشبكة",
	"Settings": "الإعدادات",
	"Download update": "تحميل التحديث",
	"build %d": "إصدار %d",
	"Could not host (port busy?)": "تعذر الاستضافة (المنفذ مشغول؟)",
	"Games found on your Wi-Fi:": "الألعاب الموجودة على شبكتك:",
	"...or type the host IP:": "...أو اكتب عنوان IP الخاص بالمضيف:",
	"(searching...)": "(جاري البحث...)",
	"Connect": "اتصال",
	"Back": "رجوع",
	"Connecting...": "جاري الاتصال...",
	"Invalid address": "عنوان غير صالح",
	"Could not connect.": "تعذر الاتصال.",
	"Could not connect. Check: same Wi-Fi, host already started, and allow Local Network for this app (iPhone Settings > this app).": "تعذر الاتصال. تأكد: نفس الواي فاي، المضيف بدأ اللعبة، وسماح الشبكة المحلية للتطبيق (إعدادات الآيفون > التطبيق).",
	"Your IP: %s": "عنوانك: %s",
	"Your IP: %s  (the host must be on the same Wi-Fi)": "عنوانك: %s  (لازم المضيف يكون على نفس الواي فاي)",
	"Kingdom": "المملكة",
	"Army Setup": "إعداد الجيش",
	"LAN Lobby": "غرفة الشبكة",
	"Mode: KINGDOM (tap to change)": "النمط: مملكة (اضغط للتغيير)",
	"Mode: BATTLE (tap to change)": "النمط: معركة (اضغط للتغيير)",
	"Build a city, hire villagers and soldiers,\nsend letters, declare war, duel the king.": "ابنِ مدينتك ووظّف فلاحين وجنود،\nأرسل رسائل، أعلن الحرب، وبارز الملك.",
	"START KINGDOM": "ابدأ المملكة",
	"START BATTLE": "ابدأ المعركة",
	"Waiting for the host to start...": "بانتظار المضيف ليبدأ اللعبة...",
	"Swordsmen": "سيافة", "Archers": "رماة", "Cavalry": "فرسان",
	"Swordsman": "سياف", "Archer": "رامي",
	"BLUE": "أزرق", "RED": "أحمر",
	"Enemy AI   [RED]": "العدو (كمبيوتر)   [أحمر]",
	# settings
	"Language": "اللغة",
	"Graphics quality": "جودة الرسوم",
	"Frame rate limit": "حد الإطارات",
	"Low": "منخفضة", "Medium": "متوسطة", "High": "عالية",
	"Show FPS counter": "إظهار عداد الإطارات",
	"ON": "تشغيل", "OFF": "إيقاف",
	"Quality: %s": "الجودة: %s",
	"Frame rate: %d": "الإطارات: %d",
	"FPS counter: %s": "عداد الإطارات: %s",
	"Language: English": "اللغة: English",
	"Language: Arabic": "اللغة: العربية",
	"Low = fastest. Use it if the game is slow or the phone gets hot.": "منخفضة = الأسرع. استخدمها إذا اللعبة بطيئة أو الجوال يسخن.",
	"FPS %d": "إطار %d",
	# updater
	"Light updates off: set your GitHub name in game/config.gd": "التحديث الخفيف متوقف: ضع اسم حسابك في game/config.gd",
	"Checking for updates...": "جاري البحث عن تحديثات...",
	"Update check failed": "فشل البحث عن تحديث",
	"No update info (offline?)": "لا توجد معلومات تحديث (لا يوجد إنترنت؟)",
	"Bad update info": "معلومات التحديث تالفة",
	"Update available: build %d (%d KB)": "تحديث متوفر: إصدار %d (%d كيلوبايت)",
	"Game is up to date (build %d)": "اللعبة محدّثة (إصدار %d)",
	"Downloading update...": "جاري تحميل التحديث...",
	"Download failed": "فشل التحميل",
	"Download failed (code %d)": "فشل التحميل (رمز %d)",
	"Update downloaded! Close the game and open it again.": "تم تحميل التحديث! أغلق اللعبة وافتحها من جديد.",
	"Updates removed. Restart the game to use the built-in version.": "تم حذف التحديثات. أعد تشغيل اللعبة.",
	# hud
	"Follow me": "تبعوني", "Advance": "تقدّموا", "Hold here": "اثبتوا هنا", "Charge!": "هجوم!", "Retreat": "انسحبوا",
	"STRIKE": "اضرب", "RALLY": "تجمّع", "HORSE\nSOON": "الحصان\nقريباً", "SOON": "قريباً", "MOUNT": "اركب", "SWD": "سيف", "ARC": "رماة", "CAV": "فرسان",
	"%ds": "%d ث",
	"YOUR SOLDIERS: %d     ENEMY: %d": "جنودك: %d     العدو: %d",
	"YOUR ARMY: %d     ENEMY: %d": "جيشك: %d     العدو: %d",
	"KINGDOM": "المملكة", "VICTORY!": "النصر!", "DEFEAT": "الهزيمة", "Main Menu": "القائمة الرئيسية",
	"Horse riding - coming soon!": "ركوب الخيل - قريباً!",
	"Build your city: open CITY. Hire villagers, build houses, train soldiers.": "ابنِ مدينتك: افتح زر المدينة، وظّف فلاحين، ابنِ بيوت، ودرّب جنود.",
	"Pick a group, then an order. Advance to attack!": "اختر مجموعة ثم أمراً. تقدّم للهجوم!",
	# kingdom ui
	"YOUR CASTLE": "قلعتك", "ENEMY CASTLE": "قلعة العدو", "PEACE": "سلام", "WAR": "حرب",
	"CITY": "المدينة", "MAP": "الخريطة", "ADVISOR": "المستشار", "MESSENGER": "الرسول", "STEWARD": "المشرف", "TRAINING YARD": "ساحة التدريب", "FORGE": "الحدادة", "STABLES": "الإسطبلات", "TALK": "تكلّم",
	"TALK: MESSENGER": "كلّم الرسول", "TALK: ADVISOR": "كلّم المستشار",
	"YOUR KINGDOM": "مملكتك", "TRAIN SOLDIERS": "تدريب الجنود", "DUEL OF KINGS": "مبارزة الملوك",
	"GOLD %d    FOOD %d    POP %d/%d    VILLAGERS %d    LV %d": "ذهب %d    أكل %d    سكان %d/%d    فلاحين %d    مستوى %d",
	"Hire Villager\n%d food": "وظّف فلاح\n%d أكل",
	"Buy Food\n%d gold -> %d food": "اشترِ أكل\n%d ذهب ← %d أكل",
	"Build House (%d/%d)\n%d gold": "ابنِ بيت (%d/%d)\n%d ذهب",
	"Barracks (%d/%d)\n%d gold": "ثكنة (%d/%d)\n%d ذهب",
	"Develop Castle -> Lv%d\n%d gold, %d food": "طوّر القلعة ← مستوى %d\n%d ذهب، %d أكل",
	"Castle at max level": "القلعة في أعلى مستوى",
	"%s\n%dg %df": "%s\n%d ذ %d أ",
	"%s\nCastle Lv%d": "%s\nقلعة مستوى %d",
	"Write Letter\nsend a messenger": "اكتب رسالة\nأرسل رسولاً",
	"WAR IS ON": "الحرب قائمة", "TAP AGAIN TO CONFIRM": "اضغط مرة أخرى للتأكيد",
	"Declare War\nattack the other king": "أعلن الحرب\nهاجم الملك الآخر",
	"Not enough food!": "الأكل غير كافٍ!", "Build more houses first!": "ابنِ بيوتاً أكثر أولاً!",
	"Not enough gold!": "الذهب غير كافٍ!", "No free land - upgrade your castle!": "لا توجد أرض فارغة - طوّر القلعة!",
	"Barracks limit reached": "وصلت للحد الأقصى من الثكنات",
	"Barracks limit reached (upgrade castle for another)": "وصلت للحد الأقصى من الثكنات (طوّر القلعة لثكنة أخرى)",
	"Need %d gold and %d food": "تحتاج %d ذهب و %d أكل",
	"Castle level %d needed": "مطلوب مستوى القلعة %d",
	"Build a barracks first!": "ابنِ ثكنة أولاً!",
	"Your messenger is still preparing (%ds)": "الرسول لسا يتجهز (%d ث)",
	"Messenger sent!": "انطلق الرسول!", "Your letter was delivered.": "وصلت رسالتك.",
	"A messenger was cut down on the road!": "تم قتل رسول في الطريق!",
	"CASTLE LEVEL %d": "مستوى القلعة %d", "WAR!": "حرب!", "%s DECLARES WAR!": "%s يعلن الحرب!",
	"THE ARMY MARCHES!": "الجيش يزحف!", "THE CASTLE FALLS!": "القلعة تسقط!",
	"Your king has fallen! He will return soon...": "سقط ملكك! سيعود قريباً...",
	"The enemy king has fallen!": "سقط ملك العدو!",
	"WRITE A LETTER TO THE OTHER KING": "اكتب رسالة للملك الآخر",
	"Write your message here...": "اكتب رسالتك هنا...",
	"SEND MESSENGER": "أرسل الرسول", "Cancel": "إلغاء", "Close": "إغلاق",
	"The paper is empty!": "الورقة فاضية!",
	"A messenger has arrived - read the letter when you finish.": "وصل رسول - اقرأ الرسالة لما تخلص.",
	"A MESSENGER HAS ARRIVED": "وصل رسول", "Letter from %s:": "رسالة من %s:", "Write Reply": "اكتب رداً",
	# map
	"WAR MAP": "خريطة الحرب",
	"Fog hides the enemy until your men or towers get close.": "الضباب يخفي العدو حتى يقرب منه جنودك أو أبراجك.",
	"SWORDS": "السيافة", "ARCHERS": "الرماة", "CAVALRY": "الفرسان",
	"STATION: tap the map": "تمركز: اضغط على الخريطة",
	"ATTACK the enemy!": "هاجم العدو!", "RETURN to the castle": "ارجعوا للقلعة",
	"Garrison (stay to guard the castle):": "الحامية (يبقون لحراسة القلعة):",
	"CLOSE MAP": "إغلاق الخريطة",
	"Orders given: attack.": "تم إعطاء الأمر: هجوم.", "Orders given: return home.": "تم إعطاء الأمر: العودة للقلعة.",
	"%d%% of your soldiers will stay and guard the castle.": "%d%% من جنودك يبقون لحراسة القلعة.",
	"Enemy soldiers in sight: %d": "جنود العدو المرئيون: %d", "No enemy in sight.": "لا يوجد عدو في الأفق.",
	"Tip: press STATION first, then tap where your groups should stand.": "نصيحة: اضغط تمركز أولاً ثم المكان الذي تريد أن تقف فيه المجموعات.",
	"Groups are moving to that spot and will hold it.": "المجموعات تتحرك لذلك المكان وتثبت فيه.",
	# court
	"ROYAL ADVISOR": "المستشار الملكي",
	"Type, or tap the microphone on your keyboard to speak. Arabic or English.": "اكتب، أو اضغط زر الميكروفون في الكيبورد وتكلّم. عربي أو إنجليزي.",
	"SEND": "إرسال", "SHOW MAP": "اعرض الخريطة", "Understood": "فهمت", "A SCOUT HAS ARRIVED": "وصل الكشّاف",
	# throne hall / royal
	"THRONE": "العرش", "SIT": "اجلس", "ROYAL": "الملكية",
	"SIT ON THRONE": "اجلس على العرش", "STAND UP": "انهض",
	"THE ROYAL COURT": "البلاط الملكي",
	"Rank": "اللقب", "Gold": "الذهب", "Food": "الأكل", "Villagers": "الفلاحين", "Soldiers": "الجنود", "Castle": "القلعة",
	"Rank: %s": "اللقب: %s", "Treasury: %d gold": "الخزينة: %d ذهب",
	"Villagers: %d   Soldiers: %d": "الفلاحين: %d   الجنود: %d",
	"Castle: level %d  (%d / %d)": "القلعة: مستوى %d  (%d / %d)",
	"Food: %d": "الأكل: %d",
	"Lord": "لورد", "Baron": "بارون", "Count": "كونت", "Duke": "دوق", "King": "ملك", "Emperor": "إمبراطور",
	"ROYAL DECREES": "المراسيم الملكية",
	"Collect Taxes\n+gold (once a minute)": "اجمع الضرائب\n+ذهب (مرة بالدقيقة)",
	"Royal Feast\n%d food - heal army": "وليمة ملكية\n%d أكل - علاج الجيش",
	"Wait %ds": "انتظر %d ث",
	"The people paid %d gold in taxes.": "دفع الشعب %d ذهب ضرائب.",
	"The royal feast heals your army!": "الوليمة الملكية تشفي جيشك!",
	"THRONE ROOM": "قاعة العرش",
	"KING %s": "الملك %s",
	"%s  -  %s": "%s  -  %s",
	"Treasury": "الخزينة",
	"Throne: press SIT to see your kingdom.": "العرش: اضغط اجلس لتشوف مملكتك.",
	"%s: %d": "%s: %d",
	"%s   [%s]": "%s   [%s]",
	"Declare war first!": "أعلن الحرب أولاً!",
	"THE KINGS ARE SUMMONED TO THE FIELD OF HONOR!": "الملكان يُستدعيان إلى ساحة الشرف!",
	"Room is full.": "الغرفة ممتلئة.",
	"The game already started.": "اللعبة بدأت بالفعل.",
	"Room size: %d players": "حجم الغرفة: %d لاعبين",
	"Players in room: %d/%d": "اللاعبون في الغرفة: %d/%d",
	"Room is full - nobody else can join.": "الغرفة ممتلئة - ما أحد يقدر ينضم.",
	"%s   %d/%d": "%s   %d/%d",
	"%s   %d/%d   (started)": "%s   %d/%d   (بدأت)",
	"%s   %d/%d   (full)": "%s   %d/%d   (ممتلئة)",
	"PLAY": "ابدأ اللعب", "LOCAL (Wi-Fi)": "محلي (واي فاي)", "Choose your game": "اختر لعبتك",
	"Solo Battle": "معركة فردية", "Solo Kingdom": "مملكة فردية",
	"Command your army against the enemy": "قُد جيشك ضد العدو",
	"Build a castle city, then rule or conquer": "ابنِ مدينة قلعتك ثم احكم أو افتح",
	"tap to play": "اضغط للعب",
	"Play with friends on the same Wi-Fi": "العب مع أصدقائك على نفس الواي فاي",
	"Create Room": "إنشاء غرفة", "Join Room": "الانضمام لغرفة",
	"VS": "ضد",
	"%s  VS  %s": "%s  ضد  %s",
	"THE KINGS FACE EACH OTHER!": "الملكان وجهاً لوجه!",
	"Your king": "ملكك", "Enemy king": "ملك العدو",
	"KING HP": "صحة الملك",
	"Summon the enemy king to a duel": "تحدَّ الملك لمبارزة",
	"The enemy king has been challenged!": "تم تحدي ملك العدو!",
	"Challenge to Duel\nface the other king": "تحدَّ لمبارزة\nواجه الملك الآخر",
}


static func is_ar() -> bool:
	return lang == "ar"


static func _esc(s: String) -> String:
	var out := ""
	for i in s.length():
		var c := s[i]
		if c in ["\\", ".", "+", "*", "?", "(", ")", "[", "]", "{", "}", "|", "^", "$", "-", "/"]:
			out += "\\" + c
		else:
			out += c
	return out


static func _build() -> void:
	_built = true
	_pat.clear()
	var allk := AR.duplicate()
	allk.merge(Loc2S.AR2)
	for k in allk.keys():
		var key: String = k
		if not (key.contains("%d") or key.contains("%s")):
			continue
		var rx := ""
		var types: Array = []
		var i := 0
		var seg := ""
		while i < key.length():
			if key[i] == "%" and i + 1 < key.length():
				var n := key[i + 1]
				if n == "d" or n == "s":
					rx += _esc(seg) + ("(-?\\d+)" if n == "d" else "(.+?)")
					types.append(n)
					seg = ""
					i += 2
					continue
				if n == "%":
					seg += "%"
					i += 2
					continue
			seg += key[i]
			i += 1
		rx += _esc(seg)
		var re := RegEx.new()
		if re.compile("^" + rx + "$") == OK:
			_pat.append({"re": re, "types": types, "ar": allk[k]})


static func t(s: String) -> String:
	if lang != "ar" or s == "":
		return s
	if AR.has(s):
		return AR[s]
	if Loc2S.AR2.has(s):
		return Loc2S.AR2[s]
	if not _built:
		_build()
	for p in _pat:
		var m: RegExMatch = p.re.search(s)
		if m == null:
			continue
		var args := []
		for i in p.types.size():
			var g := m.get_string(i + 1)
			args.append(int(g) if p.types[i] == "d" else t(g))
		return String(p.ar) % args
	if s.contains("\n"):
		var out := []
		var changed := false
		for part in s.split("\n"):
			var tp := t(part)
			if tp != part:
				changed = true
			out.append(tp)
		if changed:
			return "\n".join(out)
	return s


# Translate every Label / Button / LineEdit below `n` (remembers what it already translated).
static var _hooked := false


# Translate every label/button the moment it is created or its text changes (no English flash).
static func install(tree: SceneTree) -> void:
	if _hooked:
		return
	_hooked = true
	tree.node_added.connect(_on_added)


static func _on_added(n: Node) -> void:
	if n is Label or n is Button or n is LineEdit or n is Label3D:
		apply_one(n)
		if n is Control and not n.minimum_size_changed.is_connected(apply_one.bind(n)):
			n.minimum_size_changed.connect(apply_one.bind(n))


static func apply_one(n: Node) -> void:
	if lang != "ar" or not is_instance_valid(n):
		return
	if n is Label or n is Button or n is Label3D:
		var cur: String = n.text
		if cur != "" and not (n.has_meta("ar_out") and n.get_meta("ar_out") == cur):
			var tr_: String = t(cur)
			if tr_ != cur:
				n.text = tr_
				n.set_meta("ar_out", tr_)
	elif n is LineEdit:
		var ph: String = n.placeholder_text
		if ph != "" and not (n.has_meta("ar_out") and n.get_meta("ar_out") == ph):
			var tp: String = t(ph)
			if tp != ph:
				n.placeholder_text = tp
				n.set_meta("ar_out", tp)


static func apply_tree(n: Node) -> void:
	if lang != "ar":
		return
	if n is Label or n is Button or n is Label3D:
		var cur: String = n.text
		if cur != "" and not (n.has_meta("ar_out") and n.get_meta("ar_out") == cur):
			var tr_: String = t(cur)
			if tr_ != cur:
				n.text = tr_
				n.set_meta("ar_out", tr_)
	elif n is LineEdit:
		var ph: String = n.placeholder_text
		if ph != "" and not (n.has_meta("ar_out") and n.get_meta("ar_out") == ph):
			var tp: String = t(ph)
			if tp != ph:
				n.placeholder_text = tp
				n.set_meta("ar_out", tp)
	for c in n.get_children():
		apply_tree(c)
