#!/usr/bin/env node
// Turtle launcher update server. Zero dependencies, Node 18+.
//
// Serves:
//   GET /manifest.json   list of client files (path, size, sha256) + realmlist/news
//   GET /files/<path>    the files themselves (supports Range for resumed downloads)
//   GET /status          whether realmd and mangosd accept connections
//
// Everything placed in $DATA_DIR/client/ is mirrored into the player's client
// folder at the same relative path (e.g. client/Data/patch-Z.mpq). The folder is
// rescanned on every manifest request, so dropping in a new patch is enough;
// hashes are cached by size+mtime so big files are only hashed once.
'use strict';

const http = require('http');
const fs = require('fs');
const fsp = fs.promises;
const path = require('path');
const crypto = require('crypto');
const net = require('net');

const PORT = Number(process.env.PORT || 8090);
const DATA_DIR = path.resolve(process.env.DATA_DIR || path.join(__dirname, 'launcher-data'));
const CLIENT_DIR = path.join(DATA_DIR, 'client');
const CONFIG_FILE = path.join(DATA_DIR, 'launcher.json');
const REALMD = { host: process.env.REALMD_HOST || '127.0.0.1', port: Number(process.env.REALMD_PORT || 3724) };
const WORLD = { host: process.env.WORLD_HOST || '127.0.0.1', port: Number(process.env.WORLD_PORT || 8085) };

const hashCache = new Map(); // abs path -> { size, mtimeMs, sha256 }

function log(...args) {
  console.log(new Date().toISOString(), ...args);
}

async function sha256File(file) {
  const hash = crypto.createHash('sha256');
  for await (const chunk of fs.createReadStream(file, { highWaterMark: 1 << 20 })) hash.update(chunk);
  return hash.digest('hex');
}

async function walk(dir, base = dir, out = []) {
  let entries;
  try {
    entries = await fsp.readdir(dir, { withFileTypes: true });
  } catch (err) {
    if (err.code === 'ENOENT') return out;
    throw err;
  }
  for (const e of entries) {
    if (e.name.startsWith('.') || e.name.endsWith('.part')) continue;
    const abs = path.join(dir, e.name);
    if (e.isDirectory()) await walk(abs, base, out);
    else if (e.isFile()) out.push(abs);
  }
  return out;
}

async function readConfig() {
  try {
    return JSON.parse(await fsp.readFile(CONFIG_FILE, 'utf8'));
  } catch (err) {
    if (err.code !== 'ENOENT') log('launcher.json is invalid:', err.message);
    return {};
  }
}

let manifestPromise = null;
async function buildManifest() {
  const config = await readConfig();
  const files = [];
  for (const abs of (await walk(CLIENT_DIR)).sort()) {
    const st = await fsp.stat(abs);
    let cached = hashCache.get(abs);
    if (!cached || cached.size !== st.size || cached.mtimeMs !== st.mtimeMs) {
      log('hashing', path.relative(CLIENT_DIR, abs));
      cached = { size: st.size, mtimeMs: st.mtimeMs, sha256: await sha256File(abs) };
      hashCache.set(abs, cached);
    }
    files.push({ path: path.relative(CLIENT_DIR, abs).split(path.sep).join('/'), size: st.size, sha256: cached.sha256 });
  }
  const del = Array.isArray(config.delete) ? config.delete : [];
  const version = crypto
    .createHash('sha256')
    .update(JSON.stringify([files.map((f) => [f.path, f.sha256]), del]))
    .digest('hex')
    .slice(0, 12);
  return {
    name: config.name || 'Turtle WoW',
    version,
    realmlist: config.realmlist || null,
    clearCache: config.clearCache !== false,
    news: Array.isArray(config.news) ? config.news : [],
    files,
    delete: del,
  };
}

// Coalesce concurrent requests so a rescan never runs twice at once.
function getManifest() {
  if (!manifestPromise) manifestPromise = buildManifest().finally(() => (manifestPromise = null));
  return manifestPromise;
}

function probe({ host, port }, timeoutMs = 1500) {
  return new Promise((resolve) => {
    const started = Date.now();
    const sock = net.connect({ host, port });
    const done = (online) => {
      sock.destroy();
      resolve({ online, latencyMs: online ? Date.now() - started : null });
    };
    sock.setTimeout(timeoutMs, () => done(false));
    sock.once('connect', () => done(true));
    sock.once('error', () => done(false));
  });
}

let statusCache = { at: 0, value: null };
async function getStatus() {
  if (Date.now() - statusCache.at < 10_000 && statusCache.value) return statusCache.value;
  const [realm, world] = await Promise.all([probe(REALMD), probe(WORLD)]);
  statusCache = { at: Date.now(), value: { realm, world } };
  return statusCache.value;
}

function sendJson(res, code, body) {
  const data = JSON.stringify(body);
  res.writeHead(code, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'Content-Length': Buffer.byteLength(data) });
  res.end(data);
}

async function sendFile(req, res, rel) {
  const abs = path.resolve(CLIENT_DIR, rel);
  if (!abs.startsWith(CLIENT_DIR + path.sep)) return sendJson(res, 400, { error: 'bad path' });
  let st;
  try {
    st = await fsp.stat(abs);
  } catch {
    return sendJson(res, 404, { error: 'not found' });
  }
  if (!st.isFile()) return sendJson(res, 404, { error: 'not found' });

  let start = 0;
  let end = st.size - 1;
  let status = 200;
  const range = /^bytes=(\d+)-(\d*)$/.exec(req.headers.range || '');
  if (range) {
    start = Number(range[1]);
    if (range[2]) end = Math.min(Number(range[2]), end);
    if (start >= st.size || start > end) {
      res.writeHead(416, { 'Content-Range': `bytes */${st.size}` });
      return res.end();
    }
    status = 206;
  }
  const headers = {
    'Content-Type': 'application/octet-stream',
    'Content-Length': end - start + 1,
    'Accept-Ranges': 'bytes',
  };
  if (status === 206) headers['Content-Range'] = `bytes ${start}-${end}/${st.size}`;
  res.writeHead(status, headers);
  if (req.method === 'HEAD') return res.end();
  fs.createReadStream(abs, { start, end }).pipe(res);
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://x');
    if (url.pathname === '/manifest.json') return sendJson(res, 200, await getManifest());
    if (url.pathname === '/status') return sendJson(res, 200, await getStatus());
    if (url.pathname.startsWith('/files/')) {
      const rel = decodeURIComponent(url.pathname.slice('/files/'.length));
      log(req.socket.remoteAddress, 'GET', rel, req.headers.range || '');
      return await sendFile(req, res, rel);
    }
    sendJson(res, 404, { error: 'not found' });
  } catch (err) {
    log('error', err);
    if (!res.headersSent) sendJson(res, 500, { error: 'internal error' });
    else res.destroy();
  }
});

fs.mkdirSync(CLIENT_DIR, { recursive: true });
server.listen(PORT, () => {
  log(`update server on :${PORT}, serving ${CLIENT_DIR}`);
  log(`probing realmd ${REALMD.host}:${REALMD.port}, world ${WORLD.host}:${WORLD.port}`);
  getManifest().then((m) => log(`manifest ${m.version}: ${m.files.length} file(s)`), (e) => log('manifest error', e));
});
