/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

// zip.js is loaded before this script by the Dart worker adapter. This worker
// supplies ZIP metadata and decompressed bytes; project rules and filesystem
// ownership remain in Dart. One worker serves one archive, one file at a time.
const chunkSize = 64 * 1024;
zip.configure({ useWebWorkers: false, chunkSize });

let reader;
let entries;
let acknowledgement;

class ArchiveReadError extends Error {}

class RangeReader extends zip.Reader {
  constructor(url, length) {
    super();
    this.url = url;
    this.size = length;
  }

  async readUint8Array(offset, length) {
    const result = new Uint8Array(length);
    for (let copied = 0; copied < length; copied += chunkSize) {
      const start = offset + copied;
      const end = Math.min(offset + length, start + chunkSize);
      try {
        const response = await fetch(this.url, {
          headers: { Range: `bytes=${start}-${end - 1}` },
        });
        if (response.status !== 206 ||
            response.headers.get('Content-Range') !==
              `bytes ${start}-${end - 1}/${this.size}`) {
          throw new Error('Cannot read the requested archive range.');
        }
        const bytes = new Uint8Array(await response.arrayBuffer());
        if (bytes.length !== end - start) {
          throw new Error('Incomplete archive read.');
        }
        result.set(bytes, copied);
      } catch (error) {
        throw new ArchiveReadError(error.message);
      }
    }
    return result;
  }
}

async function sendBytes(bytes) {
  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    // Transfer an owned buffer so detaching it cannot affect the ZIP codec.
    const chunk = bytes.slice(offset, offset + chunkSize);
    await new Promise((resolve, reject) => {
      acknowledgement = { resolve, reject };
      self.postMessage({ operation: 'data', bytes: chunk }, [chunk.buffer]);
    });
  }
}

self.onmessage = async ({ data }) => {
  if (data.operation === 'ack') {
    const pending = acknowledgement;
    acknowledgement = undefined;
    if (data.error) pending.reject(new Error(data.error));
    else pending.resolve();
    return;
  }
  try {
    switch (data.operation) {
      case 'open':
        reader = new zip.ZipReader(new RangeReader(data.path, data.length), {
          // Dart applies the same filename rules to native and browser ZIPs.
          filenameValidation: 'tolerant',
        });
        entries = await reader.getEntries();
        self.postMessage({
          operation: 'entries',
          entries: entries.map(entry => ({
            name: entry.filename,
            isDirectory: entry.directory,
            isSymbolicLink: entry.symlink,
            length: entry.uncompressedSize,
            crc32: entry.crc32,
          })),
        });
        break;
      case 'file':
        await entries[data.index].getData(new WritableStream({ write: sendBytes }), {
          // The shared Dart workflow checks extracted length and CRC.
          checkCrc32: false,
        });
        self.postMessage({ operation: 'done' });
        break;
      default:
        throw new Error(`Unexpected archive operation: ${data.operation}`);
    }
  } catch (error) {
    self.postMessage({
      operation: 'error',
      error: error.message,
      stack: error.stack,
      readError: error instanceof ArchiveReadError,
    });
  }
};
