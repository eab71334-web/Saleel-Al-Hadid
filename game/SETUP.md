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
