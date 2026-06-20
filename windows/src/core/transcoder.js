"use strict";

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawn } = require("node:child_process");
const { encryptedExtensions, extensionOf } = require("./constants");
const { QMDecoder, baseNameWithoutExtension } = require("./qm-decoder");

function ensureDirectory(directory) {
  fs.mkdirSync(directory, { recursive: true });
}

function normalizedAudioExtension(ext) {
  return ["aif", "aiff", "aifc"].includes(ext.toLowerCase()) ? "aiff" : ext.toLowerCase();
}

function uniqueOutputPath(directory, baseName, ext) {
  let candidate = path.join(directory, `${baseName}.${ext}`);
  if (!fs.existsSync(candidate)) return candidate;
  let index = 2;
  while (true) {
    candidate = path.join(directory, `${baseName} ${index}.${ext}`);
    if (!fs.existsSync(candidate)) return candidate;
    index += 1;
  }
}

function findFFmpeg() {
  const candidates = [];
  if (process.resourcesPath) {
    candidates.push(path.join(process.resourcesPath, "bin", process.platform === "win32" ? "ffmpeg.exe" : "ffmpeg"));
  }
  try {
    candidates.push(require("@ffmpeg-installer/ffmpeg").path);
  } catch (_) {
    // Optional during source checkout.
  }
  candidates.push(path.resolve(__dirname, "../../../../Vendor/ffmpeg/ffmpeg"));
  candidates.push("ffmpeg");
  return candidates.find((candidate) => {
    if (candidate === "ffmpeg") return true;
    try {
      fs.accessSync(candidate, fs.constants.X_OK);
      return true;
    } catch (_) {
      return false;
    }
  }) || null;
}

function runFFmpeg(inputPath, outputPath, format) {
  const ffmpeg = findFFmpeg();
  if (!ffmpeg) throw new Error(`找不到 ffmpeg，无法转换为 ${format.toUpperCase()}。`);

  const args = ["-y", "-i", inputPath];
  switch (format) {
    case "mp3":
      args.push("-codec:a", "libmp3lame", "-q:a", "2");
      break;
    case "flac":
      args.push("-codec:a", "flac");
      break;
    case "m4a":
      args.push("-codec:a", "aac", "-b:a", "256k");
      break;
    case "ogg":
      args.push("-codec:a", "libvorbis", "-q:a", "6");
      break;
    case "wav":
      args.push("-codec:a", "pcm_s16le");
      break;
    default:
      throw new Error(`不支持的输出格式：${format}`);
  }
  args.push(outputPath);

  return new Promise((resolve, reject) => {
    const child = spawn(ffmpeg, args, { windowsHide: true });
    let stderr = "";
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(stderr.trim() || `ffmpeg 退出码：${code}`));
    });
  });
}

async function writePlainAudio(inputPath, outputDirectory, format) {
  ensureDirectory(outputDirectory);
  const originalExt = extensionOf(inputPath);
  const inputExt = normalizedAudioExtension(originalExt);
  const targetExt = format === "original" ? originalExt : format;
  const outputPath = uniqueOutputPath(outputDirectory, baseNameWithoutExtension(inputPath), targetExt);
  if (format === "original" || targetExt === inputExt) {
    fs.copyFileSync(inputPath, outputPath);
    return outputPath;
  }
  await runFFmpeg(inputPath, outputPath, format);
  return outputPath;
}

async function writeQMC(inputPath, outputDirectory, format) {
  ensureDirectory(outputDirectory);
  const decoder = new QMDecoder(inputPath);
  const decrypted = decoder.decryptAudioData();
  const targetExt = format === "original" ? decrypted.fileExtension : format;
  const outputPath = uniqueOutputPath(outputDirectory, baseNameWithoutExtension(inputPath), targetExt);

  if (format === "original" || targetExt === decrypted.fileExtension) {
    fs.writeFileSync(outputPath, decrypted.data);
    return outputPath;
  }

  const tempDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "yinzhuanxia-"));
  const tempInput = path.join(tempDirectory, `${baseNameWithoutExtension(inputPath)}.${decrypted.fileExtension}`);
  try {
    fs.writeFileSync(tempInput, decrypted.data);
    await runFFmpeg(tempInput, outputPath, format);
    return outputPath;
  } finally {
    fs.rmSync(tempDirectory, { recursive: true, force: true });
  }
}

async function convertOne(inputPath, outputDirectory, format) {
  const ext = extensionOf(inputPath);
  if (encryptedExtensions[ext]) return writeQMC(inputPath, outputDirectory, format);
  return writePlainAudio(inputPath, outputDirectory, format);
}

module.exports = { convertOne, findFFmpeg, uniqueOutputPath };
