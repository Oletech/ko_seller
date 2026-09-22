#!/usr/bin/env bash
# Verifies that an app bundle supports 16 KB memory page sizes, which Google
# Play requires of every app targeting Android 15+.
#
#   ./tool/check_16kb.sh [path/to/app-release.aab]
#
# Two things have to hold:
#   1. Every LOAD segment in every 64-bit .so is aligned to at least 16384.
#      A library built against an older NDK is aligned to 0x1000 (4 KB) and
#      fails. 32-bit ABIs use 4 KB pages and are exempt.
#   2. extractNativeLibs is false, so the libraries are mapped straight out of
#      the APK instead of being unpacked at install time.
set -euo pipefail

AAB="${1:-build/app/outputs/bundle/release/app-release.aab}"
[ -f "$AAB" ] || { echo "No bundle at $AAB. Run: flutter build appbundle --release"; exit 1; }

READELF="$(ls "${ANDROID_HOME:-$HOME/Library/Android/sdk}"/ndk/*/toolchains/llvm/prebuilt/*/bin/llvm-readelf 2>/dev/null | sort | tail -1 || true)"
[ -n "$READELF" ] || { echo "llvm-readelf not found; install an Android NDK."; exit 1; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
unzip -q -o "$AAB" 'base/lib/*' -d "$WORK" 2>/dev/null || true

MIN=16384
FAILED=0
echo "Checking $(basename "$AAB") for 16 KB page size support"
echo

for ABI in arm64-v8a x86_64; do
    DIR="$WORK/base/lib/$ABI"
    [ -d "$DIR" ] || continue
    echo "  $ABI"
    for SO in "$DIR"/*.so; do
        [ -e "$SO" ] || continue
        WORST=""
        for A in $("$READELF" --program-headers "$SO" 2>/dev/null | awk '/LOAD/{print $NF}' | sort -u); do
            DEC=$((A))
            if [ -z "$WORST" ] || [ "$DEC" -lt "$WORST" ]; then WORST=$DEC; fi
        done
        if [ -z "$WORST" ]; then
            printf "    ?  %-34s no LOAD segments found\n" "$(basename "$SO")"
        elif [ "$WORST" -ge "$MIN" ]; then
            printf "    OK %-34s align %s\n" "$(basename "$SO")" "$(printf '0x%x' "$WORST")"
        else
            printf "    !! %-34s align %s  (needs >= 0x4000)\n" "$(basename "$SO")" "$(printf '0x%x' "$WORST")"
            FAILED=1
        fi
    done
done

echo
MANIFEST="$(find build/app -name AndroidManifest.xml -path '*merged_manifest*release*' 2>/dev/null | head -1)"
if [ -n "$MANIFEST" ]; then
    if grep -q 'android:extractNativeLibs="false"' "$MANIFEST"; then
        echo "  OK extractNativeLibs=false"
    else
        echo "  !! extractNativeLibs is not false; 16 KB support needs mapped libraries"
        FAILED=1
    fi
fi

echo
if [ "$FAILED" -eq 0 ]; then
    echo "PASS - this bundle supports 16 KB page sizes."
else
    echo "FAIL - rebuild against NDK r27 or newer (android/app/build.gradle: ndkVersion)."
    exit 1
fi
