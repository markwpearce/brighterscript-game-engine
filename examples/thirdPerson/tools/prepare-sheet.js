// Prepares a Flare 8-direction sprite sheet for the game: strips the baked-in shadow
// (unless --keep-shadow), keeps only the frame columns the game uses, trims cells to a shared bounding box and
// writes an 8-bit PNG. Prints the new cell size and the feet anchor. Uses headless Chrome
// (set CHROME if it isn't in the default place).
//   node tools/prepare-sheet.js <source.png> <out.png> <firstFrame> <lastFrame> [columns] [--keep-shadow]
const { execFileSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const url = require("url");

const args = process.argv.slice(2);
const keepShadow = args.includes("--keep-shadow");
const [source, out, first, last, columns] = args.filter((a) => a !== "--keep-shadow");
if (!source || !out || first === undefined || last === undefined) {
  console.error("usage: node tools/prepare-sheet.js <source.png> <out.png> <firstFrame> <lastFrame> [columns] [--keep-shadow]");
  process.exit(1);
}

const defaultChrome = {
  darwin: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  win32: "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
  linux: "google-chrome",
}[process.platform];
const chrome = process.env.CHROME || defaultChrome;

const page = new URL(url.pathToFileURL(path.join(__dirname, "prepare-sheet.html")).href);
page.searchParams.set("src", url.pathToFileURL(path.resolve(source)).href);
page.searchParams.set("first", first);
page.searchParams.set("last", last);
if (keepShadow) {
  page.searchParams.set("keepShadow", "1");
}
if (columns) {
  page.searchParams.set("columns", columns);
}

const dom = execFileSync(chrome, ["--headless", "--disable-gpu", "--allow-file-access-from-files", "--virtual-time-budget=20000", "--dump-dom", page.href], {
  encoding: "utf8",
  maxBuffer: 256 * 1024 * 1024,
  stdio: ["ignore", "pipe", "ignore"],
});
const match = dom.match(/<pre id="out">([^\n]*)\ndata:image\/png;base64,([A-Za-z0-9+/=]+)/);
if (!match) {
  throw new Error("No sheet found in Chrome's output");
}
fs.mkdirSync(path.dirname(path.resolve(out)), { recursive: true });
fs.writeFileSync(out, Buffer.from(match[2], "base64"));
console.log(`Wrote ${out}`);
console.log(match[1]);
