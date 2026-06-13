const { app, BrowserWindow, dialog, ipcMain, shell } = require('electron');
const path = require('path');
const { scanRoot } = require('./scanner');

function createWindow() {
  const win = new BrowserWindow({
    width: 1180,
    height: 760,
    minWidth: 960,
    minHeight: 620,
    title: 'FCPX 清理助手',
    backgroundColor: '#f7f7f4',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  win.loadFile(path.join(__dirname, 'renderer', 'index.html'));
}

app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

ipcMain.handle('choose-directory', async () => {
  const result = await dialog.showOpenDialog({
    title: '选择要扫描的目录',
    properties: ['openDirectory']
  });

  if (result.canceled || !result.filePaths[0]) return null;
  return result.filePaths[0];
});

ipcMain.handle('scan-directory', async (_event, rootPath) => {
  assertAbsolutePath(rootPath);
  return scanRoot(rootPath);
});

ipcMain.handle('clean-targets', async (_event, targets) => {
  if (!Array.isArray(targets)) throw new Error('清理目标格式不正确。');

  const results = [];
  for (const target of targets) {
    assertAbsolutePath(target.path);
    try {
      await shell.trashItem(target.path);
      results.push({ path: target.path, ok: true });
    } catch (error) {
      results.push({ path: target.path, ok: false, error: error.message });
    }
  }

  return results;
});

function assertAbsolutePath(value) {
  if (typeof value !== 'string' || !path.isAbsolute(value)) {
    throw new Error('需要一个有效的绝对路径。');
  }
}
