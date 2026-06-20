"use strict";

const state = {
  files: [],
  dictionary: {},
  preferences: {},
  inputFormats: []
};

const formatOrder = ["MP3", "FLAC", "M4A", "AAC", "OGG", "OPUS", "WAV", "AIFF", "CAF"];

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
  rebuildInputFormatSelect();
  render();
}

async function setPreferences(next) {
  const response = await window.yinzhuanxia.setPreferences(next);
  state.preferences = response.preferences;
  state.dictionary = response.dictionary;
  applyI18n();
}

function mergeFiles(incoming) {
  const filtered = filterFilesForInputFormat(incoming);
  const seen = new Set(state.files.map((file) => file.path));
  for (const file of filtered) {
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

function rebuildInputFormatSelect() {
  const select = $("inputFormatSelect");
  const selected = state.preferences.inputFormat || "all";
  select.textContent = "";
  const allOption = document.createElement("option");
  allOption.value = "all";
  allOption.textContent = tr("allFormats");
  select.appendChild(allOption);
  state.inputFormats.forEach((format) => {
    const option = document.createElement("option");
    option.value = format;
    option.textContent = format;
    select.appendChild(option);
  });
  select.value = selected;
}

function filterFilesForInputFormat(files) {
  const inputFormat = state.preferences.inputFormat || "all";
  if (inputFormat === "all") return files || [];
  return (files || []).filter((file) => file.format === inputFormat);
}

function groupedFiles(files) {
  const groups = new Map();
  files.forEach((file, index) => {
    if (!groups.has(file.format)) groups.set(file.format, []);
    groups.get(file.format).push({ file, index });
  });
  return [...groups.entries()]
    .sort(([a], [b]) => {
      const ai = formatOrder.indexOf(a);
      const bi = formatOrder.indexOf(b);
      const ax = ai === -1 ? Number.MAX_SAFE_INTEGER : ai;
      const bx = bi === -1 ? Number.MAX_SAFE_INTEGER : bi;
      return ax === bx ? a.localeCompare(b) : ax - bx;
    })
    .map(([format, entries]) => ({
      format,
      entries: entries.sort((a, b) => a.file.name.localeCompare(b.file.name))
    }));
}

function render() {
  $("formatSelect").value = state.preferences.outputFormat || "original";
  $("inputFormatSelect").value = state.preferences.inputFormat || "all";
  $("languageSelect").value = state.preferences.language || "system";
  $("outputInput").value = state.preferences.outputDirectory || "";

  const hasFiles = state.files.length > 0;
  $("emptyState").hidden = hasFiles;
  $("fileSections").hidden = !hasFiles;
  $("startButton").disabled = !hasFiles;

  const sections = $("fileSections");
  sections.textContent = "";
  groupedFiles(state.files).forEach((group) => {
    const section = document.createElement("section");
    section.className = "file-section";
    const title = document.createElement("h2");
    title.textContent = tr("groupFiles", { format: group.format, count: group.entries.length });

    const table = document.createElement("table");
    const thead = document.createElement("thead");
    const headRow = document.createElement("tr");
    ["fileName", "format", "status", "output"].forEach((key) => {
      const th = document.createElement("th");
      th.textContent = tr(key);
      headRow.appendChild(th);
    });
    thead.appendChild(headRow);
    table.appendChild(thead);

    const tbody = document.createElement("tbody");

    group.entries.forEach(({ file }) => {
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
      tbody.appendChild(row);
    });

    table.appendChild(tbody);
    section.append(title, table);
    sections.appendChild(section);
  });
  updateSummary();
}

async function boot() {
  const initial = await window.yinzhuanxia.init();
  state.preferences = initial.preferences;
  state.dictionary = initial.dictionary;
  state.inputFormats = initial.inputFormats || [];
  $("ffmpegText").textContent = initial.ffmpegAvailable ? "ffmpeg OK" : "ffmpeg 未找到";
  applyI18n();

  $("addFilesButton").addEventListener("click", async () => mergeFiles(await window.yinzhuanxia.chooseFiles()));
  $("chooseOutputButton").addEventListener("click", async () => {
    const outputDirectory = await window.yinzhuanxia.chooseOutput();
    await setPreferences({ outputDirectory });
  });
  $("clearButton").addEventListener("click", () => {
    state.files = [];
    render();
  });
  $("formatSelect").addEventListener("change", (event) => setPreferences({ outputFormat: event.target.value }));
  $("inputFormatSelect").addEventListener("change", async (event) => {
    await setPreferences({ inputFormat: event.target.value });
    state.files = filterFilesForInputFormat(state.files);
    mergeFiles(await window.yinzhuanxia.autoScanMusic());
  });
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

  window.yinzhuanxia.autoScanMusic().then(mergeFiles).catch(() => render());
}

boot();
