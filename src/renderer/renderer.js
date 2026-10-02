'use strict';

const $ = (id) => document.getElementById(id);
const api = window.launcher;
const FIELDS = ['clientDir', 'realmHost', 'serverUrl', 'executable', 'launchCommand', 'winePrefix', 'closeOnLaunch'];

let ready = false; // client is up to date
let serverOnline = false; // realm and world both answer
let playLabel = 'Play';
let updating = false;
let installedVersion = null; // manifest version of the last successful update
const UPDATE_POLL_MS = 60000;

function fmtBytes(n) {
  const units = ['B', 'KB', 'MB', 'GB'];
  let i = 0;
  while (n >= 1024 && i < units.length - 1) {
    n /= 1024;
    i++;
  }
  return `${n.toFixed(i ? 1 : 0)} ${units[i]}`;
}

function setStatus(text, detail = '', pct = null) {
  $('status-text').textContent = text;
  $('status-detail').textContent = detail;
  const fill = $('bar-fill');
  fill.classList.toggle('indeterminate', pct === 'busy');
  if (pct !== 'busy') fill.style.width = `${pct ?? 0}%`;
}

function setPlayable(on, label = 'Play') {
  ready = on;
  playLabel = label;
  renderPlay();
}

// Play needs both an up-to-date client and a reachable realm.
function renderPlay() {
  const offline = ready && !serverOnline;
  $('play').disabled = !ready || offline;
  $('play').textContent = offline ? 'Offline' : playLabel;
  $('play').title = offline ? 'The realm is offline' : '';
}

// Download speed, smoothed over the last few seconds.
const speed = { samples: [] };
function rate(done) {
  const now = Date.now();
  speed.samples.push([now, done]);
  while (speed.samples.length > 2 && now - speed.samples[0][0] > 4000) speed.samples.shift();
  const [t0, d0] = speed.samples[0];
  return now > t0 ? ((done - d0) / (now - t0)) * 1000 : 0;
}

api.onProgress((p) => {
  if (p.phase === 'connect') return setStatus('Connecting to update server…', '', 'busy');
  const pct = p.total ? (p.done / p.total) * 100 : 0;
  if (p.phase === 'verify') {
    setStatus(`Verifying ${p.file}`, `${Math.floor(pct)}%`, pct);
  } else if (p.phase === 'download') {
    const bps = rate(p.done);
    const eta = bps > 0 ? Math.ceil((p.total - p.done) / bps) : null;
    const etaText = eta == null ? '' : eta > 90 ? ` · ${Math.ceil(eta / 60)} min left` : ` · ${eta}s left`;
    setStatus(`Downloading ${p.file}`, `${fmtBytes(p.done)} / ${fmtBytes(p.total)} · ${fmtBytes(bps)}/s${etaText}`, pct);
  }
});

api.onGameExited(() => autoUpdate());

api.onGameError((msg) => {
  setStatus(msg, '', 0);
  setPlayable(true);
});

function renderNews(news) {
  const list = $('news-list');
  list.replaceChildren();
  if (!news?.length) {
    list.innerHTML = '<p class="muted">Nothing yet.</p>';
    return;
  }
  for (const item of news) {
    const a = document.createElement('article');
    const h = document.createElement('h3');
    h.textContent = item.title || '';
    a.append(h);
    if (item.date) {
      const t = document.createElement('time');
      t.textContent = item.date;
      a.append(t);
    }
    const body = document.createElement('p');
    body.textContent = item.body || '';
    a.append(body);
    list.append(a);
  }
}

async function update(opts) {
  if (updating) return;
  updating = true;
  speed.samples = [];
  setPlayable(false, 'Play');
  setStatus('Checking for updates…', '', 'busy');
  const r = await api.runUpdate(opts);
  updating = false;
  switch (r.state) {
    case 'ready': {
      installedVersion = r.version;
      $('server-name').textContent = r.name;
      renderNews(r.news);
      const what = [r.updated && `${r.updated} file(s) updated`, r.removed && `${r.removed} removed`].filter(Boolean).join(', ');
      setStatus('Ready to play', what || 'Client is up to date', 100);
      setPlayable(true);
      break;
    }
    case 'offline':
      setStatus(r.message, '', 0);
      setPlayable(true); // still blocked by renderPlay while the realm is down
      break;
    case 'needs-client':
      setStatus(r.message, '', 0);
      setPlayable(false);
      openSettings();
      break;
    case 'busy':
      break;
    default:
      setStatus(r.message || 'Update failed', 'Open settings to retry', 0);
      setPlayable(false, 'Retry');
      $('play').disabled = false;
  }
}

