#!/usr/bin/env bash
# Sync prebuilt Rust FFI artifacts into FFI/ for the Apple example app.
#
#   macOS (`swift run` / `swift test`): host .dylib, loaded at runtime via dlopen()
#                                       (NativeLibraryLoader macOS branch).
#   iOS device / simulator (Xcode app target): static .a, linked into the app binary;
#                                       NativeLibraryLoader iOS branch uses dlopen(nil)
#                                       to resolve the statically-linked C-ABI symbols.
#
# Artifacts are produced by the workspace Rust build into native/artifacts/.
# Standalone demo repositories may vendor the same snapshot at ./native/.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # flare-core-ios-app/
ROOT="$(cd "$HERE/../.." && pwd)"                         # flare-im-core-client-sdk/
LOCAL_ART="$HERE/native/artifacts"
ROOT_ART="$ROOT/native/artifacts"
if [[ -d "$LOCAL_ART" ]]; then
  ART="$LOCAL_ART"
else
  ART="$ROOT_ART"
fi
DEST="$HERE/FFI"

if [[ ! -d "$ART" ]]; then
  echo "error: native artifacts not found at $LOCAL_ART or $ROOT_ART — build or distribute the Rust FFI first." >&2
  exit 1
fi
mkdir -p "$DEST"

synced=0

# macOS host dylib (for `swift run` / `swift test` on the host).
if [[ -f "$ART/host/libflare_im_core_sdk_ffi.dylib" ]]; then
  cp -f "$ART/host/libflare_im_core_sdk_ffi.dylib" "$DEST/"
  echo "synced  host/libflare_im_core_sdk_ffi.dylib  -> FFI/"
  synced=$((synced + 1))
fi

# iOS device + simulator static slices (for the Xcode app target).
for arch in aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios; do
  src="$ART/ios/$arch/libflare_im_core_sdk_ffi.a"
  if [[ -f "$src" ]]; then
    mkdir -p "$DEST/ios/$arch"
    cp -f "$src" "$DEST/ios/$arch/"
    echo "synced  ios/$arch/libflare_im_core_sdk_ffi.a  -> FFI/ios/$arch/"
    synced=$((synced + 1))
  fi
done

# C header (already vendored by the SwiftPM systemLibrary; copied for Xcode/non-SwiftPM consumers).
if [[ -f "$ART/flare_im_core_sdk_ffi.h" ]]; then
  cp -f "$ART/flare_im_core_sdk_ffi.h" "$DEST/"
  echo "synced  flare_im_core_sdk_ffi.h  -> FFI/"
fi

if [[ "$synced" -eq 0 ]]; then
  echo "error: no FFI artifacts copied — expected host/ios slices under $ART." >&2
  exit 1
fi
echo "FFI sync complete -> $DEST"
