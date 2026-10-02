# Giolgăii WoW Launcher

Launcher + auto-updater for a private Turtle WoW server.

- `server/` – tiny update server (zero deps) that runs next to tortoise-deploy.
- `src/` – Electron launcher: syncs the client, writes the realmlist, launches the game.

## Server

Put the files players should have under `server/launcher-data/client/`, using the
same layout as the game folder, e.g.:

```
server/launcher-data/client/Data/patch-Z.mpq
server/launcher-data/client/Interface/AddOns/MyAddon/...
```

Edit `server/launcher-data/launcher.json` (realm name, `realmlist` address, news,
obsolete files to `delete`). Then:

```sh
cd server && docker compose up -d     # or: npm run server
```

It listens on :8090 (open that port for friends outside the LAN). The folder is
rescanned on every check, so adding a patch takes effect right away.
`clearCache: true` wipes the players' WDB cache whenever an update downloads files.

## Launcher

```sh
npm install && node node_modules/electron/install.js
npm start
npm run dist:linux   # dist/GiolgaiiWoW-1.0.0.AppImage
npm run dist:win     # dist/GiolgaiiWoW.exe (portable)
```

Set the default server URL in `defaults.json` before building copies for friends.
If the exe/AppImage sits inside the WoW folder, that folder is picked up
automatically. On Linux, set the launch command (`wine`, `umu-run`, …) in Settings.

## Tests

`npm test` starts a real update server and checks fresh downloads, resuming,
corruption detection, deletes, the realmlist and path-escape protection.
