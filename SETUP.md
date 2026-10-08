# Medieval Wars — Setup (Godot 4)

1. Upload the whole `game/` folder to the root of your repo (next to `project.godot`).
2. Open `project.godot` on GitHub and make these small edits:

```
[application]
run/main_scene="res://game/main.tscn"

[display]
window/handheld/orientation=0
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[rendering]
renderer/rendering_method="mobile"
```
(0 = landscape. If a section already exists, just add the lines inside it.)

3. Commit → the "Export and Build iOS App" workflow runs.

## Playing
- Solo: Solo Battle → set army sizes → START.
- LAN: one phone taps Host LAN Game, the others tap Join LAN Game (same Wi-Fi). Host sets the army and presses START.
  If the host does not appear in the list, type the IP shown on the host screen.
- Left side: joystick. Drag the right side: camera. 
- SWD / ARC / CAV = choose which groups get the order, then Follow / Advance / Hold / Charge / Retreat.
- STRIKE = power attack, MOUNT = get on/off horse, RALLY = buff + heal nearby troops.
- PC keys: WASD move, Space strike, E mount, Q rally, 1-5 orders, right-mouse drag camera.
