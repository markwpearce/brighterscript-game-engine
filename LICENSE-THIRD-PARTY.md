# Third-party licenses

This file lists third-party code vendored/ported into this engine's own source
(as opposed to a ROPM/npm dependency, which carries its own license alongside
its package). Each entry lists what was used and where it now lives.

## QR code generator (`src/source/utils/qrcode/`)

`BGE.QrCode`'s encoding algorithm is ported to plain BrighterScript from
[QR-Code-generator-brightscript](https://github.com/paramount-engineering/QR-Code-generator-brightscript)
(Copyright (c) 2022 Paramount, MIT license), itself a BrightScript port of
[Project Nayuki's QR Code generator library](https://www.nayuki.io/page/qr-code-generator-library)
(Copyright (c) Project Nayuki, MIT license). Both original licenses:

```
MIT License

Copyright (c) 2022 Paramount

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

The BrightScript port additionally carries: "QR Code generator library
(Brightscript) - Copyright (c) Kevin Hoos" alongside the same MIT terms above.
