#!/usr/bin/env node
// Regenerates the named-color block of src/source/utils/colors.bs (BGE.Colors,
// BGE.ColorsRGB, GetColor, GetColorRGB) and its spec from the CSS named color table below.
// Usage: node scripts/generate-colors.js
const fs = require('fs');
const path = require('path');

const COLORS_FILE = path.join(__dirname, '..', 'src', 'source', 'utils', 'colors.bs');
const SPEC_FILE = path.join(__dirname, '..', 'src', 'source', 'utils', 'colors.spec.bs');
const START = "  ' <generated-colors> - edit scripts/generate-colors.js, not this block";
const END = "  ' </generated-colors>";

// CSS Color Module Level 4 named colors (transparent excluded).
const COLORS = {
  AliceBlue: 'F0F8FF', AntiqueWhite: 'FAEBD7', Aqua: '00FFFF', Aquamarine: '7FFFD4',
  Azure: 'F0FFFF', Beige: 'F5F5DC', Bisque: 'FFE4C4', Black: '000000',
  BlanchedAlmond: 'FFEBCD', Blue: '0000FF', BlueViolet: '8A2BE2', Brown: 'A52A2A',
  BurlyWood: 'DEB887', CadetBlue: '5F9EA0', Chartreuse: '7FFF00', Chocolate: 'D2691E',
  Coral: 'FF7F50', CornflowerBlue: '6495ED', Cornsilk: 'FFF8DC', Crimson: 'DC143C',
  Cyan: '00FFFF', DarkBlue: '00008B', DarkCyan: '008B8B', DarkGoldenrod: 'B8860B',
  DarkGray: 'A9A9A9', DarkGreen: '006400', DarkGrey: 'A9A9A9', DarkKhaki: 'BDB76B',
  DarkMagenta: '8B008B', DarkOliveGreen: '556B2F', DarkOrange: 'FF8C00', DarkOrchid: '9932CC',
  DarkRed: '8B0000', DarkSalmon: 'E9967A', DarkSeaGreen: '8FBC8F', DarkSlateBlue: '483D8B',
  DarkSlateGray: '2F4F4F', DarkSlateGrey: '2F4F4F', DarkTurquoise: '00CED1', DarkViolet: '9400D3',
  DeepPink: 'FF1493', DeepSkyBlue: '00BFFF', DimGray: '696969', DimGrey: '696969',
  DodgerBlue: '1E90FF', FireBrick: 'B22222', FloralWhite: 'FFFAF0', ForestGreen: '228B22',
  Fuchsia: 'FF00FF', Gainsboro: 'DCDCDC', GhostWhite: 'F8F8FF', Gold: 'FFD700',
  Goldenrod: 'DAA520', Gray: '808080', Green: '008000', GreenYellow: 'ADFF2F',
  Grey: '808080', Honeydew: 'F0FFF0', HotPink: 'FF69B4', IndianRed: 'CD5C5C',
  Indigo: '4B0082', Ivory: 'FFFFF0', Khaki: 'F0E68C', Lavender: 'E6E6FA',
  LavenderBlush: 'FFF0F5', LawnGreen: '7CFC00', LemonChiffon: 'FFFACD', LightBlue: 'ADD8E6',
  LightCoral: 'F08080', LightCyan: 'E0FFFF', LightGoldenrodYellow: 'FAFAD2', LightGray: 'D3D3D3',
  LightGreen: '90EE90', LightGrey: 'D3D3D3', LightPink: 'FFB6C1', LightSalmon: 'FFA07A',
  LightSeaGreen: '20B2AA', LightSkyBlue: '87CEFA', LightSlateGray: '778899', LightSlateGrey: '778899',
  LightSteelBlue: 'B0C4DE', LightYellow: 'FFFFE0', Lime: '00FF00', LimeGreen: '32CD32',
  Linen: 'FAF0E6', Magenta: 'FF00FF', Maroon: '800000', MediumAquamarine: '66CDAA',
  MediumBlue: '0000CD', MediumOrchid: 'BA55D3', MediumPurple: '9370DB', MediumSeaGreen: '3CB371',
  MediumSlateBlue: '7B68EE', MediumSpringGreen: '00FA9A', MediumTurquoise: '48D1CC', MediumVioletRed: 'C71585',
  MidnightBlue: '191970', MintCream: 'F5FFFA', MistyRose: 'FFE4E1', Moccasin: 'FFE4B5',
  NavajoWhite: 'FFDEAD', Navy: '000080', OldLace: 'FDF5E6', Olive: '808000',
  OliveDrab: '6B8E23', Orange: 'FFA500', OrangeRed: 'FF4500', Orchid: 'DA70D6',
  PaleGoldenrod: 'EEE8AA', PaleGreen: '98FB98', PaleTurquoise: 'AFEEEE', PaleVioletRed: 'DB7093',
  PapayaWhip: 'FFEFD5', PeachPuff: 'FFDAB9', Peru: 'CD853F', Pink: 'FFC0CB',
  Plum: 'DDA0DD', PowderBlue: 'B0E0E6', Purple: '800080', RebeccaPurple: '663399',
  Red: 'FF0000', RosyBrown: 'BC8F8F', RoyalBlue: '4169E1', SaddleBrown: '8B4513',
  Salmon: 'FA8072', SandyBrown: 'F4A460', SeaGreen: '2E8B57', Seashell: 'FFF5EE',
  Sienna: 'A0522D', Silver: 'C0C0C0', SkyBlue: '87CEEB', SlateBlue: '6A5ACD',
  SlateGray: '708090', SlateGrey: '708090', Snow: 'FFFAFA', SpringGreen: '00FF7F',
  SteelBlue: '4682B4', Tan: 'D2B48C', Teal: '008080', Thistle: 'D8BFD8',
  Tomato: 'FF6347', Turquoise: '40E0D0', Violet: 'EE82EE', Wheat: 'F5DEB3',
  White: 'FFFFFF', WhiteSmoke: 'F5F5F5', Yellow: 'FFFF00', YellowGreen: '9ACD32'
};

