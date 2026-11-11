# zip.js

Pinned version: **2.24.0** (BSD-3-Clause; see LICENSE).

Source: https://github.com/gildas-lormeau/zip.js/tree/v2.24.0
Bundle: https://raw.githubusercontent.com/gildas-lormeau/zip.js/v2.24.0/dist/zip-native.min.js
SHA-256: `0e6e3b1a5c7a55bf80c24c745a2f2ca2e0b7d34272e1231f23e07e1174356111`

This is the unmodified upstream bundle. It provides ZIP decoding and a JavaScript
fallback for browsers without native decompression streams. Anthem disables its
internal workers and runs it inside the project archive worker. No npm install,
bundling, generated code, or additional Wasm files are required.

To update, replace the bundle and license from a pinned upstream release, update
this note and checksum, and run the native and browser project archive tests.
