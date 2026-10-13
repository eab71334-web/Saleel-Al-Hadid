# Medieval Wars v3 — Kingdom mode + light updates

## What is new
- **Kingdom mode** (Solo Kingdom, or Host LAN -> "Mode: KINGDOM"): start with a castle and 2 houses.
  Hire villagers (they bring fruit from the trees = food), buy food with gold, build houses (gold + more people),
  build a barracks, upgrade the castle (Lv2 archers, Lv3 cavalry), train soldiers.
  Open **CITY** (top-left) to do all of this.
- **Letters**: CITY -> Write Letter. Type anything (Arabic works too), a messenger rides to the other king.
  In war a messenger can be killed on the road.
- **War**: CITY -> Declare War (tap twice). Walls can be broken by soldiers (Advance order) — slowly, towers shoot back.
  Destroy the enemy castle to win. When the two kings get close a **Duel of Kings** starts inside a shrinking ring.
- **Horse riding**: coming soon (button is greyed). Switch on later with `HORSE_RIDING := true` in `game/battle.gd`.

## Files to upload (keep folder names)
```
project.godot
game/*            (everything: boot.gd, boot.tscn, kingdom.gd, updater.gd, config.gd, build.gd, ...)
tools/*
.github/workflows/android.yml
.github/workflows/light-update.yml
```

## Light download (about 140 KB instead of 72 MB)
The engine itself is 25–70 MB and cannot shrink, so you install the big app ONCE.
After that, every change to the game is a tiny update:

1. Edit `game/config.gd` once: replace `YOURNAME` with your GitHub user name (and the repo name if it is not TowerWars).
2. Make sure the repo is public, or the in-game download will not work (private repos need a login).
3. Every time you commit changes in `game/`, the workflow **Light update (tiny download)** runs (~1 minute).
   It makes a Release called `light-update` and an artifact `MedievalWars-light-update` (a ~140 KB zip).
4. On the phone: open the game -> main menu shows "Update available" -> tap **Download update** -> close the game fully and open it again.

Safety: if an update breaks the game before the menu appears, the next launch deletes the update automatically.
Use the same Godot version as the full app (`GODOT_VERSION` in both workflows, 4.4.1 now).
After you install a NEW full build, the menu will re-check and replace older updates by itself.

## Playing
- Left side: joystick. Drag the right side: camera.
- SWD / ARC / CAV = choose groups, then Follow / Advance / Hold / Charge / Retreat.
- STRIKE = power attack, RALLY = buff + heal nearby troops.
- PC keys: WASD move, Space strike, Q rally, 1-5 orders, right-mouse drag camera.

---
# v4 - القلعة المسوّرة (Walled Castle)
المشروع تغيّر (ملفات جديدة: fortress.gd, mapview.gd, court.gd, advisor.gd) فلازم تحدّث الريبو كاملاً مرة وحدة (مش التحديث الخفيف).
- كل شي صار داخل قلعة بأسوار وبوابة؛ البوابة تفتح لما الجيش يطلع (مشهد سينمائي).
- زر MAP: خريطة الحرب، تحدد وين يوقفو المجموعات، ونسبة الحرس (0/25/50/75%).
- ضباب الحرب: ما تشوف العدو الا قريب من جنودك او أبراجك؛ ويجيك كشّاف يقولك اسم القلعة ومكانهم.
- زر ADVISOR: اكتب (او اضغط ميكروفون الكيبورد) بالعربي او الإنجليزي: "ابني بيتين وثكنه", "درب 5 رماة", "خلي 30% يحرسو القلعة", "ارسل رسالة تقول نبي السلام", "هاجم".
- الرسول: قرّب منه واضغط TALK لكتابة الرسالة، او قل للمستشار يرسلها.
- المستشار برنامج قواعد يشتغل بدون انترنت (مش ذكاء اصطناعي سحابي).
- بعد ما ترفع الملفات: عدّل YOURNAME في game/config.gd، وخلي الريبو public.

---
# v5 - إصلاح LAN + الإعدادات + قاعة العرش
**مهم - LAN على الآيفون:** iOS يمنع الاتصال المحلي إلا إذا التطبيق يعلن إذن "الشبكة المحلية". أضف خطوة في workflow الـ iOS قبل التصدير:
```
- name: iOS local network permission
  run: bash tools/add_ios_privacy.sh export_presets.cfg
```
(ملف tools/add_ios_privacy.sh مرفق). بعدها أول مرة تفتح اللعبة يطلع سؤال "Local Network" - اضغط Allow. ولو رفضت: إعدادات الآيفون > التطبيق > Local Network.
وتأكد: الجهازين على نفس الواي فاي، والمضيف ضغط Host قبل ما تنضم.

- الإعدادات (زر Settings في القائمة وفي اللعبة): اللغة (عربي/English)، الجودة (منخفضة/متوسطة/عالية)، الإطارات (30/60/120)، عداد FPS.
- قاعة العرش: ادخل من باب القصر داخل القلعة. سقف، عرش، خزنة ذهب تتملى كل ما زاد ذهبك، ولوحة فيها اسمك ولقبك.
- زر ROYAL: لقبك وثروتك + مراسيم: جمع الضرائب (كل دقيقة)، وليمة ملكية (تعالج الجيش)، وتحدي الملك لمبارزة (وقت الحرب).
- قريب من العرش يظهر زر "SIT ON THRONE".
- مواجهة الملكين: مشهد سينمائي فيه اسم الملكين قبل المبارزة.

## v6 — up to 6 kingdoms, battle map, admin code, new look
- Lobby (Kingdom mode): "Kingdoms: N" slider, 2 to 6. Kingdoms without a human are run by AI kings. N = 2 plays like before.
- Kingdoms sit on a ring. War is declared against ONE kingdom at a time (CITY panel > Target button, or tell the advisor "war on green"). Last kingdom standing wins; if your castle falls you keep watching.
- War map: quick STATION presets (gate / in front / midfield / walls) plus tap-to-station. Battle mode now has a MAP button too.
- Secret admin code: type the word in game/admin.gd (default: سوسوس or sososo) to the ADVISOR. An ADMIN button appears: switch viewpoint to any kingdom, take control of it (solo/vs AI only), see the whole map, game speed, +gold. Change the words in game/admin.gd.
- New files: game/battlemap.gd, game/admin.gd. Changed: battle, kingdom, unit, fortress, mapview, court, advisor, main, loc.
