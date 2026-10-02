'use strict';

const { app, BrowserWindow, ipcMain, dialog, shell } = require('electron');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawn } = require('child_process');
const updater = require('./updater');

const defaults = require('../defaults.json');
const settingsFile = () => path.join(app.getPath('userData'), 'settings.json');
const stateFile = () => path.join(app.getPath('userData'), 'state.json');

let win;
let cache;
let busy = false;
let abort = null;
let gameRunning = false;

function readJson(file, fallback) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return fallback;
  }
}

// When the launcher sits inside the client folder (the usual way to ship it),
// use that folder without asking.
function detectClientDir() {
  const candidates = [
    process.env.PORTABLE_EXECUTABLE_DIR,
    process.env.APPIMAGE && path.dirname(process.env.APPIMAGE),
    path.dirname(app.getPath('exe')),
    path.dirname(path.dirname(app.getPath('exe'))), // unpacked build in a subfolder
    process.cwd(),
  ].filter(Boolean);
  return candidates.find((d) => fs.existsSync(path.join(d, defaults.executable || 'WoW.exe'))) || '';
}

function loadSettings() {
  const s = { ...defaults, ...readJson(settingsFile(), {}) };
  if (!s.clientDir) s.clientDir = detectClientDir();
  return s;
}

function saveSettings(patch) {
  const current = readJson(settingsFile(), {});
  fs.writeFileSync(settingsFile(), JSON.stringify({ ...current, ...patch }, null, 2));
  return loadSettings();
}

function send(channel, payload) {
  if (win && !win.isDestroyed()) win.webContents.send(channel, payload);
}

function progress(p) {
  send('update:progress', p);
}

function validClientDir(dir, exe) {
  return dir && fs.existsSync(path.join(dir, exe));
}

// Full check-and-update pass. Reports progress via 'update:progress' and
// resolves to a summary the UI shows.
async function runUpdate({ fullVerify = false } = {}) {
  if (busy) return { state: 'busy' };
  busy = true;
  abort = new AbortController();
  const s = loadSettings();
  try {
    if (!validClientDir(s.clientDir, s.executable)) {
      return { state: 'needs-client', message: `Pick your Turtle WoW folder (the one containing ${s.executable}).` };
    }
    progress({ phase: 'connect' });
    let manifest;
    try {
      manifest = await updater.fetchManifest(s.serverUrl);
    } catch {
      // No update server: still point the client at the realm so Play works.
      await updater.applyRealmlist(s.clientDir, s.realmHost);
      return { state: 'offline', message: 'Update server unavailable, skipped the update check.' };
    }

    if (fullVerify) cache.clear();
    const p = await updater.plan({ clientDir: s.clientDir, manifest, cache, onProgress: progress, fullVerify });
    cache.save();

    for (const rel of p.toDelete) {
      await fs.promises.rm(updater.safeJoin(s.clientDir, rel), { force: true, recursive: true });
    }

    let done = 0;
    for (const [i, file] of p.toDownload.entries()) {
      const label = `${file.path} (${i + 1}/${p.toDownload.length})`;
      const before = done;
      let fileDone = 0;
      await updater.downloadFile({
        serverUrl: s.serverUrl,
        clientDir: s.clientDir,
        file,
        cache,
        signal: abort.signal,
        onBytes: (n) => {
          fileDone += n;
          done = before + fileDone;
          progress({ phase: 'download', file: label, done, total: p.downloadBytes });
        },
      });
      done = before + file.size;
      cache.save();
    }

    await updater.applyRealmlist(s.clientDir, manifest.realmlist || s.realmHost);

    const state = readJson(stateFile(), {});
    const changed = state.version !== manifest.version;
    if (changed && manifest.clearCache && (p.toDownload.length || p.toDelete.length)) {
      await updater.clearCache(s.clientDir);
    }
    fs.writeFileSync(stateFile(), JSON.stringify({ ...state, version: manifest.version }));

    return {
      state: 'ready',
      name: manifest.name,
      news: manifest.news,
      version: manifest.version,
      updated: p.toDownload.length,
      removed: p.toDelete.length,
    };
  } catch (err) {
    if (abort.signal.aborted) return { state: 'cancelled', message: 'Update cancelled.' };
    return { state: 'error', message: err.message };
  } finally {
    busy = false;
    abort = null;
    cache.save();
  }
}

