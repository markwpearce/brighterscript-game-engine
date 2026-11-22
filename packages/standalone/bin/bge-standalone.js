#!/usr/bin/env node
'use strict';
const { main } = require('../lib/cli');

main(process.argv.slice(2)).then((code) => {
    // serve keeps the process alive through its open server; only set the code.
    process.exitCode = code;
});
