#!/usr/bin/env bash
# Copyright (C) 2026 Chokri Hammedi (blue0x1) <https://github.com/blue0x1>
# Builds out/linux-2048mb.bin: the Linux payload for every PS4. On a PS4 Pro it
# first switches the GPU to all 4 shader engines (payload/boot.c), then runs the
# original Linux loader unchanged, which is packed behind it.
#   scripts/build-payload.sh <original linux-2048mb.bin>
source "$(dirname "$0")/common.sh"

LOADER="${1:-}"
LOADER_SHA256="34663661aff043770a8d7422d0d994243efce581d7315b02f5fd43313ffe31e3"
SDK_REPO="https://github.com/Scene-Collective/ps4-payload-sdk.git"
SDK_COMMIT="fd4f7299d1da5f5601c164a02b6d6d019ac8630a"
W="$BUILD/payload"
SDK="$W/ps4-payload-sdk/libPS4"

[ -f "$LOADER" ] || die "Usage: $0 <original linux-2048mb.bin>"
echo "$LOADER_SHA256  $LOADER" | sha256sum -c --quiet \
    || die "$LOADER is not the original Linux loader (it may already be a 4-engine build)"

mkdir -p "$W" "$OUT"
if [ ! -d "$W/ps4-payload-sdk/.git" ]; then
    git clone -q "$SDK_REPO" "$W/ps4-payload-sdk"
fi
git -C "$W/ps4-payload-sdk" checkout -q "$SDK_COMMIT"
# Its own assembler warnings are harmless; show the output only if it fails.
make -s -C "$SDK" >/dev/null 2>&1 || make -C "$SDK" || die "ps4-payload-sdk build failed"

cp "$LOADER" "$W/loader.bin"
CF="-I$SDK/include -Os -std=c11 -ffunction-sections -fdata-sections -fno-builtin -nostartfiles
    -nostdlib -Wall -Wextra -masm=intel -march=btver2 -mtune=btver2 -m64 -mabi=sysv
    -mcmodel=small -fpie -fPIC -Wa,-W -ffile-prefix-map=$ROOT/payload/="
LF="-L$SDK -Xlinker -T $ROOT/payload/linker.x -Wl,--build-id=none -Wl,--gc-sections
    -Wl,--no-warn-rwx-segments"
gcc -c -o "$W/boot.o" "$ROOT/payload/boot.c" $CF
gcc -c -o "$W/loader.o" "$ROOT/payload/loader.s" -Wa,-I,"$W"
gcc "$SDK/crt0.s" "$W/boot.o" "$W/loader.o" -o "$W/boot.elf" $CF $LF -lPS4

# A payload loads at an unknown address and gets no relocations.
relocs="$(readelf -rW "$W/boot.elf" | grep -c R_X86_64_RELATIVE || true)"
[ "$relocs" = 0 ] || die "payload has $relocs relocations; it would crash on the PS4"
objcopy -O binary "$W/boot.elf" "$OUT/linux-2048mb.bin"
ok "Built $OUT/linux-2048mb.bin ($(stat -c %s "$OUT/linux-2048mb.bin") bytes)"