// Splits "umu-run --foo 'a b'" into argv, honouring simple quotes.
function splitCommand(cmd) {
  return (cmd.match(/"[^"]*"|'[^']*'|\S+/g) || []).map((a) => a.replace(/^(["'])(.*)\1$/, '$2'));
}

function launchGame() {
  const s = loadSettings();
  if (busy) return { ok: false, message: 'Wait for the update to finish.' };
  if (!validClientDir(s.clientDir, s.executable)) return { ok: false, message: 'Client folder not set.' };
  const exe = path.join(s.clientDir, s.executable);
  const env = { ...process.env };
  if (s.winePrefix) env.WINEPREFIX = s.winePrefix.replace(/^~(?=$|\/)/, os.homedir());

  let cmd = exe;
  let args = [];
  if (process.platform !== 'win32') {
    const parts = splitCommand(s.launchCommand || 'wine');
    if (!parts.length) return { ok: false, message: 'Set a launch command (e.g. wine) in Settings.' };
    [cmd, ...args] = parts;
    args.push(exe);
  }
  try {
    // Keep the game's output so a failed start can be diagnosed.
    const log = fs.openSync(path.join(app.getPath('userData'), 'launch.log'), 'w');
    fs.writeSync(log, `$ ${[cmd, ...args].join(' ')}\nWINEPREFIX=${env.WINEPREFIX || ''}\n\n`);
    const child = spawn(cmd, args, { cwd: s.clientDir, env, detached: true, stdio: ['ignore', log, log] });
    fs.closeSync(log);
    gameRunning = true;
    child.on('error', (err) => {
      gameRunning = false;
      send('game:error', `Couldn't start the game with "${cmd}": ${err.message}`);
    });
    // Files the game has open can't be replaced, so updates wait for it to exit.
    child.on('exit', () => {
      gameRunning = false;
      send('game:exited');
    });
    child.unref();
  } catch (err) {
    return { ok: false, message: err.message };
  }
  if (s.closeOnLaunch) setTimeout(() => app.quit(), 1500);
  return { ok: true };
}

function createWindow() {
  win = new BrowserWindow({
    width: 1100,
    height: 690,
    resizable: false,
    backgroundColor: '#0a0806',
    title: 'Giolgăii WoW',
    icon: path.join(__dirname, 'icon.png'),
    autoHideMenuBar: true,
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, sandbox: true },
  });
  win.removeMenu();
  win.loadFile(path.join(__dirname, 'renderer', 'index.html'));
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:/.test(url)) shell.openExternal(url);
    return { action: 'deny' };
  });
}

ipcMain.handle('settings:get', () => ({ ...loadSettings(), platform: process.platform }));
ipcMain.handle('settings:set', (_e, patch) => saveSettings(patch));
ipcMain.handle('dialog:pickFolder', async () => {
  const r = await dialog.showOpenDialog(win, { properties: ['openDirectory'], title: 'Select your Turtle WoW folder' });
  return r.canceled ? null : r.filePaths[0];
});
ipcMain.handle('update:run', (_e, opts) => runUpdate(opts));
ipcMain.handle('update:cancel', () => abort?.abort());
// Cheap check for a new client version: only fetches the manifest, touches no files.
ipcMain.handle('update:peek', async () => {
  try {
    const manifest = await updater.fetchManifest(loadSettings().serverUrl);
    return { version: manifest.version, gameRunning };
  } catch {
    return null;
  }
});
ipcMain.handle('server:status', () => {
  const s = loadSettings();
  return updater.realmStatus(s.realmHost, s.realmPort, s.worldPort);
});
ipcMain.handle('game:launch', () => launchGame());
ipcMain.handle('cache:clear', async () => {
  const s = loadSettings();
  if (!validClientDir(s.clientDir, s.executable)) return false;
  await updater.clearCache(s.clientDir);
  return true;
});
ipcMain.handle('folder:open', () => {
  const dir = loadSettings().clientDir;
  if (dir) shell.openPath(dir);
});

if (!app.requestSingleInstanceLock()) app.quit();
app.on('second-instance', () => win?.focus());
app.whenReady().then(() => {
  cache = new updater.HashCache(path.join(app.getPath('userData'), 'hash-cache.json'));
  createWindow();
});
app.on('window-all-closed', () => app.quit());