// True when the server publishes a client version this launcher hasn't installed.
async function newVersionAvailable() {
  if (installedVersion == null) return null;
  const p = await api.peekUpdate();
  if (!p || p.version === installedVersion) return null;
  return p;
}

// Installs a new client version as soon as one appears, unless the game is
// running (its open files can't be replaced); then it waits for the game to exit.
async function autoUpdate() {
  if (updating || !ready) return;
  const p = await newVersionAvailable();
  if (!p) return;
  if (p.gameRunning) {
    setStatus('Update available', 'It installs automatically when you close the game', 100);
    return;
  }
  update();
}

async function refreshStatus() {
  const el = $('realm-status');
  const s = await api.serverStatus();
  serverOnline = !!(s && s.realm.online && s.world.online);
  if (playLabel === 'Play') renderPlay();
  el.classList.remove('online', 'partial', 'offline');
  if (!s) {
    el.classList.add('offline');
    el.querySelector('.label').textContent = 'Server unreachable';
  } else if (s.realm.online && s.world.online) {
    el.classList.add('online');
    el.querySelector('.label').textContent = `Realm online · ${s.world.latencyMs ?? '?'} ms`;
  } else if (s.realm.online) {
    el.classList.add('partial');
    el.querySelector('.label').textContent = 'Login up, world down';
  } else {
    el.classList.add('offline');
    el.querySelector('.label').textContent = 'Realm offline';
  }
}

async function openSettings() {
  const s = await api.getSettings();
  for (const f of FIELDS) {
    const input = $(`s-${f}`);
    if (input.type === 'checkbox') input.checked = !!s[f];
    else input.value = s[f] ?? '';
  }
  $('settings').returnValue = '';
  if (!$('settings').open) $('settings').showModal();
}

function readForm() {
  const patch = {};
  for (const f of FIELDS) {
    const input = $(`s-${f}`);
    patch[f] = input.type === 'checkbox' ? input.checked : input.value.trim();
  }
  return patch;
}

$('play').addEventListener('click', async () => {
  if (!ready) return update();
  setPlayable(false, 'Starting…');
  // Never start the game on an outdated client.
  const newer = await newVersionAvailable();
  if (newer && !newer.gameRunning) {
    await update();
    if (!ready) return;
    setPlayable(false, 'Starting…');
  }
  const r = await api.launch();
  if (!r.ok) {
    setStatus(r.message, '', 0);
    setPlayable(true);
    return;
  }
  setStatus('Game started. Have fun!', '', 100);
  setTimeout(() => setPlayable(true), 4000);
});

$('open-settings').addEventListener('click', openSettings);
$('browse').addEventListener('click', async () => {
  const dir = await api.pickFolder();
  if (dir) $('s-clientDir').value = dir;
});
$('verify').addEventListener('click', async () => {
  await api.setSettings(readForm());
  $('settings').close();
  update({ fullVerify: true });
});
$('clear-cache').addEventListener('click', async () => {
  const ok = await api.clearCache();
  $('clear-cache').textContent = ok ? 'Cache cleared ✓' : 'Set the folder first';
  setTimeout(() => ($('clear-cache').textContent = 'Clear WDB cache'), 2000);
});
$('open-folder').addEventListener('click', () => api.openFolder());
$('settings').addEventListener('close', async () => {
  if ($('settings').returnValue !== 'save') return;
  const s = await api.setSettings(readForm());
  $('server-url').textContent = s.realmHost;
  refreshStatus();
  update();
});

(async () => {
  const s = await api.getSettings();
  document.body.classList.add(s.platform);
  $('server-url').textContent = s.realmHost;
  refreshStatus();
  setInterval(refreshStatus, 10000);
  setInterval(autoUpdate, UPDATE_POLL_MS);
  update();
})();
