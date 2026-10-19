/* eslint global-require: off, no-console: off */

/**
 * This module executes inside of electron's main process. You can start
 * electron renderer process from here and communicate with the other processes
 * through IPC.
 *
 * When running `yarn build` or `yarn build-main`, this file is compiled to
 * `./app/main.prod.js` using webpack. This gives us some performance wins.
 */
import 'core-js/stable';
import 'regenerator-runtime/runtime';
import path from 'path';
import fs from 'fs';
import { spawn } from 'child_process';
import https from 'https';
import { app, BrowserWindow, dialog, ipcMain, Menu, MenuItem, shell } from 'electron';
import { autoUpdater } from 'electron-updater';
import log from 'electron-log';
const remoteMain = require("@electron/remote/main");
// import MenuBuilder from './menu';

const isMac = process.platform === 'darwin'
var closed = false;

// This maintained copy publishes its own releases; the official ones would replace its fixes
const RELEASES_REPO = 'Mikakei/Fribbels-Epic-7-Optimizer';

// Root holding data/ and scripts/: the exe folder of the portable zip, or the repo root of a local build (see MAINTENANCE.md)
const ROOT_PATH = app.isPackaged ? path.dirname(app.getPath('exe')) : path.resolve(__dirname, '..');
const SCRIPTS_PATH = path.join(ROOT_PATH, 'scripts');
const isLocalBuild = !app.isPackaged && fs.existsSync(SCRIPTS_PATH);
const hasScript = (name) => fs.existsSync(path.join(SCRIPTS_PATH, name));

// Use the Java bundled in the portable zip (jre/) or the local build's .toolchain JDK, so no system Java is needed
try {
  const toolchain = path.join(ROOT_PATH, '.toolchain');
  const localJdk = isLocalBuild && fs.existsSync(toolchain) ? fs.readdirSync(toolchain).find(x => x.startsWith('jdk')) : null;
  const javaBin = [path.join(ROOT_PATH, 'jre', 'bin'), localJdk && path.join(toolchain, localJdk, 'bin')]
    .find(dir => dir && fs.existsSync(path.join(dir, 'java.exe')));
  if (javaBin) {
    process.env.PATH = javaBin + path.delimiter + process.env.PATH;
  }
  // Local build only: pin the Python version the importer runs with
  const pythonVersionFile = path.join(toolchain, 'python-version');
  if (isLocalBuild && !process.env.PY_PYTHON && fs.existsSync(pythonVersionFile)) {
    process.env.PY_PYTHON = fs.readFileSync(pythonVersionFile, 'utf8').trim();
  }
} catch (e) {
  console.log("Unable to set up bundled Java", e);
}

const appVersion = (() => {
  try {
    return JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json'), 'utf8')).version;
  } catch (e) {
    return app.getVersion();
  }
})();

// Opens one of the scripts/*.cmd tools in its own console window, which closes when the script ends
function runScript(name, args = []) {
  spawn('cmd.exe', ['/c', 'start', '', 'cmd.exe', '/c', path.join(SCRIPTS_PATH, name), ...args], {
    cwd: ROOT_PATH,
    detached: true,
    stdio: 'ignore'
  }).unref();
}

// Used by the Tools menu and the Information tab's update button: close the app and run the update script
async function confirmLocalUpdate() {
  const result = await dialog.showMessageBox(mainWindow, {
    type: 'question',
    buttons: ['开始更新', '取消'],
    defaultId: 0,
    cancelId: 1,
    title: '检查更新',
    message: '检查并安装原仓库的更新',
    detail: '配装器会先关闭，更新完成后自动重新打开。更新过程显示在单独的窗口里。'
  });
  if (result.response !== 0) return;
  runScript('update-optimizer.cmd', ['-WaitForApp', '-Relaunch']);
  mainWindow.close();
}

function getJson(url) {
  return new Promise((resolve, reject) => {
    const request = https.get(url, { headers: { 'User-Agent': 'FribbelsE7Optimizer', 'Accept': 'application/vnd.github+json' } }, (response) => {
      let body = '';
      response.on('data', (chunk) => body += chunk);
      response.on('end', () => {
        if (response.statusCode !== 200) return reject(new Error('HTTP ' + response.statusCode));
        try { resolve(JSON.parse(body)); } catch (e) { reject(e); }
      });
    });
    request.setTimeout(15000, () => request.destroy(new Error('timeout')));
    request.on('error', reject);
  });
}

