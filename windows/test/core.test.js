"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const { formatBreakdown, displayAudioFormat, isSupportedExtension } = require("../src/core/constants");
const { TeaCipher } = require("../src/core/tea-cipher");
const { QMStaticCipher } = require("../src/core/qmc-cipher");
const { uniqueOutputPath } = require("../src/core/transcoder");

test("supported extensions include plain and encrypted audio", () => {
  assert.equal(isSupportedExtension("mp3"), true);
  assert.equal(isSupportedExtension("flac"), true);
  assert.equal(isSupportedExtension("mflac"), true);
  assert.equal(isSupportedExtension("mgg"), true);
  assert.equal(isSupportedExtension("txt"), false);
});

test("format display groups variants", () => {
  assert.equal(displayAudioFormat("mflac"), "MFLAC->FLAC");
  assert.equal(displayAudioFormat("mgg"), "MGG->OGG");
  assert.equal(displayAudioFormat("aiff"), "AIFF");
});

test("format breakdown counts files", () => {
  const breakdown = formatBreakdown(["C:/a.mp3", "C:/b.flac", "C:/c.mflac", "C:/d.aiff", "C:/e.aif"]);
  assert.match(breakdown, /MP3 1/);
  assert.match(breakdown, /FLAC 1/);
  assert.match(breakdown, /MFLAC->FLAC 1/);
  assert.match(breakdown, /AIFF 2/);
});

test("tea decrypt handles known block", () => {
  const key = Buffer.from("00112233445566778899aabbccddeeff", "hex");
  const cipher = new TeaCipher(key, 32);
  const encrypted = Buffer.from("f7536548d0013aed", "hex");
  const decrypted = cipher.decrypt(encrypted);
  assert.equal(decrypted.toString("hex"), "4691e3161f553043");
});

test("static cipher rejects empty key", () => {
  assert.throws(() => new QMStaticCipher(Buffer.alloc(0)), /invalidKeyLength/);
});

test("unique output path appends numeric suffix", () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "yinzhuanxia-test-"));
  try {
    fs.writeFileSync(path.join(directory, "song.mp3"), "");
    assert.equal(path.basename(uniqueOutputPath(directory, "song", "mp3")), "song 2.mp3");
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
