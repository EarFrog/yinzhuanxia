"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { encryptedExtensions, privateKey256, extensionOf } = require("./constants");
const { QMCKeyDecoder } = require("./qmc-key-decoder");
const { QMStaticCipher, QMMapCipher, QMRC4Cipher } = require("./qmc-cipher");

function isValidAudioHeader(data, fileExtension) {
  if (!data || data.length === 0) return false;
  const head = data.subarray(0, 16);
  switch (fileExtension) {
    case "flac":
      return head.subarray(0, 4).toString("ascii") === "fLaC";
    case "ogg":
      return head.subarray(0, 4).toString("ascii") === "OggS";
    case "mp3":
      return head.subarray(0, 3).toString("ascii") === "ID3" || (head.length >= 2 && head[0] === 0xff && (head[1] & 0xe0) === 0xe0);
    case "m4a":
      return head.length >= 12 && head.subarray(4, 8).toString("ascii") === "ftyp";
    case "wav":
      return head.subarray(0, 4).toString("ascii") === "RIFF";
    default:
      return true;
  }
}

class QMDecoder {
  constructor(originFilePath) {
    this.originFilePath = originFilePath;
    this.fileBuffer = fs.readFileSync(originFilePath);
    this.originFileLength = this.fileBuffer.length;
    this.encryptedAudioLength = this.originFileLength;
    this.realAudioSize = 0;
    this.cipher = null;
    this.searchKey();
  }

  decryptAudioData() {
    const ext = extensionOf(this.originFilePath);
    const mapped = encryptedExtensions[ext];
    if (!mapped || !this.cipher) throw new Error(`不支持的 QMC 扩展名：.${ext}`);
    const audioData = this.fileBuffer.subarray(0, this.realAudioSize);
    const decoded = this.cipher.decrypt(audioData, 0);
    if (!isValidAudioHeader(decoded, mapped.ext)) {
      throw new Error("无法解密：当前文件可能需要 ekey，或此加密版本暂不支持。");
    }
    return { data: decoded, fileExtension: mapped.ext };
  }

  searchKey() {
    this.encryptedAudioLength = this.detectEncryptedAudioLength();
    if (this.encryptedAudioLength < 4) throw new Error("文件太小，无法读取 key。");
    const lastFourBytes = this.fileBuffer.subarray(this.encryptedAudioLength - 4, this.encryptedAudioLength);

    if (lastFourBytes.toString("utf8") === "QTag") {
      if (this.originFileLength < 8) throw new Error("无法读取 QTag key 长度。");
      const keySize = this.fileBuffer.readUInt32BE(this.originFileLength - 8);
      this.realAudioSize = this.originFileLength - keySize - 8;
      if (this.realAudioSize < 0) throw new Error("QTag key 长度异常。");
      const rawKey = this.fileBuffer.subarray(this.realAudioSize, this.realAudioSize + keySize);
      const keyEndIndex = rawKey.indexOf(0x2c);
      if (keyEndIndex < 0) throw new Error("无法定位 QTag key 结束位置。");
      this.setCipher(rawKey.subarray(0, keyEndIndex));
      return;
    }

    const keySize = lastFourBytes.readUInt32LE(0);
    if (keySize < 0x300) {
      this.realAudioSize = this.encryptedAudioLength - keySize - 4;
      if (this.realAudioSize < 0) throw new Error("key 长度异常。");
      const rawKey = this.fileBuffer.subarray(this.realAudioSize, this.realAudioSize + keySize);
      this.setCipher(rawKey);
    } else {
      this.realAudioSize = this.encryptedAudioLength;
      this.cipher = new QMStaticCipher(privateKey256);
    }
  }

  setCipher(keyBuffer) {
    const keyDecoder = new QMCKeyDecoder();
    const decodedKey = keyDecoder.deriveKey(keyBuffer);
    this.cipher = decodedKey.length > 300 ? new QMRC4Cipher(decodedKey) : new QMMapCipher(decodedKey);
  }

  detectEncryptedAudioLength() {
    if (this.originFileLength < 16) return this.originFileLength;
    const tailMagic = this.fileBuffer.subarray(this.originFileLength - 8).toString("utf8");
    if (tailMagic !== "musicex\0") return this.originFileLength;
    const trailerSize = this.fileBuffer.readUInt32LE(this.originFileLength - 16);
    if (trailerSize <= 0 || trailerSize >= this.originFileLength) return this.originFileLength;
    return this.originFileLength - trailerSize;
  }
}

function baseNameWithoutExtension(filePath) {
  return path.basename(filePath, path.extname(filePath));
}

module.exports = { QMDecoder, baseNameWithoutExtension, isValidAudioHeader };
