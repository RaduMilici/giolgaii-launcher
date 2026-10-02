'use strict';

const fs = require('fs');
const fsp = fs.promises;
const path = require('path');
const crypto = require('crypto');
const net = require('net');
const { Readable, Transform } = require('stream');
const { pipeline } = require('stream/promises');

// Remembers the hash of each local file by size+mtime so a check only re-hashes
// files that changed since the last run (patch files are hundreds of MB).
class HashCache {
  constructor(file) {
    this.file = file;
    try {
      this.data = JSON.parse(fs.readFileSync(file, 'utf8'));
    } catch {
      this.data = {};
    }
  }
  get(abs, st) {
    const e = this.data[abs];
    return e && e.size === st.size && e.mtimeMs === st.mtimeMs ? e.sha256 : null;
  }
  set(abs, st, sha256) {
    this.data[abs] = { size: st.size, mtimeMs: st.mtimeMs, sha256 };
  }
  clear() {
    this.data = {};
  }
  save() {
    fs.writeFileSync(this.file, JSON.stringify(this.data));
  }
}

function baseUrl(serverUrl) {
  return serverUrl.endsWith('/') ? serverUrl : serverUrl + '/';
}

async function fetchJson(url, timeoutMs = 5000) {
  const res = await fetch(url, { signal: AbortSignal.timeout(timeoutMs), cache: 'no-store' });
  if (!res.ok) throw new Error(`${url} answered HTTP ${res.status}`);
  return res.json();
}

function fetchManifest(serverUrl) {
  return fetchJson(new URL('manifest.json', baseUrl(serverUrl)));
}

function fetchStatus(serverUrl) {
  return fetchJson(new URL('status', baseUrl(serverUrl)), 4000);
}

// Checks a port by opening a TCP connection, like the client would.
function probe(host, port, timeoutMs = 3000) {
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

// Realm status straight from the realm's login (realmd) and world (mangosd) ports.
async function realmStatus(host, realmPort = 3724, worldPort = 8085) {
  const [realm, world] = await Promise.all([probe(host, realmPort), probe(host, worldPort)]);
  return { realm, world };
}

// Resolves a manifest path inside the client folder; refuses anything that
// would escape it, so a bad manifest can never touch files elsewhere.
function safeJoin(root, rel) {
  if (typeof rel !== 'string' || !rel || rel.includes('\0') || path.isAbsolute(rel) || /^[a-zA-Z]:/.test(rel)) {
    throw new Error(`Refusing unsafe path from server: ${rel}`);
  }
  const abs = path.resolve(root, rel);
  if (!abs.startsWith(path.resolve(root) + path.sep)) throw new Error(`Refusing unsafe path from server: ${rel}`);
  return abs;
}

async function sha256File(file, onBytes) {
  const hash = crypto.createHash('sha256');
  for await (const chunk of fs.createReadStream(file, { highWaterMark: 1 << 20 })) {
    hash.update(chunk);
    if (onBytes) onBytes(chunk.length);
  }
  return hash.digest('hex');
}

// Compares the manifest against the client folder. Returns the files that need
// downloading and the obsolete files that should be removed.
async function plan({ clientDir, manifest, cache, onProgress, fullVerify = false }) {
  const toDownload = [];
  const toHash = [];
  for (const f of manifest.files) {
    const abs = safeJoin(clientDir, f.path);
    let st;
    try {
      st = await fsp.stat(abs);
    } catch {
      toDownload.push(f);
      continue;
    }
    if (st.size !== f.size) toDownload.push(f);
    else if (!fullVerify && cache.get(abs, st) === f.sha256) continue;
    else toHash.push({ f, abs, st });
  }

  const totalBytes = toHash.reduce((n, x) => n + x.st.size, 0);
  let doneBytes = 0;
  for (const { f, abs, st } of toHash) {
    onProgress?.({ phase: 'verify', file: f.path, done: doneBytes, total: totalBytes });
    const sha = await sha256File(abs, (n) => {
      doneBytes += n;
      onProgress?.({ phase: 'verify', file: f.path, done: doneBytes, total: totalBytes });
    });
    cache.set(abs, st, sha);
    if (sha !== f.sha256) toDownload.push(f);
  }

  const toDelete = [];
  for (const rel of manifest.delete || []) {
    const abs = safeJoin(clientDir, rel);
    if (fs.existsSync(abs)) toDelete.push(rel);
  }
  return { toDownload, toDelete, downloadBytes: toDownload.reduce((n, f) => n + f.size, 0) };
}

// Downloads one file to <file>.part (resuming a previous partial download),
// verifies its hash and then moves it into place.
async function downloadFile({ serverUrl, clientDir, file, cache, signal, onBytes }) {
  const dest = safeJoin(clientDir, file.path);
  const part = dest + '.part';
  await fsp.mkdir(path.dirname(dest), { recursive: true });

  const hash = crypto.createHash('sha256');
  let start = 0;
  try {
    start = (await fsp.stat(part)).size;
  } catch {}
  if (start >= file.size) {
    await fsp.rm(part, { force: true });
    start = 0;
  }

  const url = new URL('files/' + file.path.split('/').map(encodeURIComponent).join('/'), baseUrl(serverUrl));
  const res = await fetch(url, { signal, headers: start ? { Range: `bytes=${start}-` } : {} });
  if (res.status === 200) start = 0; // server ignored the range, start over
  else if (res.status !== 206) throw new Error(`Download of ${file.path} failed: HTTP ${res.status}`);

  if (start > 0) {
    // Resuming: feed the bytes we already have into the running hash.
    for await (const chunk of fs.createReadStream(part, { highWaterMark: 1 << 20 })) {
      hash.update(chunk);
      onBytes(chunk.length);
    }
  }

  const tap = new Transform({
    transform(chunk, _enc, cb) {
      hash.update(chunk);
      onBytes(chunk.length);
      cb(null, chunk);
    },
  });
  await pipeline(Readable.fromWeb(res.body), tap, fs.createWriteStream(part, { flags: start ? 'a' : 'w' }), { signal });

  const sha = hash.digest('hex');
  if (sha !== file.sha256) {
    await fsp.rm(part, { force: true });
    throw new Error(`${file.path} was corrupted in transit, please retry`);
  }
  await fsp.rm(dest, { force: true });
  await fsp.rename(part, dest);
  cache.set(dest, await fsp.stat(dest), sha);
}

// Points the client at the server: realmlist.wtf plus any realmList/patchList
// override in WTF/Config.wtf (which would otherwise win).
async function applyRealmlist(clientDir, realmlist) {
  if (!realmlist) return;
  await fsp.writeFile(path.join(clientDir, 'realmlist.wtf'), `SET realmList "${realmlist}"\r\nSET patchList "${realmlist}"\r\n`);
  const configPath = path.join(clientDir, 'WTF', 'Config.wtf');
  let config;
  try {
    config = await fsp.readFile(configPath, 'utf8');
  } catch {
    return;
  }
  const updated = config.replace(/^(SET (?:realmList|patchList) )".*"/gim, `$1"${realmlist}"`);
  if (updated !== config) await fsp.writeFile(configPath, updated);
}

async function clearCache(clientDir) {
  await fsp.rm(path.join(clientDir, 'WDB'), { recursive: true, force: true });
}

module.exports = { HashCache, fetchManifest, fetchStatus, realmStatus, plan, downloadFile, applyRealmlist, clearCache, safeJoin };
