'use strict';

// End-to-end: real update server process + the launcher's updater module.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');
const { spawn } = require('child_process');
const updater = require('../src/updater');

const PORT = 18090 + Math.floor(Math.random() * 1000);
const SERVER = `http://127.0.0.1:${PORT}/`;
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'turtle-launcher-test-'));
const dataDir = path.join(tmp, 'server');
const clientDir = path.join(tmp, 'client');
let proc;

function write(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content);
}

test.before(async () => {
  write(path.join(dataDir, 'client/Data/patch-Z.mpq'), crypto.randomBytes(3 * 1024 * 1024 + 17));
  write(path.join(dataDir, 'client/Interface/AddOns/Hello/Hello.toc'), '## Title: Hello\n');
  write(
    path.join(dataDir, 'launcher.json'),
    JSON.stringify({ name: 'Test Realm', realmlist: '10.0.0.5', delete: ['Data/patch-Y.mpq', '../escape.txt'] }),
  );
  write(path.join(clientDir, 'WoW.exe'), 'exe');
  write(path.join(clientDir, 'Data/patch-Y.mpq'), 'old');
  write(path.join(clientDir, 'WDB/creaturecache.wdb'), 'cache');
  write(path.join(clientDir, 'WTF/Config.wtf'), 'SET gxResolution "1920x1080"\nSET realmList "old.example.com"\n');

  proc = spawn(process.execPath, [path.join(__dirname, '../server/update-server.js')], {
    env: { ...process.env, PORT, DATA_DIR: dataDir, REALMD_PORT: '1', WORLD_PORT: '1' },
    stdio: 'ignore',
  });
  for (let i = 0; i < 50; i++) {
    try {
      await updater.fetchManifest(SERVER);
      return;
    } catch {
      await new Promise((r) => setTimeout(r, 100));
    }
  }
  throw new Error('server did not start');
});

test.after(() => {
  proc?.kill();
  fs.rmSync(tmp, { recursive: true, force: true });
});

test('manifest refuses paths outside the client folder', async () => {
  const manifest = await updater.fetchManifest(SERVER);
  const cache = new updater.HashCache(path.join(tmp, 'c0.json'));
  await assert.rejects(updater.plan({ clientDir, manifest, cache }), /unsafe path/);
});

test('fresh install, resume, corruption and deletes', async () => {
  const manifest = await updater.fetchManifest(SERVER);
  manifest.delete = manifest.delete.filter((p) => !p.startsWith('..'));
  assert.equal(manifest.name, 'Test Realm');
  assert.equal(manifest.files.length, 2);
  const cache = new updater.HashCache(path.join(tmp, 'cache.json'));

  // Simulate an interrupted earlier download of the big file.
  const src = fs.readFileSync(path.join(dataDir, 'client/Data/patch-Z.mpq'));
  write(path.join(clientDir, 'Data/patch-Z.mpq.part'), src.subarray(0, 1024 * 1024));

  let p = await updater.plan({ clientDir, manifest, cache });
  assert.equal(p.toDownload.length, 2);
  assert.deepEqual(p.toDelete, ['Data/patch-Y.mpq']);

  let bytes = 0;
  for (const file of p.toDownload) {
    await updater.downloadFile({ serverUrl: SERVER, clientDir, file, cache, onBytes: (n) => (bytes += n) });
  }
  assert.equal(bytes, src.length + 16);
  assert.ok(fs.readFileSync(path.join(clientDir, 'Data/patch-Z.mpq')).equals(src));
  assert.ok(!fs.existsSync(path.join(clientDir, 'Data/patch-Z.mpq.part')));

  await updater.applyRealmlist(clientDir, manifest.realmlist);
  assert.match(fs.readFileSync(path.join(clientDir, 'realmlist.wtf'), 'utf8'), /SET realmList "10\.0\.0\.5"/);
  const config = fs.readFileSync(path.join(clientDir, 'WTF/Config.wtf'), 'utf8');
  assert.match(config, /SET realmList "10\.0\.0\.5"/);
  assert.match(config, /gxResolution "1920x1080"/);

  // Second check is a no-op and needs no hashing thanks to the cache.
  let verified = 0;
  p = await updater.plan({ clientDir, manifest, cache, onProgress: () => verified++ });
  assert.equal(p.toDownload.length, 0);
  assert.equal(verified, 0);

  // Same-size corruption is caught by a full verify.
  const buf = fs.readFileSync(path.join(clientDir, 'Data/patch-Z.mpq'));
  buf[100] ^= 0xff;
  fs.writeFileSync(path.join(clientDir, 'Data/patch-Z.mpq'), buf);
  const st = fs.statSync(path.join(clientDir, 'Data/patch-Z.mpq'));
  cache.set(path.join(clientDir, 'Data/patch-Z.mpq'), st, manifest.files.find((f) => f.path === 'Data/patch-Z.mpq').sha256);
  p = await updater.plan({ clientDir, manifest, cache });
  assert.equal(p.toDownload.length, 0, 'cache trusts size+mtime');
  p = await updater.plan({ clientDir, manifest, cache, fullVerify: true });
  assert.deepEqual(p.toDownload.map((f) => f.path), ['Data/patch-Z.mpq']);

  await updater.clearCache(clientDir);
  assert.ok(!fs.existsSync(path.join(clientDir, 'WDB')));
});

test('server picks up new files without a restart', async () => {
  const before = await updater.fetchManifest(SERVER);
  write(path.join(dataDir, 'client/Data/patch-W.mpq'), 'new patch');
  const after = await updater.fetchManifest(SERVER);
  assert.notEqual(before.version, after.version);
  assert.ok(after.files.some((f) => f.path === 'Data/patch-W.mpq'));
});

test('status reports offline realm', async () => {
  const s = await updater.fetchStatus(SERVER);
  assert.equal(s.realm.online, false);
  assert.equal(s.world.online, false);
});
