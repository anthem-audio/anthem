#!/usr/bin/env bash
# Copyright (C) 2026 Joshua Wade
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail
cd "$(dirname "$0")"

toolchain=nightly-2026-11-06
profile=${1:-}
case "$profile" in
    --install-toolchain) exec rustup toolchain install "$toolchain" --profile minimal --component rust-src ;;
    debug) cargo_profile=dev ;;
    release) cargo_profile=release ;;
    *) echo "Usage: bash build-web.sh --install-toolchain | <debug|release> [cargo build options]" >&2; exit 2 ;;
esac
shift

target=wasm32-unknown-emscripten
cargo "+$toolchain" build --locked --target "$target" --target-dir target \
    --profile "$cargo_profile" -Zbuild-std=std,panic_abort "$@"

source_directory="target/$target/$profile"
output_directory="../build/rust-web/$profile"
mkdir -p "$output_directory"

# Prepare all files before replacing the staged build, which may contain Cargo hard links.
staging_directory=$(mktemp -d "$output_directory/.stage.XXXXXXXX")
trap 'rm -f "$staging_directory/"*; rmdir "$staging_directory"' EXIT
emcc ../engine/browser_file_system/runtime.c --no-entry -O2 \
    -sFORCE_FILESYSTEM=1 -sMODULARIZE=1 \
    -sEXPORT_NAME=AnthemFileSystem -sEXPORTED_RUNTIME_METHODS=FS \
    -o "$staging_directory/AnthemFileSystem.js"
cp "$source_directory/anthem-engine.js" "$source_directory/anthem_engine.wasm" "$staging_directory/"
mv -f "$staging_directory/"* "$output_directory/"