function isNewerVersion(latest, current) {
  const parse = (v) => String(v).replace(/^v/, '').split(/[.-]/).slice(0, 3).map(x => parseInt(x, 10) || 0);
  const a = parse(latest), b = parse(current);
  for (let i = 0; i < 3; i++) {
    if (a[i] !== b[i]) return a[i] > b[i];
  }
  return false;
}

// Portable zip: look up the latest release of this maintained copy and offer its download page
async function checkReleaseUpdate() {
  const releasesPage = `https://github.com/${RELEASES_REPO}/releases`;
  try {
    const latest = await getJson(`https://api.github.com/repos/${RELEASES_REPO}/releases/latest`);
    if (isNewerVersion(latest.tag_name, appVersion)) {
      const result = await dialog.showMessageBox(mainWindow, {
        type: 'info',
        buttons: ['打开下载页面', '以后再说'],
        defaultId: 0,
        cancelId: 1,
        title: '检查更新',
        message: `有新版本 ${latest.tag_name}`,
        detail: `当前版本 v${appVersion}。下载新的压缩包，解压后覆盖或替换原来的程序文件夹即可，存档在"文档\\FribbelsOptimizerSaves"里，不受影响。`
      });
      if (result.response === 0) shell.openExternal(latest.html_url || releasesPage);
    } else {
      await dialog.showMessageBox(mainWindow, { type: 'info', title: '检查更新', message: `已经是最新版本 v${appVersion}` });
    }
  } catch (e) {
    const result = await dialog.showMessageBox(mainWindow, {
      type: 'warning',
      buttons: ['打开下载页面', '关闭'],
      defaultId: 0,
      cancelId: 1,
      title: '检查更新',
      message: '无法连接 GitHub 检查更新',
      detail: String(e.message || e)
    });
    if (result.response === 0) shell.openExternal(releasesPage);
  }
}

const checkForUpdates = () => isLocalBuild ? confirmLocalUpdate() : checkReleaseUpdate();

const toolsMenu = {
  label: '工具',
  submenu: [
    { label: '检查更新…', click: checkForUpdates },
    hasScript('check-importer.cmd') && { label: '检测导入环境', click: () => runScript('check-importer.cmd') },
    hasScript('diagnose-importer.cmd') && { label: '加速器网络诊断', click: () => runScript('diagnose-importer.cmd') },
    { type: 'separator' },
    isLocalBuild
      ? { label: '打开维护说明', click: () => shell.openPath(path.join(ROOT_PATH, 'MAINTENANCE.md')) }
      : { label: '使用说明（GitHub）', click: () => shell.openExternal(`https://github.com/${RELEASES_REPO}/blob/maintenance/README.zh-CN.md`) },
    { label: '打开程序文件夹', click: () => shell.openPath(ROOT_PATH) }
  ].filter(Boolean)
};

// Match build.appId
app.setAppUserModelId("fribbelse7optimizer");
app.setAsDefaultProtocolClient('fribbelse7optimizer');

const template = [
   {
      label: 'File',
      submenu: [
         isMac ? { role: 'close' } : { role: 'quit' }
      ]
   },

   {
      label: 'View',
      submenu: [
         {
            role: 'toggledevtools'
         },
         {
            type: 'separator'
         },
         {
            role: 'reload'
         },
         {
            role: 'forcereload'
         },
         {
            type: 'separator'
         },
         {
            role: 'resetzoom'
         },
         {
            role: 'zoomin'
         },
         {
            role: 'zoomout'
         },
         {
            type: 'separator'
         },
         {
            role: 'togglefullscreen'
         }
      ]
   },
   {
      role: 'window',
      submenu: [
         {
            role: 'minimize'
         },
         {
            role: 'close'
         }
      ]
   },

   {
      role: 'help',
      submenu: [
        {
          label: 'Learn More',
          click: async () => {
            const { shell } = require('electron')
            await shell.openExternal('https://github.com/fribbels/Fribbels-Epic-7-Optimizer')
          }
        }
      ]
   }
]

if (isLocalBuild || app.isPackaged) {
  // Before Help
  template.splice(template.length - 1, 0, toolsMenu);
}
const menu = Menu.buildFromTemplate(template)
Menu.setApplicationMenu(menu)

export default class AppUpdater {
  constructor() {
    log.transports.file.level = 'info';
    autoUpdater.logger = log;
    autoUpdater.allowDowngrade = false;
    autoUpdater.checkForUpdatesAndNotify();
  }
}

console.log("main.dev.ts");

let mainWindow = null;

if (process.env.NODE_ENV === 'production') {
  const sourceMapSupport = require('source-map-support');
  sourceMapSupport.install();
}

if (
  process.env.NODE_ENV === 'development' ||
  process.env.DEBUG_PROD === 'true'
) {
  require('electron-debug')();
}

