"use strict";

const { TeaCipher } = require("./tea-cipher");

class QMCKeyDecoder {
  constructor() {
    this.saltLength = 2;
    this.zeroLength = 7;
  }

  deriveKey(rawKey) {
    const base64DecodedKey = Buffer.from(Buffer.from(rawKey).toString("ascii"), "base64");
    if (base64DecodedKey.length < 16) throw new Error("keyLengthTooShort");

    const simpleKey = this.simpleMakeKey(106, 8);
    const teaKey = Buffer.alloc(16);
    for (let index = 0; index < 8; index += 1) {
      teaKey[index << 1] = simpleKey[index];
      teaKey[(index << 1) + 1] = base64DecodedKey[index];
    }

    const subBuffer = this.decryptTencentTea(base64DecodedKey.subarray(8), teaKey);
    return Buffer.concat([base64DecodedKey.subarray(0, 8), subBuffer]);
  }

  simpleMakeKey(seed, length) {
    const result = Buffer.alloc(length);
    for (let index = 0; index < length; index += 1) {
      result[index] = Math.trunc(Math.abs(Math.tan(seed + index * 0.1)) * 100.0) & 0xff;
    }
    return result;
  }

  decryptTencentTea(inBuffer, key) {
    const input = Buffer.from(inBuffer);
    if (input.length % 8 !== 0) throw new Error("inBufferSizeInvalidWithBlockSize");
    if (input.length < 16) throw new Error("inBufferSizeToSmall");

    const teaCipher = new TeaCipher(key, 32);
    let tempBuffer = Buffer.from(teaCipher.decrypt(input.subarray(0, 8)));
    const paddingLength = tempBuffer[0] & 0x7;
    const outputLength = input.length - 1 - paddingLength - this.saltLength - this.zeroLength;
    if (paddingLength + this.saltLength !== 8) throw new Error("invalidPaddingLength");
    if (outputLength < 0) throw new Error("outputLengthInvalid");

    const outputBuffer = Buffer.alloc(outputLength);
    let ivPrevious = Buffer.alloc(8);
    let ivCurrent = Buffer.from(input.subarray(0, 8));
    let inputPosition = 8;
    let tempIndex = 1 + paddingLength;

    const cryptBlock = () => {
      ivPrevious = ivCurrent;
      ivCurrent = Buffer.from(input.subarray(inputPosition, inputPosition + 8));
      for (let j = 0; j < 8; j += 1) tempBuffer[j] ^= ivCurrent[j];
      tempBuffer = Buffer.from(teaCipher.decrypt(tempBuffer));
      inputPosition += 8;
      tempIndex = 0;
    };

    let saltIndex = 1;
    while (saltIndex <= this.saltLength) {
      if (tempIndex < 8) {
        tempIndex += 1;
        saltIndex += 1;
      } else {
        cryptBlock();
      }
    }

    let outputPosition = 0;
    while (outputPosition < outputLength) {
      if (tempIndex < 8) {
        outputBuffer[outputPosition] = tempBuffer[tempIndex] ^ ivPrevious[tempIndex];
        outputPosition += 1;
        tempIndex += 1;
      } else {
        cryptBlock();
      }
    }

    for (let i = 1; i <= this.zeroLength; i += 1) {
      if (tempBuffer[tempIndex] !== ivPrevious[tempIndex]) throw new Error("zeroCheckFailed");
      tempIndex += 1;
      if (tempIndex === 8 && i < this.zeroLength) cryptBlock();
    }
    return outputBuffer;
  }
}

module.exports = { QMCKeyDecoder };
