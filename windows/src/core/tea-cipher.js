"use strict";

const DELTA = 0x9e3779b9 >>> 0;

function readUInt32BE(bytes, offset) {
  return Buffer.from(bytes.subarray(offset, offset + 4)).readUInt32BE(0) >>> 0;
}

function writeUInt32BE(value, target, offset) {
  target.writeUInt32BE(value >>> 0, offset);
}

class TeaCipher {
  constructor(key, rounds = 64) {
    if (!Buffer.isBuffer(key)) key = Buffer.from(key);
    if (key.length !== 16) throw new Error("keySizeInvalid");
    if ((rounds & 1) !== 0) throw new Error("oddNumberOfRoundsSpecified");
    this.rounds = rounds >>> 0;
    this.key0 = readUInt32BE(key, 0);
    this.key1 = readUInt32BE(key, 4);
    this.key2 = readUInt32BE(key, 8);
    this.key3 = readUInt32BE(key, 12);
  }

  decrypt(src) {
    const input = Buffer.from(src);
    let v0 = readUInt32BE(input, 0);
    let v1 = readUInt32BE(input, 4);
    let sum = Math.imul(DELTA, this.rounds / 2) >>> 0;

    for (let i = 0; i < this.rounds / 2; i += 1) {
      v1 = (v1 - ((((v0 << 4) >>> 0) + this.key2 >>> 0) ^ ((v0 + sum) >>> 0) ^ (((v0 >>> 5) + this.key3) >>> 0))) >>> 0;
      v0 = (v0 - ((((v1 << 4) >>> 0) + this.key0 >>> 0) ^ ((v1 + sum) >>> 0) ^ (((v1 >>> 5) + this.key1) >>> 0))) >>> 0;
      sum = (sum - DELTA) >>> 0;
    }

    const output = Buffer.alloc(8);
    writeUInt32BE(v0, output, 0);
    writeUInt32BE(v1, output, 4);
    return output;
  }
}

module.exports = { TeaCipher };