const installExtensions = async () => {
  const installer = require('electron-devtools-installer');
  const forceDownload = !!process.env.UPGRADE_EXTENSIONS;
  const extensions = ['REACT_DEVELOPER_TOOLS', 'REDUX_DEVTOOLS'];

  return Promise.all(
    extensions.map((name) => installer.default(installer[name], forceDownload))
  ).catch(console.log);
};

const createWindow = async () => {
  if (
    process.env.NODE_ENV === 'development' ||
    process.env.DEBUG_PROD === 'true'
  ) {
    await installExtensions();
  }

  const RESOURCES_PATH = app.isPackaged
    ? path.join(process.resourcesPath, 'resources')
    : path.join(__dirname, '../resources');

  const getAssetPath = (paths) => {
    return path.join(RESOURCES_PATH, paths);
  };

  mainWindow = new BrowserWindow({
    show: false,
    width: 1400,
    height: 1000,
    title: `Fribbels E7 Optimizer v${appVersion}`,
    icon: getAssetPath('icon.png'),
    webPreferences:
      (process.env.NODE_ENV === 'development' || process.env.E2E_BUILD === 'true') && process.env.ERB_SECURE !== 'true' ?
      {
        nodeIntegration: true,
        enableRemoteModule: true,
        contextIsolation: false
      } :
      {
        preload: path.join(__dirname, 'dist/renderer.prod.js'),
        nodeIntegration: true,
        enableRemoteModule: true,
        contextIsolation: false
      },
  });

  // app.html has no <title>; keep the window title above instead of the default "Electron"
  mainWindow.on('page-title-updated', (e) => e.preventDefault());

  mainWindow.loadURL(`file://${__dirname}/app.html`);
  // mainWindow.webContents.openDevTools();


  remoteMain.initialize();
  require('@electron/remote/main').enable(mainWindow.webContents)

  // @TODO: Use 'ready-to-show' event
  //        https://github.com/electron/electron/blob/master/docs/api/browser-window.md#using-ready-to-show-event
  mainWindow.webContents.on('did-finish-load', () => {
    if (!mainWindow) {
      throw new Error('"mainWindow" is not defined');
    }
    if (process.env.START_MINIMIZED) {
      mainWindow.minimize();
    } else {
      mainWindow.show();
      mainWindow.focus();
    }
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  mainWindow.on('resize', () => {
    mainWindow.webContents.send('resize');
  });

  mainWindow.on('resized', () => {
    mainWindow.webContents.send('resized');
  });

  mainWindow.on('close', (e) => {
    if (!closed) {
      e.preventDefault();
      mainWindow.webContents.send('app-close');
    }
  });

  ipcMain.on('closed', _ => {
    closed = true;
    if (process.platform !== 'darwin') {
      app.quit();
    }
  });



  // const menuBuilder = new MenuBuilder(mainWindow);
  // menuBuilder.buildMenu();

  // The official auto-updaters (electron-updater, update-electron-app) are off: they would replace this maintained
  // copy with the official release. Updates go through checkForUpdates() instead.
};

/**
 * Add event listeners...
 */

app.on('window-all-closed', () => {
  // Respect the OSX convention of having the application in memory even
  // after all windows have been closed
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

if (process.env.E2E_BUILD === 'true') {
  // eslint-disable-next-line promise/catch-or-return
  app.whenReady().then(createWindow);
} else {
  app.on('ready', createWindow);
}

app.on('activate', () => {
  // On macOS it's common to re-create a window in the app when the
  // dock icon is clicked and there are no other windows open.
  if (mainWindow === null) createWindow();
});

ipcMain.on('app_version', (event) => {
  event.sender.send('app_version', { version: app.getVersion() });
});


ipcMain.on('test', async (event) => {
  const updates = await autoUpdater.checkForUpdates()
  console.log("TEST UPDATES")
  console.log(updates)
  event.sender.send('test', JSON.stringify(updates));
});

ipcMain.on('check', async (event) => {
  // Information tab's update button: this copy's own update flow instead of the official releases
  await checkForUpdates();
});

ipcMain.on('restart_app', () => {
  autoUpdater.quitAndInstall();
});

autoUpdater.on('update-available', (data) => {
  mainWindow.webContents.send('update_available');
});
autoUpdater.on('update-downloaded', (data) => {
  console.log("DOWNLOADED");
  console.log(data);
  mainWindow.webContents.send('update_downloaded', data);
});
autoUpdater.on('update-not-available', () => {
  mainWindow.webContents.send('update_not_available');
});