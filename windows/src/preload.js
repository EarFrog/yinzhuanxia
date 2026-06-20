"use strict";

const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("yinzhuanxia", {
  init: () => ipcRenderer.invoke("app:init"),
  setPreferences: (preferences) => ipcRenderer.invoke("app:setPreferences", preferences),
  chooseFiles: () => ipcRenderer.invoke("files:choose"),
  scanFolder: () => ipcRenderer.invoke("folder:scan"),
  addPaths: (paths) => ipcRenderer.invoke("paths:add", paths),
  chooseOutput: () => ipcRenderer.invoke("output:choose"),
  summary: (paths) => ipcRenderer.invoke("files:summary", paths),
  startConvert: (payload) => ipcRenderer.invoke("convert:start", payload),
  showFile: (filePath) => ipcRenderer.invoke("file:show", filePath),
  onConvertUpdate: (callback) => {
    const listener = (_event, payload) => callback(payload);
    ipcRenderer.on("convert:update", listener);
    return () => ipcRenderer.removeListener("convert:update", listener);
  }
});
