const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('fcpxCleaner', {
  chooseDirectory: () => ipcRenderer.invoke('choose-directory'),
  scanDirectory: (rootPath) => ipcRenderer.invoke('scan-directory', rootPath),
  cleanTargets: (targets) => ipcRenderer.invoke('clean-targets', targets)
});
