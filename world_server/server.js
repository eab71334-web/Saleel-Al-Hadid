// Saleel Al Hadid - Open World presence server (zero dependencies, Node 18+).
// Players POST their castle; everybody GETs the list and sees the other players' castles in the world.
//   GET  /api/world/castles?game=saleelalhadid   -> { "castles": [ {player_id,name,x,z,level,banner,emblem,px,pz,updated} ] }
//   POST /api/world/castle  {player_id,name,x,z,level,banner,emblem,px,pz}  -> { "ok": true }   (px,pz = where the king is now)
//   (castle POST also takes pvp: 0/1 - players with pvp on can fight each other; hits travel through /send as type "hit")
//   POST /api/world/send    {from,to,type,data}   -> { "ok": true }   mailbox: tax offers, alliance proposals, replies, muster calls
//   POST /api/world/chat    {player_id,code,x,z}   public quick-chat (phrase codes only)
//   GET  /api/world/chat?after=ID   -> { chat:[{id,from,name,code,x,z,ts}], last }
//   GET  /api/world/inbox?player_id=ID            -> { "msgs": [ {id,from,from_name,type,data,ts} ] }   (messages are removed once read)
//   GET  /health
// Deploy on Render as a new Web Service (build: none, start: node server.js) and put its URL in the game
// (game/backend.gd DEFAULT_URL), or copy the two handlers into your existing sabak-backend.
const http = require("http");
const fs = require("fs");
const PORT = process.env.PORT || 8080;
const FILE = process.env.WORLD_FILE || "./world.json";
const MAX_AGE = 30 * 24 * 3600 * 1000;
let castles = {};
try { castles = JSON.parse(fs.readFileSync(FILE, "utf8")); } catch (e) { castles = {}; }
let dirty = false;
const inbox = {};
const chatlog = [];
let chatId = 0;
let msgId = 0;
setInterval(() => { if (dirty) { try { fs.writeFileSync(FILE, JSON.stringify(castles)); dirty = false; } catch (e) {} } }, 15000);

const hits = {};
function limited(ip) {
  const now = Date.now();
  const h = (hits[ip] = (hits[ip] || []).filter(t => now - t < 60000));
  h.push(now);
  return h.length > 200;
}
function send(res, code, obj) {
  res.writeHead(code, { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "Content-Type", "Access-Control-Allow-Methods": "GET,POST,OPTIONS" });
  res.end(JSON.stringify(obj));
}
function num(v, lo, hi, d) { v = Number(v); return Number.isFinite(v) ? Math.min(hi, Math.max(lo, v)) : d; }

http.createServer((req, res) => {
  if (req.method === "OPTIONS") return send(res, 204, {});
  const ip = req.socket.remoteAddress || "?";
  if (limited(ip)) return send(res, 429, { error: "slow down" });
  const url = new URL(req.url, "http://x");
  if (url.pathname === "/health") return send(res, 200, { ok: true, castles: Object.keys(castles).length });
  if (req.method === "GET" && url.pathname === "/api/world/castles") {
    const now = Date.now();
    const list = Object.values(castles).filter(c => now - c.updated < MAX_AGE);
    return send(res, 200, { castles: list });
  }
  if (req.method === "POST" && url.pathname === "/api/world/castle") {
    let body = "";
    req.on("data", d => { body += d; if (body.length > 4096) req.destroy(); });
    req.on("end", () => {
      let j;
      try { j = JSON.parse(body); } catch (e) { return send(res, 400, { error: "bad json" }); }
      const id = String(j.player_id || "").slice(0, 40);
      if (!id) return send(res, 400, { error: "player_id" });
      const old = castles[id];
      const level = Math.round(num(j.level, 1, 50, 1));
      if (old && level > old.level + 3) return send(res, 400, { error: "level jump" });
      castles[id] = {
        player_id: id,
        name: String(j.name || "Player").replace(/[<>]/g, "").slice(0, 24),
        x: num(j.x, -4000, 4000, 0), z: num(j.z, -4000, 4000, 0),
        level, banner: Math.round(num(j.banner, 0, 6, 0)), emblem: Math.round(num(j.emblem, 0, 4, 0)),
        pvp: j.pvp ? 1 : 0, kills: Math.round(num(j.kills, 0, 1e6, 0)), gold: Math.round(num(j.gold, 0, 1e9, 0)),
        px: num(j.px, -4000, 4000, num(j.x, -4000, 4000, 0)), pz: num(j.pz, -4000, 4000, num(j.z, -4000, 4000, 0)),
        updated: Date.now(),
      };
      dirty = true;
      send(res, 200, { ok: true });
    });
    return;
  }
  if (req.method === "GET" && url.pathname === "/api/world/chat") {
    const after = Number(url.searchParams.get("after") || 0);
    return send(res, 200, { chat: chatlog.filter(m => m.id > after), last: chatId });
  }
  if (req.method === "POST" && url.pathname === "/api/world/chat") {
    let body = "";
    req.on("data", d => { body += d; if (body.length > 1024) req.destroy(); });
    req.on("end", () => {
      let j;
      try { j = JSON.parse(body); } catch (e) { return send(res, 400, { error: "bad json" }); }
      const id = String(j.player_id || "").slice(0, 40);
      if (!id || !castles[id]) return send(res, 400, { error: "unknown player" });
      // only ready-made phrase codes are accepted (no free text)
      const code = String(j.code || "").replace(/[^a-z0-9_]/g, "").slice(0, 16);
      if (!code) return send(res, 400, { error: "code" });
      chatlog.push({ id: ++chatId, from: id, name: castles[id].name, code, x: num(j.x, -4000, 4000, 0), z: num(j.z, -4000, 4000, 0), ts: Date.now() });
      while (chatlog.length > 60) chatlog.shift();
      send(res, 200, { ok: true });
    });
    return;
  }
  if (req.method === "GET" && url.pathname === "/api/world/inbox") {
    const id = String(url.searchParams.get("player_id") || "").slice(0, 40);
    const msgs = inbox[id] || [];
    inbox[id] = [];
    return send(res, 200, { msgs });
  }
  if (req.method === "POST" && url.pathname === "/api/world/send") {
    let body = "";
    req.on("data", d => { body += d; if (body.length > 2048) req.destroy(); });
    req.on("end", () => {
      let j;
      try { j = JSON.parse(body); } catch (e) { return send(res, 400, { error: "bad json" }); }
      const from = String(j.from || "").slice(0, 40), to = String(j.to || "").slice(0, 40);
      const type = String(j.type || "").slice(0, 20);
      if (!from || !to || !type || !castles[to]) return send(res, 400, { error: "bad target" });
      const q = (inbox[to] = inbox[to] || []);
      if (q.length > 40) q.shift();
      q.push({ id: ++msgId, from, from_name: castles[from] ? castles[from].name : "Player", type, data: j.data && typeof j.data === "object" ? j.data : {}, ts: Date.now() });
      send(res, 200, { ok: true });
    });
    return;
  }
  send(res, 404, { error: "not found" });
}).listen(PORT, () => console.log("world server on " + PORT));