function generate() {
  const names = Object.keys(COLORS);
  const lookup = (fn, enumName, fallback) => [
    `  ' Looks up a BGE.${enumName} value by CSS color name (case-insensitive).`,
    `  ' Falls back to White for a name that isn't a known color.`,
    `  '`,
    `  ' @param {string} name`,
    `  ' @return {integer}`,
    `  function ${fn}(name as string) as integer`,
    `    lookup = {`,
    names.map((n) => `      ${n}: BGE.${enumName}.${n}`).join(',\n'),
    `    }`,
    `    if invalid <> lookup[name]`,
    `      return lookup[name]`,
    `    end if`,
    `    return BGE.${enumName}.${fallback}`,
    `  end function`
  ].join('\n');

  return [
    START,
    `  ' The CSS named colors as packed RGBA integers (0xRRGGBBAA), fully opaque.`,
    `  ' Values match \`RGBAtoRGBA(r, g, b)\` for the same named color.`,
    `  enum Colors`,
    names.map((n) => `    ${n} = &h${COLORS[n]}FF`).join('\n'),
    `  end enum`,
    ``,
    `  ' The CSS named colors as packed RGB integers (0xRRGGBB, no alpha byte) - the`,
    `  ' same values as BGE.Colors, right-shifted by 8.`,
    `  enum ColorsRGB`,
    names.map((n) => `    ${n} = &h${COLORS[n]}`).join('\n'),
    `  end enum`,
    ``,
    lookup('GetColor', 'Colors', 'White'),
    ``,
    lookup('GetColorRGB', 'ColorsRGB', 'White'),
    END
  ].join('\n');
}

// Every name: Colors = ColorsRGB << 8 with alpha FF, and both lookups resolve it.
function generateSpec() {
  const names = Object.keys(COLORS);
  return [
    START,
    `    @it("every CSS named color matches across Colors, ColorsRGB, GetColor and GetColorRGB")`,
    `    function _()`,
    names.map((n) => [
      `      m.assertEqual(BGE.Colors.${n}, (BGE.ColorsRGB.${n} << 8) or &hFF, "${n}")`,
      `      m.assertEqual(BGE.Colors.${n}, BGE.GetColor("${n}"), "GetColor ${n}")`,
      `      m.assertEqual(BGE.ColorsRGB.${n}, BGE.GetColorRGB("${n}"), "GetColorRGB ${n}")`
    ].join('\n')).join('\n'),
    `    end function`,
    END.replace(/^  /, '    ')
  ].join('\n').replace(/^  ' </gm, "    ' <");
}

function writeBlock(file, block, start, end) {
  const source = fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n');
  const startIdx = source.indexOf(start);
  const endIdx = source.indexOf(end);
  if (startIdx < 0 || endIdx < startIdx) {
    console.error(`Generated-colors markers not found in ${file}`);
    process.exit(1);
  }
  fs.writeFileSync(file, source.slice(0, startIdx) + block + source.slice(endIdx + end.length));
  console.log(`Wrote ${Object.keys(COLORS).length} named colors to ${path.relative(process.cwd(), file)}`);
}

writeBlock(COLORS_FILE, generate(), START, END);
writeBlock(SPEC_FILE, generateSpec(), '  ' + START, '  ' + END);
