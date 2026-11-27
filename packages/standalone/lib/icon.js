'use strict';
const sharp = require('sharp');

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const ICON_SIZE = 512;

function pngSize(buf) {
    if (!Buffer.isBuffer(buf) || buf.length < 24 || !buf.subarray(0, 8).equals(PNG_SIGNATURE)) {
        return null;
    }
    return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
}

// electron-builder needs a square icon of at least 512x512 for mac/linux.
function isUsableIcon(buf) {
    const size = pngSize(buf);
    return size !== null && size.width >= ICON_SIZE && size.width === size.height;
}

// Roku channel icons are small and wide (e.g. 336x210): scale to fit, keep the aspect,
// and pad with transparency so the dock/taskbar shows a wide icon, not black bars.
function letterboxIcon(buf) {
    return sharp(buf)
        .resize(ICON_SIZE, ICON_SIZE, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
        .png()
        .toBuffer();
}

module.exports = { pngSize, isUsableIcon, letterboxIcon, ICON_SIZE };
