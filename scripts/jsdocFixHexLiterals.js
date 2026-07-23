// brighterscript-jsdocs-plugin (registered before this plugin in jsdoc.json) rewrites .bs/.brs
// source into pseudo-JS for jsdoc's own parser, but it copies enum/const literal values through
// verbatim - including BrightScript hex literals like `&hFF0000FF`, which aren't valid JS and
// crash jsdoc's babel-based parser ("Unexpected token"). Convert them to JS hex (`0xFF0000FF`)
// after that conversion has already run.
exports.handlers = {
    beforeParse: (e) => {
        e.source = e.source.replace(/&h([0-9A-Fa-f]+)/g, '0x$1');
    }
};
