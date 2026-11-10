// WebP read/write helpers for the asset build scripts, via sharp (prebuilt on Windows/macOS/Linux).
// Roku channels must stay under 4 MB zipped, so generated textures are WebP rather than PNG.

const sharp = require('sharp');

// Lossy keeps alpha lossless so sprite edges don't fringe; use lossless for pixel art and tile sheets.
const LOSSY = { quality: 90, alphaQuality: 100 };
const LOSSLESS = { lossless: true, effort: 6, exact: true };

/**
 * Encodes straight (non-premultiplied) RGBA pixels as a WebP file.
 * @param {Uint8Array|Uint8ClampedArray|Buffer} rgba width*height*4 bytes
 * @param {number} width
 * @param {number} height
 * @param {string} outPath
 * @param {{lossless?: boolean}} [options] lossy (q90) by default
 */
async function writeWebp(rgba, width, height, outPath, options = {}) {
  const raw = Buffer.from(rgba.buffer, rgba.byteOffset, rgba.byteLength);
  await sharp(raw, { raw: { width, height, channels: 4 } })
    .webp(options.lossless ? LOSSLESS : LOSSY)
    .toFile(outPath);
}

/**
 * Decodes any image sharp reads (PNG, WebP, JPEG, ...) to straight RGBA pixels.
 * @param {string} inPath
 * @returns {Promise<{data: Buffer, width: number, height: number}>}
 */
async function readRgba(inPath) {
  const { data, info } = await sharp(inPath).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  return { data, width: info.width, height: info.height };
}

module.exports = { writeWebp, readRgba };
