'use strict';
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('bgeHost', { quit: () => ipcRenderer.send('bge:quit') });
