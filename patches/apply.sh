#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Russell Barton
# Madeira Converter Exception: see LICENSE-EXCEPTION.md
#
# Applies this repository's Wine changes (patches/wine-*.patch, in order) to the
# wine checkout before build/windows-runtime/build.sh and build/ntdll-unix/build.sh
# build from it. docs/BUILDING.md had this as a step by hand, so the CI runtime
# built opengl32.dll and opengl32's unix side without
# patches/wine-opengl-winios.patch: the ARM64EC DLL kept Wine's 0x7a800000 base
# and the 32-bit thunks dereferenced guest addresses without the window base (a
# 32-bit program died in wow64_thread_attach as soon as it loaded opengl32).
# As with build/dxmt-patches/apply.sh, the wine submodule and its repository are
# not changed: the patches only touch the working tree, and a patch already
# applied is skipped, so every build script can call this. `apply.sh --revert`
# takes them out again.
set -eu
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S="$R/wine"
shopt -s nullglob
patches=("$R"/patches/wine-*.patch)
# Nothing to do without patches (and bash 3.2 under set -u rejects "${patches[@]}" when empty).
[ ${#patches[@]} -gt 0 ] || exit 0
if [ "${1:-}" = --revert ]; then
    for ((i = ${#patches[@]} - 1; i >= 0; i--)); do
        p="${patches[$i]}"
        if git -C "$S" apply --reverse --check "$p" 2>/dev/null; then
            git -C "$S" apply --reverse "$p"
            echo "wine-patches: reverted $(basename "$p")"
        fi
    done
    exit 0
fi
for p in "${patches[@]}"; do
    if git -C "$S" apply --reverse --check "$p" 2>/dev/null; then
        echo "wine-patches: $(basename "$p") already applied"
    elif git -C "$S" apply --check "$p" 2>/dev/null; then
        git -C "$S" apply "$p"
        echo "wine-patches: applied $(basename "$p")"
    else
        echo "wine-patches: $(basename "$p") does not apply on wine $(git -C "$S" rev-parse --short HEAD)" >&2
        exit 1
    fi
done
