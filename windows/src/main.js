"use strict";

const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const { app, BrowserWindow, dialog, ipcMain, shell } = require("electron");
const { convertOne, findFFmpeg } = require("./core/transcoder");
const { extensionOf, isSupportedExtension, displayAudioFormat, formatBreakdown, outputFormats } = require("./core/constants");
const { getDictionary, resolveLanguage } = require("./core/i18n");

let mainWindow;
let preferences = {
  language: "system",
  outputDirectory: path.join(app.getPath("music"), "音转匣 输出"),
  outputFormat: "original"
};

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1120,
    height: 760,
    minWidth: 880,
    minHeight: 620,
    title: "音转匣",
    backgroundColor: "#f6f4ee",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false
    }
  });
  mainWindow.loadFile(path.join(__dirname, "renderer", "index.html"));
}

app.whenReady().then(() => {
  createWindow();
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});

function walkSupportedFiles(entryPath, results = []) {
  let stat;
  try {
    stat = fs.statSync(entryPath);
  } catch (_) {
    return results;
  }

  if (stat.isDirectory()) {
    let children;
    try {
      children = fs.readdirSync(entryPath);
    } catch (_) {
      return results;
    }
    for (const child of children) {
      walkSupportedFiles(path.join(entryPath, child), results);
    }
  } else if (stat.isFile() && isSupportedExtension(extensionOf(entryPath))) {
    results.push(entryPath);
  }
  return results;
}

function fileSummaries(paths) {
  return paths.map((filePath) => ({
    path: filePath,
    name: path.basename(filePath),
    format: displayAudioFormat(extensionOf(filePath)),
    status: "waiting",
    output: "",
    error: ""
  }));
}

ipcMain.handle("app:init", () => {
  const language = resolveLanguage(preferences.language, app.getLocale());
  return {
    preferences,
    language,
    dictionary: getDictionary(preferences.language, app.getLocale()),
    outputFormats,
    ffmpegAvailable: Boolean(findFFmpeg())
  };
});

ipcMain.handle("app:setPreferences", (_event, next) => {
  preferences = { ...preferences, ...next };
  if (!outputFormats.includes(preferences.outputFormat)) preferences.outputFormat = "original";
  return {
    preferences,
    language: resolveLanguage(preferences.language, app.getLocale()),
    dictionary: getDictionary(preferences.language, app.getLocale())
  };
});

ipcMain.handle("files:choose", async () => {
  const response = await dialog.showOpenDialog(mainWindow, {
    properties: ["openFile", "multiSelections"],
    filters: [{ name: "Audio", extensions: ["mp3", "flac", "m4a", "aac", "ogg", "opus", "wav", "aif", "aiff", "aifc", "caf", "mgg", "mgg1", "mflac", "mflac0", "qmcflac", "qmcogg", "qmc0", "qmc2", "qmc3", "bkcmp3", "bkcflac", "tkm"] }]
  });
  if (response.canceled) return [];
  return fileSummaries(response.filePaths.filter((filePath) => isSupportedExtension(extensionOf(filePath))));
});

ipcMain.handle("folder:scan", async () => {
  const response = await dialog.showOpenDialog(mainWindow, {
    properties: ["openDirectory"]
  });
  if (response.canceled || response.filePaths.length === 0) return [];
  return fileSummaries(walkSupportedFiles(response.filePaths[0]));
});

ipcMain.handle("paths:add", (_event, paths) => {
  const files = [];
  for (const entryPath of paths || []) {
    walkSupportedFiles(entryPath, files);
  }
  return fileSummaries(files);
});

ipcMain.handle("output:choose", async () => {
  const response = await dialog.showOpenDialog(mainWindow, {
    properties: ["openDirectory", "createDirectory"],
    defaultPath: preferences.outputDirectory
  });
  if (response.canceled || response.filePaths.length === 0) return preferences.outputDirectory;
  preferences.outputDirectory = response.filePaths[0];
  return preferences.outputDirectory;
});

ipcMain.handle("files:summary", (_event, paths) => ({
  count: (paths || []).length,
  breakdown: formatBreakdown(paths || [])
}));

ipcMain.handle("file:show", (_event, filePath) => {
  if (filePath) shell.showItemInFolder(filePath);
});

ipcMain.handle("convert:start", async (event, payload) => {
  const files = payload.files || [];
  const outputDirectory = payload.outputDirectory || preferences.outputDirectory || path.join(os.homedir(), "Music", "音转匣 输出");
  const outputFormat = outputFormats.includes(payload.outputFormat) ? payload.outputFormat : "original";
  fs.mkdirSync(outputDirectory, { recursive: true });

  const results = [];
  for (let index = 0; index < files.length; index += 1) {
    const file = files[index];
    event.sender.send("convert:update", { index, status: "converting", output: "", error: "" });
    try {
      const output = await convertOne(file.path, outputDirectory, outputFormat);
      const result = { ...file, status: "success", output, error: "" };
      results.push(result);
      event.sender.send("convert:update", { index, status: "success", output, error: "" });
    } catch (error) {
      const result = { ...file, status: "failed", output: "", error: error.message || String(error) };
      results.push(result);
      event.sender.send("convert:update", { index, status: "failed", output: "", error: result.error });
    }
  }
  return results;
});
