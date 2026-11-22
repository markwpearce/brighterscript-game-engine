'use strict';
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const JSZip = require('jszip');

function tmpDir() {
    return fs.mkdtempSync(path.join(os.tmpdir(), 'bge-standalone-'));
}

// A minimal 1x1 PNG header is enough for size checks; width/height are big-endian at bytes 16..23.
function fakePng(width, height) {
    const buf = Buffer.alloc(33);
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).copy(buf, 0);
    buf.writeUInt32BE(13, 8);
    buf.write('IHDR', 12, 'ascii');
    buf.writeUInt32BE(width, 16);
    buf.writeUInt32BE(height, 20);
    return buf;
}

async function makeGameZip(manifestText, extraFiles = {}) {
    const zip = new JSZip();
    if (manifestText !== null) {
        zip.file('manifest', manifestText);
    }
    zip.file('source/main.brs', 'sub main()\nend sub\n');
    for (const [name, data] of Object.entries(extraFiles)) {
        zip.file(name, data);
    }
    return zip.generateAsync({ type: 'nodebuffer' });
}

module.exports = { tmpDir, fakePng, makeGameZip };
