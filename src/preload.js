'use strict';

const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('launcher', {
  getSettings: () => ipcRenderer.invoke('settings:get'),
  setSettings: (patch) => ipcRenderer.invoke('settings:set', patch),
  pickFolder: () => ipcRenderer.invoke('dialog:pickFolder'),
  runUpdate: (opts) => ipcRenderer.invoke('update:run', opts),
  cancelUpdate: () => ipcRenderer.invoke('update:cancel'),
  peekUpdate: () => ipcRenderer.invoke('update:peek'),
  serverStatus: () => ipcRenderer.invoke('server:status'),
  launch: () => ipcRenderer.invoke('game:launch'),
  clearCache: () => ipcRenderer.invoke('cache:clear'),
  openFolder: () => ipcRenderer.invoke('folder:open'),
  onProgress: (fn) => ipcRenderer.on('update:progress', (_e, p) => fn(p)),
  onGameError: (fn) => ipcRenderer.on('game:error', (_e, msg) => fn(msg)),
  onGameExited: (fn) => ipcRenderer.on('game:exited', () => fn()),
});
