# Saleel Al Hadid - Open World server

Tiny presence server so players see each other's castles in the Open World.

1. Push this folder to a new GitHub repo (or a sub-folder of sabak-backend).
2. Render -> New -> Web Service -> pick the repo, Build Command: (empty), Start Command: `node server.js`.
3. Copy the service URL. In the game, set `DEFAULT_URL` in `game/backend.gd` to it
   (or add the two handlers from server.js to the existing sabak-backend routes - same paths).
4. Test: open `<url>/health` in a browser -> {"ok":true}.

Render free plans sleep after inactivity and the JSON file resets on redeploy; for permanent storage use a Render disk or a database.
Until the server exists the game simply shows "Offline world - lords only".
