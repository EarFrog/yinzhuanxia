"use strict";

const state = {
  files: [],
  dictionary: {},
  preferences: {}
};

const $ = (id) => document.getElementById(id);

function tr(key, replacements = {}) {
  let value = state.dictionary[key] || key;
  for (const [name, replacement] of Object.entries(replacements)) {
    value = value.replace(`{${name}}`, replacement);
  }
  return value;
}

function applyI18n() {
  document.querySelectorAll("[data-i18n]").forEach((element) => {
    const key = element.getAttribute("data-i18n");
    element.textContent = tr(key);
  });
  document.title = tr("appTitle");
  render();
}

async function setPreferences(next) {
  const response = await window.yinzhuanxia.setPreferences(next);
  state.preferences = response.preferences;
  state.dictionary = response.dictionary;
  applyI18n();
}

function mergeFiles(incoming) {
  const seen = new Set(state.files.map((file) => file.path));
  for (const file of incoming) {
    if (!seen.has(file.path)) {
      state.files.push(file);
      seen.add(file.path);
    }
  }
  render();
}

async function updateSummary() {
  if (state.files.length === 0) {
    $("summaryText").textContent = tr("defaultOutput");
    return;
  }
  const summary = await window.yinzhuanxia.summary(state.files.map((file) => file.path));
  $("summaryText").textContent = `${tr("items", { count: summary.count })}，${tr("breakdown", { breakdown: summary.breakdown })}`;
}

function statusText(status) {
  return tr(status);
}

function render() {
  $("formatSelect").value = state.preferences.outputFormat || "original";
  $("languageSelect").value = state.preferences.language || "system";
  $("outputInput").value = state.preferences.outputDirectory || "";

  const hasFiles = state.files.length > 0;
  $("emptyState").hidden = hasFiles;
  $("fileTable").hidden = !hasFiles;
  $("startButton").disabled = !hasFiles;

  const rows = $("fileRows");
  rows.textContent = "";
  state.files.forEach((file) => {
    const row = document.createElement("tr");
    const name = document.createElement("td");
    name.textContent = file.name;
    name.title = file.path;

    const format = document.createElement("td");
    format.textContent = file.format;

    const status = document.createElement("td");
    status.textContent = file.error ? `${statusText(file.status)}：${file.error}` : statusText(file.status);
    status.className = `status-${file.status}`;
    status.title = file.error || status.textContent;

    const output = document.createElement("td");
    if (file.output) {
      const link = document.createElement("a");
      link.textContent = file.output.split(/[\\/]/).pop();
      link.title = file.output;
      link.className = "output-link";
      link.addEventListener("click", () => window.yinzhuanxia.showFile(file.output));
      output.appendChild(link);
    }

    row.append(name, format, status, output);
    rows.appendChild(row);
  });
  updateSummary();
}

async function boot() {
  const initial = await window.yinzhuanxia.init();
  state.preferences = initial.preferences;
  state.dictionary = initial.dictionary;
  $("ffmpegText").textContent = initial.ffmpegAvailable ? "ffmpeg OK" : "ffmpeg 未找到";
  applyI18n();

  $("addFilesButton").addEventListener("click", async () => mergeFiles(await window.yinzhuanxia.chooseFiles()));
  $("scanFolderButton").addEventListener("click", async () => mergeFiles(await window.yinzhuanxia.scanFolder()));
  $("chooseOutputButton").addEventListener("click", async () => {
    const outputDirectory = await window.yinzhuanxia.chooseOutput();
    await setPreferences({ outputDirectory });
  });
  $("clearButton").addEventListener("click", () => {
    state.files = [];
    render();
  });
  $("formatSelect").addEventListener("change", (event) => setPreferences({ outputFormat: event.target.value }));
  $("languageSelect").addEventListener("change", (event) => setPreferences({ language: event.target.value }));
  $("startButton").addEventListener("click", async () => {
    $("startButton").disabled = true;
    state.files = await window.yinzhuanxia.startConvert({
      files: state.files,
      outputDirectory: state.preferences.outputDirectory,
      outputFormat: state.preferences.outputFormat
    });
    $("startButton").disabled = state.files.length === 0;
    render();
  });

  window.yinzhuanxia.onConvertUpdate((update) => {
    state.files[update.index] = { ...state.files[update.index], ...update };
    render();
  });

  const dropZone = $("dropZone");
  dropZone.addEventListener("dragover", (event) => {
    event.preventDefault();
    dropZone.classList.add("dragging");
  });
  dropZone.addEventListener("dragleave", () => dropZone.classList.remove("dragging"));
  dropZone.addEventListener("drop", async (event) => {
    event.preventDefault();
    dropZone.classList.remove("dragging");
    const paths = [...event.dataTransfer.files].map((file) => file.path).filter(Boolean);
    mergeFiles(await window.yinzhuanxia.addPaths(paths));
  });
}

boot();
