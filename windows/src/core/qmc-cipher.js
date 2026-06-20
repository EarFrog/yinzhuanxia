"use strict";

class QMStaticCipher {
  constructor(originKey) {
    this.key = Buffer.from(originKey);
    if (this.key.length === 0) throw new Error("invalidKeyLength");
  }

  getMask(offset) {
    const temp = offset > 0x7fff ? offset % 0x7fff : offset;
    return this.key[((temp * temp + 27) & 0xff)];
  }

  decrypt(data, offset = 0) {
    const result = Buffer.from(data);
    for (let index = 0; index < result.length; index += 1) {
      result[index] ^= this.getMask(offset + index);
    }
    return result;
  }
}

class QMMapCipher {
  constructor(originKey) {
    this.key = Buffer.from(originKey);
    if (this.key.length === 0) throw new Error("invalidKeyLength");
  }

  getMask(offset) {
    const temp = offset > 0x7fff ? offset % 0x7fff : offset;
    const index = (temp * temp + 71214) & 0xff;
    const rotate = ((index & 0x7) + 4) % 8;
    const value = this.key[index];
    return (((value << rotate) | (value >>> rotate)) & 0xff);
  }

  decrypt(data, offset = 0) {
    const result = Buffer.from(data);
    for (let index = 0; index < result.length; index += 1) {
      result[index] ^= this.getMask(offset + index);
    }
    return result;
  }
}

class QMRC4Cipher {
  constructor(originKey) {
    this.firstSegmentSize = 0x80;
    this.segmentSize = 0x1400;
    this.originKey = Buffer.from(originKey);
    if (this.originKey.length === 0) throw new Error("invalidKeyLength");
    this.originKeyLength = this.originKey.length;

    const seedBox = Buffer.alloc(this.originKeyLength);
    for (let index = 0; index < this.originKeyLength; index += 1) seedBox[index] = index & 0xff;
    let tempIndex = 0;
    for (let index = 0; index < this.originKeyLength; index += 1) {
      tempIndex = (seedBox[index] + tempIndex + this.originKey[index % this.originKeyLength]) % this.originKeyLength;
      const temp = seedBox[index];
      seedBox[index] = seedBox[tempIndex];
      seedBox[tempIndex] = temp;
    }
    this.seedBox = seedBox;

    this.hashValue = 1;
    for (let index = 0; index < this.originKeyLength; index += 1) {
      const value = this.originKey[index];
      if (value === 0) continue;
      const nextHash = Math.imul(this.hashValue, value) >>> 0;
      if (nextHash === 0 || nextHash <= this.hashValue) break;
      this.hashValue = nextHash;
    }
  }

  getSegmentKey(index) {
    const seed = this.originKey[index % this.originKeyLength];
    const resultValue = Math.floor((this.hashValue / ((index + 1) * seed)) * 100);
    return resultValue % this.originKeyLength;
  }

  decrypt(data, offset = 0) {
    const result = Buffer.from(data);
    let toProcess = result.length;
    let processed = 0;
    let newOffset = offset;

    const postProcessed = (length) => {
      toProcess -= length;
      processed += length;
      newOffset += length;
      return toProcess === 0;
    };

    if (newOffset < this.firstSegmentSize) {
      const processLength = Math.min(result.length, this.firstSegmentSize - newOffset);
      const temp = Buffer.from(result.subarray(0, processLength));
      this.encodeFirstSegment(temp, newOffset);
      temp.copy(result, 0);
      if (postProcessed(processLength)) return result;
    }

    if (newOffset % this.segmentSize !== 0) {
      const processLength = Math.min(this.segmentSize - (newOffset % this.segmentSize), toProcess);
      const temp = Buffer.from(result.subarray(processed, processed + processLength));
      this.encodeAllSegment(temp, newOffset);
      temp.copy(result, processed);
      if (postProcessed(processLength)) return result;
    }

    while (toProcess > this.segmentSize) {
      const temp = Buffer.from(result.subarray(processed, processed + this.segmentSize));
      this.encodeAllSegment(temp, newOffset);
      temp.copy(result, processed);
      postProcessed(this.segmentSize);
    }

    if (toProcess > 0) {
      const temp = Buffer.from(result.subarray(processed));
      this.encodeAllSegment(temp, newOffset);
      temp.copy(result, processed);
    }
    return result;
  }

  encodeFirstSegment(data, offset) {
    for (let index = 0; index < data.length; index += 1) {
      data[index] ^= this.originKey[this.getSegmentKey(index + offset)];
    }
  }

  encodeAllSegment(data, offset) {
    const seedBox = Buffer.from(this.seedBox);
    const skipLength = (offset % this.segmentSize) + this.getSegmentKey(Math.floor(offset / this.segmentSize));
    let left = 0;
    let right = 0;
    for (let index = -skipLength; index < data.length; index += 1) {
      left = (left + 1) % this.originKeyLength;
      right = (seedBox[left] + right) % this.originKeyLength;
      const temp = seedBox[right];
      seedBox[right] = seedBox[left];
      seedBox[left] = temp;
      if (index >= 0) {
        data[index] ^= seedBox[(seedBox[left] + seedBox[right]) % this.originKeyLength];
      }
    }
  }
}

module.exports = { QMStaticCipher, QMMapCipher, QMRC4Cipher };
